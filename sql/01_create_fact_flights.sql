-- ============================================================
-- 01_create_fact_flights.sql
-- Creates the central fact table for the airline analytics warehouse.
--
-- Schema: 19 source columns from CSV + 1 surrogate PK + 2 computed cols
-- Constraints: NOT NULL on identifying columns, BIT for cancellation flag
-- Computed columns: departure_hour, flight_month (PERSISTED)
-- Indexes: 4 non-clustered indexes to support analytical queries
-- ============================================================

USE AirlineAnalytics;
GO

DROP TABLE IF EXISTS fact_flights;
GO

CREATE TABLE fact_flights (
    flight_id                   INT IDENTITY(1,1) PRIMARY KEY,

    carrier_code                CHAR(2)    NOT NULL,
    flight_date                 DATE       NOT NULL,
    flight_number               INT        NOT NULL,
    tail_number                 VARCHAR(10) NULL,
    origin_airport              CHAR(3)    NOT NULL,
    destination_airport         CHAR(3)    NOT NULL,

    scheduled_departure_time    TIME       NOT NULL,
    actual_departure_time       TIME       NULL,
    scheduled_elapsed_minutes   INT        NOT NULL,
    actual_elapsed_minutes      INT        NULL,
    departure_delay_minutes     INT        NULL,

    wheels_off_time             TIME       NULL,
    taxi_out_minutes            INT        NULL,

    carrier_delay_minutes       INT        NULL,
    weather_delay_minutes       INT        NULL,
    nas_delay_minutes           INT        NULL,
    security_delay_minutes      INT        NULL,
    late_aircraft_delay_minutes INT        NULL,

    is_cancelled                BIT        NOT NULL,

    -- Computed columns for time-of-day and seasonality analysis
    departure_hour AS DATEPART(HOUR, scheduled_departure_time) PERSISTED,
    flight_month   AS MONTH(flight_date)                       PERSISTED
);
GO

-- Indexes to support analytical query performance
CREATE INDEX idx_carrier_code     ON fact_flights(carrier_code);
CREATE INDEX idx_destination      ON fact_flights(destination_airport);
CREATE INDEX idx_flight_date      ON fact_flights(flight_date);
CREATE INDEX idx_departure_delay  ON fact_flights(departure_delay_minutes);
GO

PRINT 'fact_flights table created with 4 indexes.';
