# US Airline Operations Analytics

End-to-end analytics on 495,771 US domestic flights (2022 – Feb 2026) across four
carriers and four origin airports — including a data quality audit that recovered
296,834 records lost to silent ETL corruption, a SQL Server dimensional warehouse,
and a Power BI executive dashboard surfacing operational insights on delays,
cancellations, and on-time performance.

**Tech stack:** Python (Pandas, Jupyter) · SQL Server · T-SQL · Power BI · DAX

**Key findings**
- Summer flights carry 2× the delay of autumn (27.2 vs 12.5 min average); July is the
  worst month at 30.5 min mean delay
- Delays accumulate through the operational day: from 2.7 min at 6am to 30+ min
  by 11pm — a clear late-aircraft cascade pattern
- Carrier and late-aircraft delays together drive 77.7% of all delay minutes
- 1.83% of flights cancelled (9,056 of 495,771) — a metric the original pipeline
  silently misclassified as on-time zero-delay flights

"C:\Users\jumma\Downloads\Airline-Operations-Analytics\docs\screenshots\executive_overview.png"
---

## The Project

US Bureau of Transportation Statistics (BTS) publishes detailed on-time
performance data for every commercial flight at every US airport. This project
takes five years of that data across four carriers (American, Southwest,
JetBlue, PSA) operating from four origin airports (MIA, ATL, JFK, LEX) and
builds an end-to-end analytics platform — from raw CSV ingestion through to
an interactive Power BI dashboard.

The interesting part isn't the destination; it's how the project got there.

## The Data Quality Story

The original pipeline used SQL Server Management Studio's Flat File Import
wizard to load each carrier's CSV directly into the database. The wizard ran
without errors. The flights loaded. The dashboards built. Nothing visibly
broken.

Then an audit revealed:

- **296,834 of 495,771 rows (60%) had NULL flight_date.** The Flat File Import
  samples the first ~200 rows of each CSV and locks in a date format based on
  what it sees. The raw BTS exports contained a 6-row metadata preamble before
  the data started, and the dates in early rows used dashes (`2022-01-15`)
  while later rows used slashes (`01/15/2022`). The wizard locked in one
  format, then silently converted everything else to NULL.

- **The origin airport column was missing entirely.** Each carrier's CSV
  contained only flights from one airport, so origin was redundant within
  each file. The UNION ALL that combined them dropped the column. The
  warehouse had no way to answer "which airport is most congested?" because
  the airport identifier didn't exist.

- **9,056 cancelled flights were stored as on-time, zero-delay flights.** A
  cancelled flight has `actual_elapsed_minutes = 0` and `wheels_off_time =
  '00:00'`. The original load treated these as completed flights with
  exceptionally good performance. The dashboard's on-time percentage was
  silently inflated; the average delay was silently deflated.

The project that followed is the rebuild: a Python ETL pipeline that handles
the format drift, restores origin from filename, flags cancellations
explicitly, and produces a properly typed parquet file. A SQL Server star
schema with computed columns and foreign key constraints. Six analytical
queries that re-derive every KPI from clean data, applying the US Department
of Transportation's standard on-time definition (departure delay < 15
minutes, cancellations excluded). And three Power BI pages that visualise
the results.

The dashboard numbers are different from the original, sometimes by enough
to matter. The on-time percentage moved from 73.1% (broken methodology) to
71.8% (DOT standard, cancellations excluded). The original "JetBlue has the
highest delays" insight survived the audit but gained an important caveat:
each carrier in the dataset flies from only one airport, so carrier-level
performance differences cannot be cleanly separated from airport-level
congestion effects.

The full audit and recovery is documented in [docs/data_quality_report.md](docs/data_quality_report.md).

---

## Architecture

![Architecture Diagram](docs/architecture.png)

The pipeline flows in four stages:

1. **Ingestion (Python)** — Four BTS CSV exports are read into Pandas with a
   custom header-detection function that skips the 6-row BTS metadata
   preamble. A unified date parser handles the dash/slash format drift.
   Cancellations are flagged from `actual_elapsed_minutes = 0` and
   `wheels_off_time = '00:00'`. The cleaned data is written to Parquet for
   type-preserved intermediate storage.

