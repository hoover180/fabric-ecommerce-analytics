-- =============================================================
-- Table: fact_orders
-- Grain: One row per order item (order_id + order_item_id)
-- Source: Silver.orders, Silver.order_items, Silver.order_reviews,
--         Silver.order_payments + all four dimension tables
-- Surrogate key: order_item_key (MD5 hash of order_id + order_item_id)
-- Degenerate dimensions: order_id, order_item_id, order_status
-- Note: review_score sourced from most recent review per order.
--       ~23 rows expected with null review_score (tolerated — source data).
--       payment_value aggregated to order level from Silver.order_payments.
--       customer_unique_id resolved via Silver.customers join on customer_id.
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

DROP TABLE IF EXISTS dbo.fact_orders;

CREATE TABLE dbo.fact_orders (
    order_item_key              VARCHAR(32)     NOT NULL,
    order_id                    VARCHAR(50)     NOT NULL,
    order_item_id               INTEGER         NOT NULL,
    customer_key                VARCHAR(32)     NOT NULL,
    seller_key                  VARCHAR(32)     NOT NULL,
    product_key                 VARCHAR(32)     NOT NULL,
    order_date_key              INTEGER         NULL,
    delivery_date_key           INTEGER         NULL,
    estimated_delivery_date_key INTEGER         NULL,
    price                       DECIMAL(10,2)   NULL,
    freight_value               DECIMAL(10,2)   NULL,
    payment_value               DECIMAL(10,2)   NULL,
    review_score                SMALLINT        NULL,
    delivery_days               INTEGER         NULL,
    days_late                   INTEGER         NULL,
    is_late                     SMALLINT        NULL,
    is_delivered                SMALLINT        NULL,
    order_status                VARCHAR(20)     NULL
);

WITH latest_review AS (
    SELECT
        order_id,
        review_score,
        ROW_NUMBER() OVER (
            PARTITION BY order_id
            ORDER BY review_answer_timestamp DESC
        ) AS rn
    FROM ecommerce_lakehouse.Silver.order_reviews
    WHERE review_score_valid = 1
),
payments_agg AS (
    SELECT
        order_id,
        SUM(payment_value)  AS payment_value
    FROM ecommerce_lakehouse.Silver.order_payments
    GROUP BY order_id
),
customer_lookup AS (
    SELECT DISTINCT
        customer_id,
        customer_unique_id
    FROM ecommerce_lakehouse.Silver.customers
)
INSERT INTO dbo.fact_orders (
    order_item_key, order_id, order_item_id,
    customer_key, seller_key, product_key,
    order_date_key, delivery_date_key, estimated_delivery_date_key,
    price, freight_value, payment_value,
    review_score, delivery_days, days_late,
    is_late, is_delivered, order_status
)
SELECT
    LOWER(CONVERT(VARCHAR(32),
        HASHBYTES('MD5', oi.order_id + CAST(oi.order_item_id AS VARCHAR(10))), 2))
                                                                AS order_item_key,
    oi.order_id,
    oi.order_item_id,
    LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', cl.customer_unique_id), 2))
                                                                AS customer_key,
    LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', oi.seller_id), 2))
                                                                AS seller_key,
    LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', oi.product_id), 2))
                                                                AS product_key,
    CAST(FORMAT(o.order_purchase_timestamp, 'yyyyMMdd') AS INTEGER)
                                                                AS order_date_key,
    CASE WHEN o.order_delivered_customer_date IS NOT NULL
         THEN CAST(FORMAT(o.order_delivered_customer_date, 'yyyyMMdd') AS INTEGER)
         ELSE NULL END                                          AS delivery_date_key,
    CASE WHEN o.order_estimated_delivery_date IS NOT NULL
         THEN CAST(FORMAT(o.order_estimated_delivery_date, 'yyyyMMdd') AS INTEGER)
         ELSE NULL END                                          AS estimated_delivery_date_key,
    oi.price,
    oi.freight_value,
    pa.payment_value,
    CAST(lr.review_score AS SMALLINT)                           AS review_score,
    o.delivery_days,
    o.days_late,
    CAST(o.is_late AS SMALLINT)                                 AS is_late,
    CAST(o.is_delivered AS SMALLINT)                            AS is_delivered,
    o.order_status
FROM ecommerce_lakehouse.Silver.order_items AS oi
INNER JOIN ecommerce_lakehouse.Silver.orders AS o
    ON oi.order_id = o.order_id
INNER JOIN customer_lookup AS cl
    ON o.customer_id = cl.customer_id
INNER JOIN dbo.dim_customers AS dc
    ON LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', cl.customer_unique_id), 2)) = dc.customer_key
INNER JOIN dbo.dim_sellers AS ds
    ON LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', oi.seller_id), 2)) = ds.seller_key
INNER JOIN dbo.dim_products AS dp
    ON LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', oi.product_id), 2)) = dp.product_key
LEFT JOIN latest_review AS lr
    ON oi.order_id = lr.order_id AND lr.rn = 1
LEFT JOIN payments_agg AS pa
    ON oi.order_id = pa.order_id;