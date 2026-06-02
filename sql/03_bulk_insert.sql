-- ============================================================
-- 03_bulk_insert.sql
-- Loads cleaned data from CSV into staging, then into fact_flights.
--
-- Source file: cleaned_data/fact_flights_load.csv
--   - 495,771 rows
--   - 19 columns (no header)
--   - Unix line endings (\n) - set by the Python ETL via lineterminator="\n"
--
-- Permission note: The SQL Server service account must have read
-- access to the file path. If you get OS error 5 (Access denied),
-- either move the file or grant the SQL Server service account
-- read permission on the source folder.
-- ============================================================

USE AirlineAnalytics;
GO

-- Clear any existing data before reload
TRUNCATE TABLE stg_fact_flights;
GO

-- Load CSV into staging
BULK INSERT stg_fact_flights
FROM 'C:\Users\jumma\Downloads\Airline-Operations-Analytics\cleaned_data\fact_flights_load.csv'
WITH (
    FORMAT          = 'CSV',
    FIELDTERMINATOR = ',',
    ROWTERMINATOR   = '0x0a',   -- Unix newline (\n). Use '0x0d0a' if CSV has Windows line endings (\r\n).
    KEEPNULLS,
    TABLOCK
);
GO

SELECT COUNT(*) AS staged_rows FROM stg_fact_flights;
GO

-- Move staged data into the production fact table.
-- The 19 columns from staging map to the 19 source columns of fact_flights.
-- flight_id (IDENTITY) and the computed columns auto-populate.
TRUNCATE TABLE fact_flights;
GO

INSERT INTO fact_flights (
    carrier_code, flight_date, flight_number, tail_number,
    origin_airport, destination_airport,
    scheduled_departure_time, actual_departure_time,
    scheduled_elapsed_minutes, actual_elapsed_minutes,
    departure_delay_minutes,
    wheels_off_time, taxi_out_minutes,
    carrier_delay_minutes, weather_delay_minutes,
    nas_delay_minutes, security_delay_minutes,
    late_aircraft_delay_minutes,
    is_cancelled
)
SELECT
    carrier_code, flight_date, flight_number, tail_number,
    origin_airport, destination_airport,
    scheduled_departure_time, actual_departure_time,
    scheduled_elapsed_minutes, actual_elapsed_minutes,
    departure_delay_minutes,
    wheels_off_time, taxi_out_minutes,
    carrier_delay_minutes, weather_delay_minutes,
    nas_delay_minutes, security_delay_minutes,
    late_aircraft_delay_minutes,
    is_cancelled
FROM stg_fact_flights;
GO

SELECT COUNT(*) AS total_rows FROM fact_flights;
GO

PRINT 'fact_flights loaded. Expected 495,771 rows.';
