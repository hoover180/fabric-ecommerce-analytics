-- =============================================================
-- Table: dim_sellers
-- Grain: One row per seller (seller_id)
-- Source: Silver.sellers LEFT JOIN Silver.geolocation
--         Pre-aggregated: total_orders, on_time_rate, avg_review_score
-- Surrogate key: seller_key (MD5 hash of seller_id)
-- SCD Type: 1 (overwrite on reload)
-- Note: total_orders, on_time_rate, avg_review_score denormalized into
--       dim for reporting performance (Kimball pattern).
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

DROP TABLE IF EXISTS dbo.dim_sellers;

CREATE TABLE dbo.dim_sellers (
    seller_key          VARCHAR(32)     NOT NULL,
    seller_id           VARCHAR(50)     NOT NULL,
    seller_city         VARCHAR(100)    NULL,
    seller_state        VARCHAR(2)      NULL,
    geolocation_lat     FLOAT           NULL,
    geolocation_lng     FLOAT           NULL,
    total_orders        INTEGER         NULL,
    on_time_rate        FLOAT           NULL,
    avg_review_score    FLOAT           NULL
);

WITH geo_by_zip AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat)    AS geo_lat,
        AVG(geolocation_lng)    AS geo_lng
    FROM ecommerce_lakehouse.Silver.geolocation
    GROUP BY geolocation_zip_code_prefix
),
seller_stats AS (
    SELECT
        oi.seller_id,
        COUNT(*)                                AS total_orders,
        AVG(CAST(1 - o.is_late AS FLOAT))       AS on_time_rate,
        AVG(CAST(r.review_score AS FLOAT))       AS avg_review_score
    FROM ecommerce_lakehouse.Silver.order_items AS oi
    INNER JOIN ecommerce_lakehouse.Silver.orders AS o
        ON oi.order_id = o.order_id
    LEFT JOIN ecommerce_lakehouse.Silver.order_reviews AS r
        ON oi.order_id = r.order_id
    GROUP BY oi.seller_id
)
INSERT INTO dbo.dim_sellers (
    seller_key, seller_id, seller_city, seller_state,
    geolocation_lat, geolocation_lng,
    total_orders, on_time_rate, avg_review_score
)
SELECT
    LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', s.seller_id), 2))   AS seller_key,
    s.seller_id,
    s.seller_city,
    s.seller_state,
    g.geo_lat                                                        AS geolocation_lat,
    g.geo_lng                                                        AS geolocation_lng,
    st.total_orders,
    st.on_time_rate,
    st.avg_review_score
FROM ecommerce_lakehouse.Silver.sellers AS s
LEFT JOIN geo_by_zip AS g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
LEFT JOIN seller_stats AS st
    ON s.seller_id = st.seller_id;