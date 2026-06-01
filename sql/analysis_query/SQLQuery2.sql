/* =========================================================
PHASE 7 — ADVANCED SQL ANALYTICS
Project: Airline Operations Intelligence System
========================================================= */


/* =========================================================
1. MONTHLY DELAY TREND ANALYSIS
========================================================= */

SELECT
    YEAR(Date_MM_DD_YYYY) AS flight_year,

    MONTH(Date_MM_DD_YYYY) AS flight_month,

    AVG(Departure_delay_Minutes) AS average_delay

FROM fact_flights

GROUP BY
    YEAR(Date_MM_DD_YYYY),
    MONTH(Date_MM_DD_YYYY)

ORDER BY
    flight_year,
    flight_month;



/* =========================================================
2. AIRLINE ON-TIME PERFORMANCE %
========================================================= */

SELECT
    Carrier_Code,

    COUNT(*) AS total_flights,

    SUM(
        CASE
            WHEN Departure_delay_Minutes <= 15 THEN 1
            ELSE 0
        END
    ) * 100.0 / COUNT(*) AS on_time_percentage

FROM fact_flights

GROUP BY Carrier_Code

ORDER BY on_time_percentage DESC;



/* =========================================================
3. DELAY CATEGORY DISTRIBUTION
========================================================= */

SELECT

    CASE

        WHEN Departure_delay_Minutes <= 0
            THEN 'On Time / Early'

        WHEN Departure_delay_Minutes <= 15
            THEN 'Minor Delay'

        WHEN Departure_delay_Minutes <= 60
            THEN 'Moderate Delay'

        ELSE 'Severe Delay'

    END AS delay_category,

    COUNT(*) AS total_flights

FROM fact_flights

GROUP BY

    CASE

        WHEN Departure_delay_Minutes <= 0
            THEN 'On Time / Early'

        WHEN Departure_delay_Minutes <= 15
            THEN 'Minor Delay'

        WHEN Departure_delay_Minutes <= 60
            THEN 'Moderate Delay'

        ELSE 'Severe Delay'

    END

ORDER BY total_flights DESC;



/* =========================================================
4. TOP 10 MOST DELAYED DESTINATIONS
========================================================= */

SELECT TOP 10

    Destination_Airport,

    AVG(Departure_delay_Minutes) AS average_delay,

    COUNT(*) AS total_flights

FROM fact_flights

GROUP BY Destination_Airport

ORDER BY average_delay DESC;



/* =========================================================
5. AIRLINE RELIABILITY ANALYSIS
========================================================= */

SELECT

    Carrier_Code,

    COUNT(*) AS total_flights,

    AVG(Departure_delay_Minutes) AS average_delay,

    AVG(Taxi_Out_time_Minutes) AS average_taxi_out

FROM fact_flights

GROUP BY Carrier_Code

ORDER BY average_delay;



/* =========================================================
6. PEAK FLIGHT HOURS ANALYSIS
========================================================= */

SELECT

    DATEPART(HOUR, Scheduled_departure_time) AS departure_hour,

    COUNT(*) AS total_flights

FROM fact_flights

GROUP BY DATEPART(HOUR, Scheduled_departure_time)

ORDER BY total_flights DESC;



/* =========================================================
7. DELAY CAUSE ANALYSIS
========================================================= */

SELECT

    AVG(Delay_Carrier_Minutes) AS carrier_delay,

    AVG(Delay_Weather_Minutes) AS weather_delay,

    AVG(Delay_National_Aviation_System_Minutes) AS nas_delay,

    AVG(Delay_Security_Minutes) AS security_delay,

    AVG(Delay_Late_Aircraft_Arrival_Minutes) AS late_aircraft_delay

FROM fact_flights;



/* =========================================================
8. MOST ACTIVE DESTINATIONS
========================================================= */

SELECT TOP 10

    Destination_Airport,

    COUNT(*) AS total_flights

FROM fact_flights

GROUP BY Destination_Airport

ORDER BY total_flights DESC;



/* =========================================================
9. AIRLINE MARKET SHARE
========================================================= */

SELECT

    Carrier_Code,

    COUNT(*) AS total_flights,

    COUNT(*) * 100.0 /
    (SELECT COUNT(*) FROM fact_flights) AS market_share_percentage

FROM fact_flights

GROUP BY Carrier_Code

ORDER BY market_share_percentage DESC;



/* =========================================================
10. CREATE PERFORMANCE INDEXES
========================================================= */

CREATE INDEX idx_carrier
ON fact_flights(Carrier_Code);


CREATE INDEX idx_destination
ON fact_flights(Destination_Airport);


CREATE INDEX idx_flight_date
ON fact_flights(Date_MM_DD_YYYY);


CREATE INDEX idx_departure_delay
ON fact_flights(Departure_delay_Minutes);



/* =========================================================
11. VERIFY INDEXES
========================================================= */

EXEC sp_helpindex 'fact_flights';



/* =========================================================
12. FINAL EXECUTIVE KPI QUERY
========================================================= */

SELECT

    COUNT(*) AS total_flights,

    AVG(Departure_delay_Minutes) AS average_departure_delay,

    AVG(Taxi_Out_time_Minutes) AS average_taxi_out_time,

    COUNT(DISTINCT Destination_Airport) AS total_destinations,

    COUNT(DISTINCT Carrier_Code) AS total_airlines

FROM fact_flights;