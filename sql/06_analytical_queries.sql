-- ============================================================
-- 06_analytical_queries.sql
-- Six analytical queries that derive the headline KPIs and insights
-- from the cleaned warehouse data.
--
-- Methodology:
--   - On-time definition: departure_delay_minutes < 15 (US DOT standard)
--   - Operational metrics exclude cancelled flights (is_cancelled = 0)
--   - Cancellation rate computed across all flights
-- ============================================================

USE AirlineAnalytics;
GO

-- ============================================================
-- QUERY 1: Headline KPIs
-- ============================================================
SELECT
    COUNT(*)                                              AS total_flights,
    SUM(CAST(is_cancelled AS INT))                        AS cancelled_flights,
    CAST(100.0 * SUM(CAST(is_cancelled AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS cancellation_rate_pct,

    AVG(CASE WHEN is_cancelled = 0 THEN departure_delay_minutes END) AS avg_departure_delay_min,
    AVG(CASE WHEN is_cancelled = 0 THEN taxi_out_minutes END)        AS avg_taxi_out_min,

    CAST(100.0 *
        SUM(CASE WHEN is_cancelled = 0 AND departure_delay_minutes < 15 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN is_cancelled = 0 THEN 1 ELSE 0 END), 0)
    AS DECIMAL(5,2)) AS on_time_pct
FROM fact_flights;
GO

-- Expected: 495,771 total | 9,056 cancelled | 1.83% cancel rate
--           17.95 avg delay | 19.87 avg taxi | 71.84% on-time


-- ============================================================
-- QUERY 2: Carrier comparison (joins to dim_carrier)
-- ============================================================
SELECT
    c.carrier_name,
    c.carrier_type,
    COUNT(*) AS total_flights,
    SUM(CAST(f.is_cancelled AS INT)) AS cancelled,
    CAST(100.0 * SUM(CAST(f.is_cancelled AS INT)) / COUNT(*) AS DECIMAL(5,2)) AS cancel_rate_pct,
    CAST(AVG(CASE WHEN f.is_cancelled = 0 THEN CAST(f.departure_delay_minutes AS DECIMAL(10,2)) END) AS DECIMAL(6,2)) AS avg_delay_min,
    CAST(AVG(CASE WHEN f.is_cancelled = 0 THEN CAST(f.taxi_out_minutes AS DECIMAL(10,2)) END) AS DECIMAL(6,2)) AS avg_taxi_min,
    CAST(100.0 *
        SUM(CASE WHEN f.is_cancelled = 0 AND f.departure_delay_minutes < 15 THEN 1 ELSE 0 END)
        / NULLIF(SUM(CASE WHEN f.is_cancelled = 0 THEN 1 ELSE 0 END), 0)
    AS DECIMAL(5,2)) AS on_time_pct
FROM fact_flights f
JOIN dim_carrier c ON f.carrier_code = c.carrier_code
GROUP BY c.carrier_name, c.carrier_type
ORDER BY total_flights DESC;
GO

-- Expected:
--   American Airlines:  242,907 / 1.80% / 20.28 min / 71.59% on-time
--   Southwest Airlines: 125,959 / 1.27% / 13.40 min / 73.79% on-time
--   JetBlue Airways:    120,592 / 2.44% / 21.00 min / 69.66% on-time
--   PSA Airlines:         6,313 / 2.52% /  9.74 min / 83.59% on-time


-- ============================================================
-- QUERY 3: Seasonal pattern (joins to dim_date)
-- ============================================================
SELECT
    d.season,
    COUNT(*) AS flights,
    CAST(AVG(CAST(f.departure_delay_minutes AS DECIMAL(10,2))) AS DECIMAL(6,2)) AS avg_delay_min,
    CAST(100.0 * SUM(CASE WHEN f.departure_delay_minutes < 15 THEN 1 ELSE 0 END) / COUNT(*) AS DECIMAL(5,2)) AS on_time_pct
FROM fact_flights f
JOIN dim_date d ON f.flight_date = d.date_key
WHERE f.is_cancelled = 0
GROUP BY d.season
ORDER BY avg_delay_min DESC;
GO

-- Expected:
--   Summer: 115,990 flights / 27.19 min / 64.07%
--   Spring: 123,419 flights / 18.83 min / 71.20%
--   Winter: 135,013 flights / 16.00 min / 73.89%
--   Autumn: 112,293 flights / 12.45 min / 78.10%


-- ============================================================
-- QUERY 4: Monthly delay trend
-- ============================================================
SELECT
    d.month_num,
    d.month_name,
    COUNT(*) AS flights,
    CAST(AVG(CAST(f.departure_delay_minutes AS DECIMAL(10,2))) AS DECIMAL(6,2)) AS avg_delay_min
FROM fact_flights f
JOIN dim_date d ON f.flight_date = d.date_key
WHERE f.is_cancelled = 0
GROUP BY d.month_num, d.month_name
ORDER BY d.month_num;
GO

-- Expected: July is the worst month (30.50 min); October is the best (11.34 min).


-- ============================================================
-- QUERY 5: Time-of-day pattern
-- ============================================================
SELECT
    f.departure_hour,
    COUNT(*) AS flights,
    CAST(AVG(CAST(f.departure_delay_minutes AS DECIMAL(10,2))) AS DECIMAL(6,2)) AS avg_delay_min
FROM fact_flights f
WHERE f.is_cancelled = 0
GROUP BY f.departure_hour
ORDER BY f.departure_hour;
GO

-- Expected pattern:
--   Volume: M-shape with peaks at 8am (~47K) and 9pm (~51K)
--   Delay:  steady climb from 2.70 min at 6am to 30.38 min at 23:00
--   This shows the delay-accumulation / late-aircraft cascade effect.


-- ============================================================
-- QUERY 6: Delay cause breakdown
-- ============================================================
SELECT
    SUM(f.carrier_delay_minutes)       AS carrier_delay_total,
    SUM(f.late_aircraft_delay_minutes) AS late_aircraft_total,
    SUM(f.nas_delay_minutes)           AS nas_delay_total,
    SUM(f.weather_delay_minutes)       AS weather_delay_total,
    SUM(f.security_delay_minutes)      AS security_delay_total
FROM fact_flights f
WHERE f.is_cancelled = 0;
GO

-- Expected (total minutes):
--   Carrier:        3,565,346  (39.0%)
--   Late Aircraft:  3,542,302  (38.7%)
--   NAS:            1,661,956  (18.2%)
--   Weather:          438,048  ( 4.8%)
--   Security:          27,439  ( 0.3%)
-- Together, Carrier + Late Aircraft account for 77.7% of all delay minutes.