2. **Staging & Load (SQL Server)** — A staging table matching the CSV
   structure receives the data via `BULK INSERT`. After validation, the
   data flows into the typed `fact_flights` table where computed columns
   (`departure_hour`, `flight_month`) are auto-populated.

3. **Dimensional Warehouse (SQL Server)** — A star schema with three
   conformed dimensions (`dim_carrier`, `dim_airport`, `dim_date`) joined
   to `fact_flights` via foreign key constraints. The `dim_date` table
   spans Jan 2022 – Feb 2026 (1,520 days) with an `is_partial_year` flag
   for 2026 (only Jan–Feb available). Indexes on `carrier_code`,
   `destination_airport`, `flight_date`, and `departure_delay_minutes`
   support analytical query performance.

4. **Analytics & Visualisation (Power BI)** — The four warehouse tables
   are imported into Power BI's tabular model. The foreign keys from
   SQL Server are auto-detected as relationships. DAX measures implement
   the DOT on-time standard (departure delay < 15 minutes, cancellations
   excluded) and serve three dashboard pages: Executive Overview,
   Delay Intelligence, and Carrier Deep-Dive.

## Tech Stack

| Layer | Technology |
|---|---|
| ETL | Python 3.14.3, Pandas, PyArrow (Parquet), Jupyter |
| Database | SQL Server 2019 Express, T-SQL |
| Modelling | Star schema (1 fact + 3 dimensions), computed columns, FK constraints |
| Connectivity | SQLAlchemy, pyodbc, ODBC Driver 17 |
| Visualisation | Power BI Desktop, DAX |
| Version control | Git, GitHub |

---

## Key Insights

Six analytical findings, derived from clean data using DOT-standard methodology
(on-time = departure delay < 15 min, cancellations excluded from operational
metrics).

### 1. Summer drives delay by a factor of 2

Average delay rises from 12.5 min in Autumn to 27.2 min in Summer — more than
double. On-time performance collapses from 78% to 64% across the same range.
July is the worst single month at 30.5 min mean delay, driven by thunderstorm
season and capacity stress.

### 2. Delays accumulate through the operational day

Flights departing at 6am average 2.7 min of delay. By 11pm, the same metric is
30.4 min — an 11× increase across the day. This pattern is the late-aircraft
cascade: a delay early in the day propagates forward as the same airframe
flies subsequent legs. The cascade is the operational mechanism behind insight
3 below.

### 3. Carrier and late-aircraft delays drive 77.7% of all delay minutes

| Cause          | Share |
|---|---|
| Carrier        | 39.0% |
| Late aircraft  | 38.7% |
| NAS (air traffic) | 18.2% |
| Weather        | 4.8%  |
| Security       | 0.3%  |

Carrier and late-aircraft are deeply linked: most "late aircraft" delays
originate as carrier delays earlier in the day. The system's delay is
fundamentally airline-operational, not weather- or ATC-driven.

### 4. PSA achieves best on-time, worst cancellation rate

PSA Airlines (regional) leads on-time performance at 83.6% — 14 points ahead
of JetBlue. But it also has the highest cancellation rate at 2.52%. The
pattern: PSA rarely runs late, but when operations break down (crew, aircraft
availability), the response is to cancel rather than delay. This is typical
regional-carrier behaviour driven by tight resource margins.

### 5. JetBlue records highest delays — but cannot be cleanly separated from JFK

JetBlue averages 21.0 min delay and 26.0 min taxi-out — both the worst in the
dataset. However, JetBlue is the only carrier flying from JFK in this data,
and JFK is the most congested airport in the dataset. **The observed "JetBlue
delay" is inseparable from "JFK congestion."** A proper carrier-vs-airport
analysis would require carriers operating from multiple airports.

### 6. 1.83% of flights cancelled — previously misclassified as on-time

9,056 cancellations across 495,771 flights. In the original pipeline, these
were stored as flights with zero departure delay and zero taxi-out time —
silently inflating on-time percentage and deflating average delay. Correcting
this moved on-time from 73.1% (broken) to 71.8% (DOT standard).

---

## Repository Structure

