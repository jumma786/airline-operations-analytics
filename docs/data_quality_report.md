# Data Quality Report

This report documents the data quality audit performed on the original
pipeline and the recovery work that followed. The headline findings are
captured in the main [README](../README.md); this document provides the
full technical detail.

## Context

The source data is the US Bureau of Transportation Statistics (BTS)
Detailed Statistics — Departures export, downloaded as four CSV files
covering four carrier-airport pairs:

- `mia_aa.csv` — American Airlines from Miami
- `atl_wn.csv` — Southwest Airlines from Atlanta
- `jfk_jetblue.csv` — JetBlue Airways from JFK
- `lex_psa.csv` — PSA Airlines from Lexington

Combined dataset: 495,775 raw rows covering January 2022 to February 2026.

The original ingestion was performed using SQL Server Management Studio's
Flat File Import wizard, loading each CSV directly into a SQL Server table.
The audit was prompted by anomalies noticed during initial dashboard
development.

## Issue 1: Silent date corruption (60% of rows)

### Symptom

A row count query returned 495,775 rows. A `WHERE flight_date IS NOT NULL`
query returned 198,941 rows. The missing 296,834 rows had silently been
set to NULL during ingestion.

### Root cause

The BTS exports contain three problematic features the Flat File Import
wizard does not handle:

1. **Six-row metadata preamble.** Each CSV begins with six lines of
   header metadata (export timestamp, applied filters, blank lines)
   before the actual column header row. The wizard treats the first row
   as the column header, so it parses metadata text as column names and
   misaligns every subsequent row.

2. **Mixed date formats within each file.** Early rows use ISO format
   (`2022-01-15`); later rows use US format (`01/15/2022`). The wizard
   samples approximately the first 200 rows to infer a date format,
   locks in that format, then silently converts anything that doesn't
   match to NULL.

3. **No error reporting.** Conversion failures produce NULLs, not errors.
   The wizard reports the import as successful. The 60% data loss is
   invisible unless you actively query for it.

Affected files: `mia_aa.csv`, `atl_wn.csv`, `jfk_jetblue.csv`. The
`lex_psa.csv` file happened to be clean because its rows were all in a
single format.

### Recovery

A Python ETL pipeline replaces the wizard. The `find_header_row()`
function reads each file line by line until it locates the actual header
row (identified by the presence of expected column names), skipping any
preamble. The `parse_dates()` function normalises both date formats to a
common ISO representation before storage.

After recovery: 495,771 rows successfully parsed (4 rows were genuinely
malformed and dropped, all from the same source file). Zero NULL values
in the `flight_date` column.

## Issue 2: Origin airport column missing

### Symptom

The original schema had no `origin_airport` column. Any analytical
question about airport-level operations could not be answered.

### Root cause

Each BTS export contains flights from only one origin airport, so the
origin was implicit in the filename rather than the data. When the four
files were combined via `UNION ALL` in the original pipeline, the
origin information was lost. The combined table had no way to
reconstruct which flight departed from which airport.

### Recovery

The Python ETL extracts the origin airport from the source filename
(`mia_aa.csv` → `MIA`, etc.) and attaches it as a new column before
writing to the warehouse. Recovery is exact — there is no ambiguity
because each file maps to one airport.

## Issue 3: Cancellations misclassified as on-time flights

### Symptom

The original on-time percentage was 73.1%, computed across all 495,771
rows. Average departure delay was reported at 18.29 minutes. Both
figures were inflated favourably.

### Root cause

A cancelled flight in BTS data has `actual_elapsed_minutes = 0` and
`wheels_off_time = '00:00'`. There is no explicit `is_cancelled` flag
in the source data. The original load treated cancelled flights as
completed flights with exceptionally fast performance, dragging down
the average delay metric and inflating the on-time percentage.

### Recovery

A cancellation flag was added at the ETL stage, derived from the
combination of `actual_elapsed_minutes = 0` AND `wheels_off_time = '00:00'`.
This identifies 9,056 cancelled flights (1.83% of total). All
operational metrics (delay average, taxi-out average, on-time
percentage) are computed with cancellations excluded.

After correction:
- On-time percentage: 71.84% (was 73.12%)
- Average departure delay: 17.95 min (was 18.29 min)
- Cancellation rate: 1.83% (was 0%, because they were misclassified)

## Issue 4: Out-of-range time values

### Symptom

During warehouse load, BULK INSERT rejected 233 rows with TIME conversion
errors on the `actual_departure_time` (96 rows) and `wheels_off_time`
(137 rows) columns.

### Root cause

BTS data encodes midnight at end-of-day as `24:00:00` rather than
`00:00:00`. SQL Server's TIME type accepts only values from `00:00:00`
to `23:59:59` and rejects `24:00:00` as out of range.

### Recovery

The ETL normalises out-of-range times via modulo: `hour % 24`. So
`24:00:00` becomes `00:00:00`. This is a minor approximation — strictly,
a 24:00 time at the end of day should roll forward to the next day —
but for analytical purposes (computing hour-of-day patterns and
delay distributions) the simplification is acceptable. The change is
documented here for transparency.

## Methodology corrections in the analytical layer

Two methodology issues were also identified and corrected:

### On-time definition

The original analysis used a loose definition (any non-negative delay
treated as on-time). The US Department of Transportation standard is
delay < 15 minutes. All KPIs were re-derived using the DOT standard.

### Cancellations in denominators

Operational averages (delay, taxi-out) and on-time percentages should
exclude cancelled flights from the denominator. The original
calculations included cancellations (as zero-delay rows), distorting
all rate-based metrics. The corrected analysis filters
`is_cancelled = 0` in every operational query.

## Acknowledged limitations of the recovered data

Two structural limitations remain even after the recovery, and are
explicitly named in the analysis:

### Carrier-airport confounding

Each carrier in the dataset flies from only one airport. This means
carrier-level differences cannot be cleanly separated from airport-level
differences. The observed "JetBlue has the highest delays" finding is
inseparable from "JFK is the most congested airport in the dataset."
A proper carrier-vs-airport analysis would require carriers operating
from multiple airports, which this dataset does not provide.

### Partial 2026 coverage

The data covers January 2022 through February 2026. The 2026 year is
incomplete (Jan-Feb only). The `dim_date` table flags this with an
`is_partial_year` column. Annual aggregates that include 2026 should
be interpreted with caution; comparisons that aggregate by month
across years remain valid because each month is fairly sampled.

## Summary

| Issue | Rows affected | Method | Outcome |
|---|---|---|---|
| Null dates | 296,834 (60%) | Python date parser | All recovered |
| Missing origin | All | Filename extraction | Restored |
| Cancellation misclassification | 9,056 | Compound flag | Flagged explicitly |
| Time out of range | 233 | Modulo normalisation | All recovered |

Final clean dataset: **495,771 rows, 19 columns, zero NULL values in
required fields, 9,056 cancellations correctly flagged.**
