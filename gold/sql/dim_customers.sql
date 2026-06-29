-- =============================================================
-- Table: dim_customers
-- Grain: One row per unique customer (customer_unique_id)
-- Source: Silver.customers LEFT JOIN Silver.geolocation
-- Surrogate key: customer_key (MD5 hash of customer_unique_id)
-- SCD Type: 1 (overwrite on reload)
-- Note: Silver.customers grain is customer_id (order-scoped per Olist schema).
--       Deduplication to customer_unique_id grain applied at Gold load via
--       ROW_NUMBER() — correct layer for this transformation.
--       Geolocation joined at zip prefix level; AVG lat/lng guards
--       against multi-row matches from Silver geolocation table.
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

DROP TABLE IF EXISTS dbo.dim_customers;

CREATE TABLE dbo.dim_customers (
    customer_key        VARCHAR(32)     NOT NULL,
    customer_unique_id  VARCHAR(50)     NOT NULL,
    customer_city       VARCHAR(100)    NULL,
    customer_state      VARCHAR(2)      NULL,
    geolocation_lat     FLOAT           NULL,
    geolocation_lng     FLOAT           NULL
);

WITH geo_by_zip AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat)    AS geo_lat,
        AVG(geolocation_lng)    AS geo_lng
    FROM ecommerce_lakehouse.Silver.geolocation
    GROUP BY geolocation_zip_code_prefix
),
latest_customer AS (
    SELECT
        customer_unique_id,
        customer_city,
        customer_state,
        customer_zip_code_prefix,
        ROW_NUMBER() OVER (
            PARTITION BY customer_unique_id
            ORDER BY customer_id DESC
        ) AS rn
    FROM ecommerce_lakehouse.Silver.customers
)
INSERT INTO dbo.dim_customers (
    customer_key, customer_unique_id, customer_city,
    customer_state, geolocation_lat, geolocation_lng
)
SELECT
    LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', c.customer_unique_id), 2))  AS customer_key,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    g.geo_lat                                                                AS geolocation_lat,
    g.geo_lng                                                                AS geolocation_lng
FROM latest_customer AS c
LEFT JOIN geo_by_zip AS g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE c.rn = 1;