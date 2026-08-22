-- =============================================================
-- Table: dim_date
-- Grain: One row per calendar date
-- Source: Generated (date spine 2016-01-01 through 2018-12-31)
-- Surrogate key: date_key (INTEGER YYYYMMDD)
-- SCD Type: N/A (static reference table)
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================
IF
    NOT EXISTS (
        SELECT 1 FROM sys.schemas
        WHERE name = 'Gold'
    )
    EXEC ('CREATE SCHEMA [Gold]');
DROP TABLE IF EXISTS [Gold].dim_date;
CREATE TABLE [Gold].dim_date (
    date_key INTEGER NOT NULL,
    full_date DATE NOT NULL,
    [year] SMALLINT NOT NULL,  -- noqa: RF06
    quarter SMALLINT NOT NULL,
    quarter_name VARCHAR(10) NOT NULL,
    [month] SMALLINT NOT NULL,  -- noqa: RF06
    month_name VARCHAR(20) NOT NULL,
    month_year VARCHAR(10) NOT NULL,
    month_sort INT NOT NULL,
    week_of_year SMALLINT NOT NULL,
    day_of_month SMALLINT NOT NULL,
    day_of_week SMALLINT NOT NULL,
    day_name VARCHAR(20) NOT NULL,
    is_weekend BIT NOT NULL,
    is_month_end BIT NOT NULL,
    year_offset SMALLINT NOT NULL
);
INSERT INTO [Gold].dim_date (
    date_key, full_date, [year], quarter, quarter_name,  -- noqa: RF06
    [month], month_name, month_year, month_sort, week_of_year,  -- noqa: RF06
    day_of_month, day_of_week, day_name, is_weekend, is_month_end, year_offset
)
SELECT
    CAST(FORMAT(dt, 'yyyyMMdd') AS INT) AS date_key,
    dt AS full_date,
    CAST(YEAR(dt) AS SMALLINT) AS [year],  -- noqa: RF06
    CAST(DATEPART(QUARTER, dt) AS SMALLINT) AS quarter,
    CONCAT('Q', DATEPART(QUARTER, dt)) AS quarter_name,
    CAST(MONTH(dt) AS SMALLINT) AS [month],  -- noqa: RF06
    DATENAME(MONTH, dt) AS month_name,
    CONCAT(FORMAT(dt, 'MMM'), '-', YEAR(dt)) AS month_year,
    CAST(YEAR(dt) AS INT) * 100
    + CAST(MONTH(dt) AS INT) AS month_sort,
    CAST(DATEPART(WEEK, dt) AS SMALLINT) AS week_of_year,
    CAST(DAY(dt) AS SMALLINT) AS day_of_month,
    CAST(DATEPART(WEEKDAY, dt) AS SMALLINT) AS day_of_week,
    DATENAME(WEEKDAY, dt) AS day_name,
    CAST(CASE WHEN DATEPART(WEEKDAY, dt) IN (1, 7) THEN 1 ELSE 0 END AS BIT)
        AS is_weekend,
    CAST(CASE WHEN dt = EOMONTH(dt) THEN 1 ELSE 0 END AS BIT) AS is_month_end,
    CAST(YEAR(dt) - YEAR(GETDATE()) AS SMALLINT) AS year_offset
FROM (
    SELECT DATEADD(DAY, value, CAST('2016-01-01' AS DATE)) AS dt
    FROM GENERATE_SERIES(0, DATEDIFF(DAY, '2016-01-01', '2018-12-31'))
) AS calendar;
