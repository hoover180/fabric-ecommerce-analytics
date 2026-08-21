-- =============================================================
-- Table: dim_sellers
-- Grain: One row per seller (seller_id)
-- Source: Silver.sellers LEFT JOIN Silver.geolocation
--         Pre-aggregated: total_orders, on_time_rate, avg_review_score
-- Surrogate key: seller_key (MD5 hash of seller_id)
-- SCD Type: 1 (overwrite on reload)
-- Note: total_orders, on_time_rate, avg_review_score denormalized into
--       dim for reporting performance (Kimball pattern).
-- Note: total_orders uses COUNT(DISTINCT order_id), not COUNT(*), since
--       source is order_items (item grain, not order grain).
-- Note: order_reviews deduplicated via ROW_NUMBER() (most recent review
--       per order) before joining, to prevent seller total_orders/
--       on_time_rate inflation from duplicate review rows per order_id.
-- Note: on_time_rate/sla_compliance_bucket deduplicated to (seller_id,
--       order_id) grain via seller_order_grain CTE before averaging
--       is_late — source join (order_items/orders) is item grain, and
--       averaging is_late directly over item rows overweights sellers
--       with more multi-item orders.
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

DROP TABLE IF EXISTS [Gold].dim_sellers;

CREATE TABLE [Gold].dim_sellers (
    seller_key VARCHAR(32) NOT NULL,
    seller_id VARCHAR(50) NOT NULL,
    seller_city VARCHAR(100) NULL,
    seller_state VARCHAR(2) NULL,
    sla_compliance_bucket VARCHAR(10) NULL,
    geolocation_lat FLOAT NULL,
    geolocation_lng FLOAT NULL,
    total_orders INTEGER NULL,
    on_time_rate FLOAT NULL,
    avg_review_score FLOAT NULL
);

WITH geo_by_zip AS (
    SELECT
        geolocation_zip_code_prefix,
        AVG(geolocation_lat) AS geo_lat,
        AVG(geolocation_lng) AS geo_lng
    FROM ecommerce_lakehouse.[Silver].geolocation
    GROUP BY geolocation_zip_code_prefix
),

seller_order_grain AS (
    SELECT DISTINCT
        oi.seller_id,
        oi.order_id,
        o.is_late
    FROM ecommerce_lakehouse.[Silver].order_items AS oi
    INNER JOIN ecommerce_lakehouse.[Silver].orders AS o
        ON oi.order_id = o.order_id
),

latest_review AS (
    SELECT
        order_id,
        review_score,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_creation_date DESC
        ) AS rn
    FROM ecommerce_lakehouse.[Silver].order_reviews
),

seller_stats AS (
    SELECT
        seller_order_grain.seller_id,
        COUNT(DISTINCT seller_order_grain.order_id) AS total_orders,
        AVG(CAST(1 - seller_order_grain.is_late AS FLOAT)) AS on_time_rate,
        CASE
            WHEN AVG(CAST(1 - seller_order_grain.is_late AS FLOAT)) < 0.6
                THEN '0-60%'
            WHEN AVG(CAST(1 - seller_order_grain.is_late AS FLOAT)) < 0.8
                THEN '60-80%'
            WHEN AVG(CAST(1 - seller_order_grain.is_late AS FLOAT)) < 0.9
                THEN '80-90%'
            ELSE '90-100%'
        END AS sla_compliance_bucket,
        AVG(CAST(latest_review.review_score AS FLOAT)) AS avg_review_score
    FROM
        seller_order_grain
    LEFT JOIN latest_review
        ON
            seller_order_grain.order_id = latest_review.order_id
            AND latest_review.rn = 1
    GROUP BY seller_order_grain.seller_id
)

INSERT INTO [Gold].dim_sellers (
    seller_key, seller_id, seller_city, seller_state,
    sla_compliance_bucket,
    geolocation_lat, geolocation_lng,
    total_orders, on_time_rate, avg_review_score
)
SELECT
    LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', s.seller_id), 2)) AS seller_key,
    s.seller_id,
    s.seller_city,
    s.seller_state,
    st.sla_compliance_bucket,
    g.geo_lat AS geolocation_lat,
    g.geo_lng AS geolocation_lng,
    st.total_orders,
    st.on_time_rate,
    st.avg_review_score
FROM ecommerce_lakehouse.[Silver].sellers AS s
LEFT JOIN geo_by_zip AS g
    ON s.seller_zip_code_prefix = g.geolocation_zip_code_prefix
LEFT JOIN seller_stats AS st
    ON s.seller_id = st.seller_id;