```
airline-operations-analytics/
├── README.md                          # This file
├── requirements.txt                   # Python dependencies
├── LICENSE                            # MIT
├── docs/
│   ├── architecture.png               # Architecture diagram
│   ├── data_quality_report.md         # Full audit story
│   ├── data_dictionary.md             # Column-by-column reference
│   └── screenshots/                   # Dashboard page screenshots
├── raw_data/                          # Original BTS CSV exports (not committed)
│   ├── mia_aa.csv
│   ├── atl_wn.csv
│   ├── jfk_jetblue.csv
│   └── lex_psa.csv
├── cleaned_data/                      # Pipeline outputs
│   ├── fact_flights_clean.parquet     # Typed intermediate
│   └── fact_flights_load.csv          # BULK INSERT-ready
├── notebooks/                         # Python ETL
│   └── 01_clean_and_load.ipynb
├── sql/                               # Warehouse build scripts
│   ├── 01_create_fact_flights.sql
│   ├── 02_create_staging.sql
│   ├── 03_bulk_insert.sql
│   ├── 04_create_dimensions.sql
│   ├── 05_foreign_keys.sql
│   └── 06_analytical_queries.sql
└── dashboard/
    └── airline_operations.pbix        # Power BI file
```

---

## How to Reproduce

### Prerequisites
- Python 3.14.3 with Pandas, PyArrow, SQLAlchemy, pyodbc, Jupyter
- SQL Server 2019+ (Express edition works) with a local instance
- ODBC Driver 17 for SQL Server
- Power BI Desktop (June 2024 or later) — Windows only
- BTS detailed flight exports placed in `raw_data/`

**Total runtime end-to-end: ~3 minutes** (Python pipeline ~90s, BULK INSERT
~10s, Power BI import ~60s).

### Setup

```bash
pip install -r requirements.txt
```

### Build the warehouse

```bash
# 1. Run the ETL pipeline
jupyter notebook notebooks/01_clean_and_load.ipynb
# Produces cleaned_data/fact_flights_clean.parquet
#          cleaned_data/fact_flights_load.csv
```

```sql
-- 2. Create the database in SSMS
CREATE DATABASE AirlineAnalytics;
USE AirlineAnalytics;

-- 3. Run the SQL scripts in order
:r sql/01_create_fact_flights.sql
:r sql/02_create_staging.sql
:r sql/03_bulk_insert.sql       -- requires fact_flights_load.csv readable by SQL Server service account
:r sql/04_create_dimensions.sql
:r sql/05_foreign_keys.sql
```

### Open the dashboard

1. Open `dashboard/airline_operations.pbix` in Power BI Desktop
2. Refresh data source — connect to your local SQL Server / AirlineAnalytics
3. Three pages: Executive Overview · Delay Intelligence · Carrier Deep-Dive

### Source data

This project uses publicly available exports from the **US Bureau of Transportation
Statistics Detailed Statistics**. The four CSV files are not included in this
repository; download them from [transtats.bts.gov](https://www.transtats.bts.gov/)
using the "Detailed Statistics — Departures" report, filtered to:

- Airlines: American (AA), Southwest (WN), JetBlue (B6), PSA (OH)
- Origin airports: MIA, ATL, JFK, LEX
- Date range: 2022-01 to 2026-02

Save as `raw_data/{airport}_{carrier}.csv`.

---

## About this project

Built as a portfolio piece by **Jumma Mohammad Teli** — Data Analyst, Birmingham UK.

Designed to demonstrate end-to-end analytics capability across data engineering,
dimensional modelling, analytical SQL, BI dashboarding, and methodology rigour.
The data quality audit story (60% of records silently corrupted by a default
import wizard) is the project's central differentiator.

### Contact
- LinkedIn: [linkedin.com/in/jumma-mohammad](https://linkedin.com/in/jumma-mohammad)
- Email: jummamohammad477@gmail.com
- Phone: +44 7442 001088
- GitHub: [@jumma786](https://github.com/jumma786)

### Acknowledgements
Source data: US Bureau of Transportation Statistics, Detailed Statistics — Departures.

### License
MIT License. See [LICENSE](LICENSE) for details.
