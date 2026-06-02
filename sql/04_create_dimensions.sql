-- ============================================================
-- 04_create_dimensions.sql
-- Creates the three dimension tables for the star schema.
--
-- dim_carrier: 4 rows - one per carrier in the dataset
-- dim_airport: 4 rows - one per origin airport (NOT destinations)
-- dim_date:    1,520 rows - daily calendar 2022-01-01 to 2026-02-28
-- ============================================================

USE AirlineAnalytics;
GO

-- ------------------------------------------------------------
-- dim_carrier
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dim_carrier;
GO

CREATE TABLE dim_carrier (
    carrier_code CHAR(2)    PRIMARY KEY,
    carrier_name VARCHAR(50) NOT NULL,
    carrier_type VARCHAR(20) NOT NULL   -- Major / Low-Cost / Regional
);
GO

INSERT INTO dim_carrier (carrier_code, carrier_name, carrier_type) VALUES
('AA', 'American Airlines',  'Major'),
('WN', 'Southwest Airlines', 'Low-Cost'),
('B6', 'JetBlue Airways',    'Low-Cost'),
('OH', 'PSA Airlines',       'Regional');
GO

-- ------------------------------------------------------------
-- dim_airport
-- Note: covers only the 4 origin airports. Destination airports
-- (100+ values) are not constrained to this dimension.
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dim_airport;
GO

CREATE TABLE dim_airport (
    airport_code CHAR(3)     PRIMARY KEY,
    airport_name VARCHAR(100) NOT NULL,
    city         VARCHAR(50)  NOT NULL,
    state        CHAR(2)      NOT NULL,
    airport_role VARCHAR(20)  NOT NULL   -- Hub / Regional
);
GO

INSERT INTO dim_airport (airport_code, airport_name, city, state, airport_role) VALUES
('MIA', 'Miami International Airport',      'Miami',     'FL', 'Hub'),
('ATL', 'Hartsfield-Jackson Atlanta Intl',  'Atlanta',   'GA', 'Hub'),
('JFK', 'John F. Kennedy International',    'New York',  'NY', 'Hub'),
('LEX', 'Blue Grass Airport',               'Lexington', 'KY', 'Regional');
GO

-- ------------------------------------------------------------
-- dim_date
-- Built via recursive CTE. Includes is_partial_year flag for 2026
-- (only Jan-Feb available). day_of_week is calculated
-- DATEFIRST-independently (always 1=Mon, 7=Sun).
-- ------------------------------------------------------------
DROP TABLE IF EXISTS dim_date;
GO

CREATE TABLE dim_date (
    date_key        DATE        PRIMARY KEY,
    year_num        INT         NOT NULL,
    quarter_num     TINYINT     NOT NULL,
    month_num       TINYINT     NOT NULL,
    month_name      VARCHAR(10) NOT NULL,
    day_of_month    TINYINT     NOT NULL,
    day_of_week     TINYINT     NOT NULL,   -- 1=Mon ... 7=Sun
    day_name        VARCHAR(10) NOT NULL,
    is_weekend      BIT         NOT NULL,
    season          VARCHAR(10) NOT NULL,
    is_partial_year BIT         NOT NULL    -- flags 2026 (Jan-Feb only)
);
GO

WITH date_range AS (
    SELECT CAST('2022-01-01' AS DATE) AS d
    UNION ALL
    SELECT DATEADD(DAY, 1, d) FROM date_range WHERE d < '2026-02-28'
)
INSERT INTO dim_date
SELECT
    d,
    YEAR(d),
    DATEPART(QUARTER, d),
    MONTH(d),
    DATENAME(MONTH, d),
    DAY(d),
    ((DATEPART(WEEKDAY, d) + @@DATEFIRST - 2) % 7) + 1,   -- 1=Mon..7=Sun, DATEFIRST-independent
    DATENAME(WEEKDAY, d),
    CASE WHEN DATENAME(WEEKDAY, d) IN ('Saturday','Sunday') THEN 1 ELSE 0 END,
    CASE
        WHEN MONTH(d) IN (12, 1, 2) THEN 'Winter'
        WHEN MONTH(d) IN (3, 4, 5)  THEN 'Spring'
        WHEN MONTH(d) IN (6, 7, 8)  THEN 'Summer'
        ELSE                              'Autumn'
    END,
    CASE WHEN YEAR(d) = 2026 THEN 1 ELSE 0 END
FROM date_range
OPTION (MAXRECURSION 2000);
GO

SELECT COUNT(*) AS day_count,
       MIN(date_key) AS first_day,
       MAX(date_key) AS last_day
FROM dim_date;
GO

PRINT 'Dimensions created: dim_carrier (4), dim_airport (4), dim_date (1,520 days expected).';
