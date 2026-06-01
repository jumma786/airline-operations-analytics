SELECT COUNT(*) FROM mia_aa;
SELECT COUNT(*) FROM atl_wn;
SELECT COUNT(*) FROM jfk_jetblue;
SELECT COUNT(*) FROM lex_psa;

sp_help mia_aa;
sp_help atl_wn;
sp_help jfk_jetblue;
sp_help lex_psa;


CREATE TABLE fact_flights (

    Carrier_Code NVARCHAR(50) NULL,

    Date_MM_DD_YYYY DATE NULL,

    Flight_Number INT NULL,

    Tail_Number NVARCHAR(50) NULL,

    Destination_Airport NVARCHAR(50) NULL,

    Scheduled_departure_time TIME NULL,

    Actual_departure_time TIME NULL,

    Scheduled_elapsed_time_Minutes INT NULL,

    Actual_elapsed_time_Minutes INT NULL,

    Departure_delay_Minutes INT NULL,

    Wheels_off_time TIME NULL,

    Taxi_Out_time_Minutes INT NULL,

    Delay_Carrier_Minutes INT NULL,

    Delay_Weather_Minutes INT NULL,

    Delay_National_Aviation_System_Minutes INT NULL,

    Delay_Security_Minutes INT NULL,

    Delay_Late_Aircraft_Arrival_Minutes INT NULL

);

INSERT INTO fact_flights
SELECT * FROM mia_aa

UNION ALL

SELECT * FROM atl_wn

UNION ALL

SELECT * FROM jfk_jetblue

UNION ALL

SELECT * FROM lex_psa;


SELECT COUNT(*)
FROM fact_flights;


SELECT
    COUNT(*) AS total_rows,

    COUNT(Actual_departure_time) AS actual_departure_non_null,

    COUNT(Departure_delay_Minutes) AS delay_non_null,

    COUNT(Taxi_Out_time_Minutes) AS taxi_non_null

FROM fact_flights;


SELECT DISTINCT Carrier_Code
FROM fact_flights;


SELECT COUNT(DISTINCT Destination_Airport)
FROM fact_flights;


SELECT TOP 10
    Destination_Airport,
    COUNT(*) AS total_flights
FROM fact_flights
GROUP BY Destination_Airport
ORDER BY total_flights DESC;

SELECT
    Carrier_Code,
    AVG(Departure_delay_Minutes) AS avg_delay
FROM fact_flights
GROUP BY Carrier_Code
ORDER BY avg_delay DESC;


SELECT
    COUNT(*) AS total_flights,
    
    AVG(Departure_delay_Minutes) AS average_delay,

    AVG(Taxi_Out_time_Minutes) AS average_taxi_out
FROM fact_flights;

SELECT
    AVG(Delay_Carrier_Minutes) AS carrier_delay,
    AVG(Delay_Weather_Minutes) AS weather_delay,
    AVG(Delay_National_Aviation_System_Minutes) AS nas_delay,
    AVG(Delay_Security_Minutes) AS security_delay
FROM fact_flights;


SELECT
    DATEPART(HOUR, Scheduled_departure_time) AS departure_hour,
    COUNT(*) AS total_flights
FROM fact_flights
GROUP BY DATEPART(HOUR, Scheduled_departure_time)
ORDER BY total_flights DESC;


SELECT TOP 10
    Destination_Airport,
    AVG(Departure_delay_Minutes) AS avg_delay
FROM fact_flights
GROUP BY Destination_Airport
ORDER BY avg_delay DESC;

SELECT
    Carrier_Code,
    
    COUNT(*) AS total_flights,

    AVG(Departure_delay_Minutes) AS avg_delay,

    AVG(Taxi_Out_time_Minutes) AS avg_taxi_out

FROM fact_flights

GROUP BY Carrier_Code

ORDER BY avg_delay;


CREATE INDEX idx_carrier
ON fact_flights(Carrier_Code);

CREATE INDEX idx_destination
ON fact_flights(Destination_Airport);


CREATE INDEX idx_flight_date
ON fact_flights(Date_MM_DD_YYYY);


