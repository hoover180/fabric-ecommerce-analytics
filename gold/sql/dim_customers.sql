-- =============================================================
-- Table: dim_customers
-- Grain: One row per unique customer (customer_unique_id)
-- Source: Silver.customers LEFT JOIN Silver.geolocation
-- Surrogate key: customer_key (MD5 hash of customer_unique_id)
-- SCD Type: 1 (overwrite on reload)
-- Note: Silver.customers grain is customer_id (order-scoped per the
--   source schema — one row per order-level customer record, not per
--   distinct human). Deduplication to customer_unique_id grain applied
--   here at Gold load via ROW_NUMBER(), the correct layer for this
--   transformation. Geolocation joined at zip-prefix level; AVG lat/lng
--   guards against multi-row matches from Silver.geolocation.
-- Added customer_state_country to disambiguate Brazilian state codes
--   from colliding international place names (e.g. PA, AP, RO) when
--   used as the Location field in a Power BI Filled Map visual.
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

DROP TABLE IF EXISTS [Gold].dim_customers;

CREATE TABLE [Gold].dim_customers (
    customer_key VARCHAR(32) NOT NULL,
    customer_unique_id VARCHAR(50) NOT NULL,
    customer_city VARCHAR(100) NULL,
    customer_state VARCHAR(2) NULL,
    customer_state_country VARCHAR(40) NULL,
    geolocation_lat FLOAT NULL,
    geolocation_lng FLOAT NULL
);

WITH geo_by_zip AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS geo_lat,
        AVG(geolocation_lng) AS geo_lng
    FROM ecommerce_lakehouse.[Silver].geolocation
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
    FROM ecommerce_lakehouse.[Silver].customers
)

INSERT INTO [Gold].dim_customers (
    customer_key, customer_unique_id, customer_city,
    customer_state, customer_state_country, geolocation_lat, geolocation_lng
)
SELECT
    LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', c.customer_unique_id), 2))
        AS customer_key,
    c.customer_unique_id,
    c.customer_city,
    c.customer_state,
    CASE c.customer_state
        WHEN 'AC' THEN 'Acre, Brazil'
        WHEN 'AL' THEN 'Alagoas, Brazil'
        WHEN 'AM' THEN 'Amazonas, Brazil'
        WHEN 'AP' THEN 'Amapá, Brazil'
        WHEN 'BA' THEN 'Bahia, Brazil'
        WHEN 'CE' THEN 'Ceará, Brazil'
        WHEN 'DF' THEN 'Distrito Federal, Brazil'
        WHEN 'ES' THEN 'Espírito Santo, Brazil'
        WHEN 'GO' THEN 'Goiás, Brazil'
        WHEN 'MA' THEN 'Maranhão, Brazil'
        WHEN 'MG' THEN 'Minas Gerais, Brazil'
        WHEN 'MS' THEN 'Mato Grosso do Sul, Brazil'
        WHEN 'MT' THEN 'Mato Grosso, Brazil'
        WHEN 'PA' THEN 'Pará, Brazil'
        WHEN 'PB' THEN 'Paraíba, Brazil'
        WHEN 'PE' THEN 'Pernambuco, Brazil'
        WHEN 'PI' THEN 'Piauí, Brazil'
        WHEN 'PR' THEN 'Paraná, Brazil'
        WHEN 'RJ' THEN 'Rio de Janeiro, Brazil'
        WHEN 'RN' THEN 'Rio Grande do Norte, Brazil'
        WHEN 'RO' THEN 'Rondônia, Brazil'
        WHEN 'RR' THEN 'Roraima, Brazil'
        WHEN 'RS' THEN 'Rio Grande do Sul, Brazil'
        WHEN 'SC' THEN 'Santa Catarina, Brazil'
        WHEN 'SE' THEN 'Sergipe, Brazil'
        WHEN 'SP' THEN 'São Paulo, Brazil'
        WHEN 'TO' THEN 'Tocantins, Brazil'
        ELSE c.customer_state + ', Brazil'
    END AS customer_state_country,
    g.geo_lat AS geolocation_lat,
    g.geo_lng AS geolocation_lng
FROM latest_customer AS c
LEFT JOIN geo_by_zip AS g
    ON c.customer_zip_code_prefix = g.geolocation_zip_code_prefix
WHERE c.rn = 1;
