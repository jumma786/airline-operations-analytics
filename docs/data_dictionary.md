# Data Dictionary

Column-by-column reference for the AirlineAnalytics warehouse. All tables
sit in the default `dbo` schema.

## fact_flights

The central fact table. One row per scheduled flight operation. 495,771 rows.

| Column | Type | Nullable | Description |
|---|---|---|---|
| `flight_id` | INT IDENTITY | No | Surrogate primary key, auto-generated |
| `carrier_code` | CHAR(2) | No | IATA carrier code (AA, WN, B6, OH). FK to `dim_carrier` |
| `flight_date` | DATE | No | Scheduled departure date. FK to `dim_date` |
| `flight_number` | INT | No | Carrier-assigned flight number |
| `tail_number` | VARCHAR(10) | Yes | Aircraft registration (e.g. N12345). NULL on cancellations |
| `origin_airport` | CHAR(3) | No | IATA origin airport code (MIA, ATL, JFK, LEX). FK to `dim_airport` |
| `destination_airport` | CHAR(3) | No | IATA destination code. Not constrained to dim_airport |
| `scheduled_departure_time` | TIME | No | Scheduled gate departure time (local) |
| `actual_departure_time` | TIME | Yes | Actual gate departure time. NULL if cancelled |
| `scheduled_elapsed_minutes` | INT | No | Scheduled flight duration in minutes |
| `actual_elapsed_minutes` | INT | Yes | Actual flight duration. 0 if cancelled |
| `departure_delay_minutes` | INT | Yes | Minutes late at gate departure. Negative if early. NULL if cancelled |
| `wheels_off_time` | TIME | Yes | Time aircraft left the runway. '00:00' if cancelled |
| `taxi_out_minutes` | INT | Yes | Minutes between pushback and wheels-up |
| `carrier_delay_minutes` | INT | Yes | Delay attributable to carrier (0 on non-delayed) |
| `weather_delay_minutes` | INT | Yes | Delay attributable to weather |
| `nas_delay_minutes` | INT | Yes | Delay attributable to National Airspace System (ATC) |
| `security_delay_minutes` | INT | Yes | Delay attributable to security incidents |
| `late_aircraft_delay_minutes` | INT | Yes | Delay attributable to a late inbound aircraft |
| `is_cancelled` | BIT | No | 1 if flight was cancelled, 0 if operated |
| `departure_hour` | INT | No | Computed from scheduled_departure_time. Range 0-23 |
| `flight_month` | INT | No | Computed from flight_date. Range 1-12 |

### Notes

- Five delay-cause columns are only populated for flights delayed 15+
  minutes (BTS attribution rule). For shorter delays they show as 0
  even when `departure_delay_minutes > 0`.
- Cancellation derivation: `is_cancelled = 1 WHERE actual_elapsed_minutes
  = 0 AND wheels_off_time = '00:00'`.
- `departure_hour` and `flight_month` are computed columns (`PERSISTED`)
  populated automatically at insert time.

## dim_carrier

Carrier dimension. 4 rows.

| Column | Type | Nullable | Description |
|---|---|---|---|
| `carrier_code` | CHAR(2) | No | IATA carrier code (PK) |
| `carrier_name` | VARCHAR(50) | No | Full airline name |
| `carrier_type` | VARCHAR(20) | No | Operating category: Major, Low-Cost, or Regional |

### Contents

| carrier_code | carrier_name | carrier_type |
|---|---|---|
| AA | American Airlines | Major |
| WN | Southwest Airlines | Low-Cost |
| B6 | JetBlue Airways | Low-Cost |
| OH | PSA Airlines | Regional |

## dim_airport

Airport dimension covering the four origin airports. 4 rows.

| Column | Type | Nullable | Description |
|---|---|---|---|
| `airport_code` | CHAR(3) | No | IATA airport code (PK) |
| `airport_name` | VARCHAR(100) | No | Full airport name |
| `city` | VARCHAR(50) | No | City served |
| `state` | CHAR(2) | No | US state code |
| `airport_role` | VARCHAR(20) | No | Classification: Hub or Regional |

### Contents

| airport_code | airport_name | city | state | airport_role |
|---|---|---|---|---|
| MIA | Miami International Airport | Miami | FL | Hub |
| ATL | Hartsfield-Jackson Atlanta Intl | Atlanta | GA | Hub |
| JFK | John F. Kennedy International | New York | NY | Hub |
| LEX | Blue Grass Airport | Lexington | KY | Regional |

### Note on destination airports

The `destination_airport` column in `fact_flights` contains 100+
destinations that are not in `dim_airport`. This is intentional —
the dimension covers only the four origin airports relevant to
operational analysis. No foreign key constraint exists on destinations.

## dim_date

Date dimension covering the analysis period. 1,520 rows (one per day).

| Column | Type | Nullable | Description |
|---|---|---|---|
| `date_key` | DATE | No | Calendar date (PK) |
| `year_num` | INT | No | Four-digit year |
| `quarter_num` | TINYINT | No | Quarter (1-4) |
| `month_num` | TINYINT | No | Month (1-12). Use to sort month_name |
| `month_name` | VARCHAR(10) | No | English month name (January, February...) |
| `day_of_month` | TINYINT | No | Day of month (1-31) |
| `day_of_week` | TINYINT | No | 1 = Monday through 7 = Sunday |
| `day_name` | VARCHAR(10) | No | English day name (Monday, Tuesday...) |
| `is_weekend` | BIT | No | 1 if Saturday or Sunday |
| `season` | VARCHAR(10) | No | Winter / Spring / Summer / Autumn (Northern Hemisphere) |
| `is_partial_year` | BIT | No | 1 for 2026 (Jan-Feb only available) |

### Notes

- Range: 2022-01-01 to 2026-02-28.
- `is_partial_year` flags 2026 because the data only covers January
  and February of that year. Use this flag to exclude or label
  incomplete years in dashboards.
- `day_of_week` is calculated DATEFIRST-independently (i.e., always
  1=Mon regardless of SQL Server's session setting), making queries
  portable across servers.
- Season mapping: Dec/Jan/Feb = Winter, Mar/Apr/May = Spring,
  Jun/Jul/Aug = Summer, Sep/Oct/Nov = Autumn.

## Foreign key relationships

Three foreign key constraints enforce referential integrity:

- `fk_flights_carrier`: `fact_flights.carrier_code` → `dim_carrier.carrier_code`
- `fk_flights_origin`: `fact_flights.origin_airport` → `dim_airport.airport_code`
- `fk_flights_date`: `fact_flights.flight_date` → `dim_date.date_key`

No FK on `destination_airport` (see dim_airport note above).

## Indexes

Non-clustered indexes on the fact table to support analytical queries:

- `idx_carrier_code` on `carrier_code`
- `idx_destination` on `destination_airport`
- `idx_flight_date` on `flight_date`
- `idx_departure_delay` on `departure_delay_minutes`
