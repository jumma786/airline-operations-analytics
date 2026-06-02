-- ============================================================
-- 05_foreign_keys.sql
-- Adds foreign key constraints from fact_flights to the dimensions.
--
-- These constraints enforce referential integrity and also serve as
-- a data validation pass: if any FK fails, it means there is a value
-- in fact_flights that does not exist in the referenced dimension.
--
-- Note: destination_airport is NOT constrained because the dim_airport
-- table covers only the 4 origin airports, while destinations span
-- 100+ airports.
-- ============================================================

USE AirlineAnalytics;
GO

-- Carrier FK
ALTER TABLE fact_flights
ADD CONSTRAINT fk_flights_carrier
FOREIGN KEY (carrier_code) REFERENCES dim_carrier(carrier_code);
GO

-- Origin airport FK
ALTER TABLE fact_flights
ADD CONSTRAINT fk_flights_origin
FOREIGN KEY (origin_airport) REFERENCES dim_airport(airport_code);
GO

-- Date FK
ALTER TABLE fact_flights
ADD CONSTRAINT fk_flights_date
FOREIGN KEY (flight_date) REFERENCES dim_date(date_key);
GO

PRINT 'Foreign keys applied: fk_flights_carrier, fk_flights_origin, fk_flights_date.';
