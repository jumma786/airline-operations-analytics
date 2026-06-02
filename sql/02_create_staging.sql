-- ============================================================
-- 02_create_staging.sql
-- Creates the staging table for BULK INSERT.
--
-- The staging table mirrors the CSV structure exactly (19 columns,
-- same order as the CSV). This is necessary because BULK INSERT
-- maps CSV columns positionally to table columns and does not
-- automatically skip IDENTITY or computed columns.
--
-- Workflow:
--   1. BULK INSERT loads the CSV into stg_fact_flights
--   2. INSERT...SELECT moves data into the real fact_flights table,
--      where IDENTITY and computed columns auto-populate
-- ============================================================

USE AirlineAnalytics;
GO

DROP TABLE IF EXISTS stg_fact_flights;
GO

CREATE TABLE stg_fact_flights (
    carrier_code                CHAR(2),
    flight_date                 DATE,
    flight_number               INT,
    tail_number                 VARCHAR(10),
    origin_airport              CHAR(3),
    destination_airport         CHAR(3),
    scheduled_departure_time    TIME,
    actual_departure_time       TIME,
    scheduled_elapsed_minutes   INT,
    actual_elapsed_minutes      INT,
    departure_delay_minutes     INT,
    wheels_off_time             TIME,
    taxi_out_minutes            INT,
    carrier_delay_minutes       INT,
    weather_delay_minutes       INT,
    nas_delay_minutes           INT,
    security_delay_minutes      INT,
    late_aircraft_delay_minutes INT,
    is_cancelled                BIT
);
GO

PRINT 'stg_fact_flights staging table created (19 columns, matches CSV).';
