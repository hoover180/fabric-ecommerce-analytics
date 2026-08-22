-- =============================================================
-- Table: gold_quality_log
-- Purpose: Persists results of the five Gold-layer validation
--          checks (val_surrogate_keys, val_referential_integrity,
--          val_fact_orders_completeness, val_review_scores,
--          val_revenue) each time this script runs, matching the
--          bronze_quality_log / silver_quality_log pattern.
-- Note: Bronze/Silver logging happens from PySpark notebooks against
--       Delta tables; Gold validation runs entirely in T-SQL against
--       the warehouse, so this table and its population script are
--       T-SQL-native.
-- Note: run_timestamp has no DEFAULT constraint — Fabric Warehouse does
--       not support DEFAULT in CREATE TABLE. The timestamp is captured
--       once into a variable and supplied explicitly in every branch.
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

IF
    NOT EXISTS (
        SELECT 1 FROM sys.tables
        WHERE
            name = 'gold_quality_log' AND schema_id = SCHEMA_ID('Gold')
    )
    CREATE TABLE [Gold].gold_quality_log (
        check_name VARCHAR(100) NOT NULL,
        result VARCHAR(10) NOT NULL,
        detail VARCHAR(200) NULL,
        run_timestamp DATETIME2(6) NOT NULL
    );

-- =============================================================
-- Run all five validation checks and log each result.
-- Re-run this script any time Gold is rebuilt to get a fresh log entry.
-- =============================================================

DECLARE @run_ts DATETIME2(6) = SYSUTCDATETIME();

WITH fact_count AS (
    SELECT COUNT(*) AS row_count
    FROM [Gold].fact_orders
),

silver_order_items_count AS (
    SELECT COUNT(*) AS row_count
    FROM ecommerce_lakehouse.[Silver].order_items
),

fact_revenue AS (
    SELECT SUM(payment_value) AS revenue_total
    FROM (
        SELECT DISTINCT
            order_id,
            payment_value
        FROM [Gold].fact_orders
        WHERE payment_value IS NOT NULL
    ) AS ft
),

silver_revenue AS (
    SELECT SUM(op.payment_value) AS revenue_total
    FROM ecommerce_lakehouse.[Silver].order_payments AS op
    WHERE EXISTS (
        SELECT 1
        FROM ecommerce_lakehouse.[Silver].order_items AS oi
        WHERE oi.order_id = op.order_id
    )
)

INSERT INTO [Gold].gold_quality_log (check_name, result, detail, run_timestamp)
SELECT
    'null_customer_key' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('null_count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders
WHERE customer_key IS NULL

UNION ALL

SELECT
    'null_seller_key' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('null_count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders
WHERE seller_key IS NULL

UNION ALL

SELECT
    'null_product_key' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('null_count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders
WHERE product_key IS NULL

UNION ALL

SELECT
    'null_order_date_key' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('null_count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders
WHERE order_date_key IS NULL

UNION ALL

SELECT
    'customer_key_orphans' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('orphan_count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders AS f
LEFT JOIN [Gold].dim_customers AS dc ON f.customer_key = dc.customer_key
WHERE dc.customer_key IS NULL

UNION ALL

SELECT
    'seller_key_orphans' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('orphan_count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders AS f
LEFT JOIN [Gold].dim_sellers AS ds ON f.seller_key = ds.seller_key
WHERE ds.seller_key IS NULL

UNION ALL

SELECT
    'product_key_orphans' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('orphan_count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders AS f
LEFT JOIN [Gold].dim_products AS dp ON f.product_key = dp.product_key
WHERE dp.product_key IS NULL

UNION ALL

SELECT
    'order_date_key_orphans' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('orphan_count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders AS f
LEFT JOIN [Gold].dim_date AS dd ON f.order_date_key = dd.date_key
WHERE dd.date_key IS NULL AND f.order_date_key IS NOT NULL

UNION ALL

SELECT
    'fact_vs_silver_order_items' AS check_name,
    CASE
        WHEN fc.row_count = sc.row_count THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    CONCAT('fact=', fc.row_count, ' silver=', sc.row_count) AS detail,
    @run_ts AS run_timestamp
FROM fact_count AS fc
CROSS JOIN silver_order_items_count AS sc

UNION ALL

SELECT
    'review_score_out_of_range' AS check_name,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders
WHERE
    review_score IS NOT NULL
    AND review_score NOT BETWEEN 1 AND 5

UNION ALL

SELECT
    'review_score_null_count' AS check_name,
    CASE WHEN COUNT(*) <= 1500 THEN 'PASS' ELSE 'FAIL' END AS result,
    CONCAT('null_count=', COUNT(*)) AS detail,
    @run_ts AS run_timestamp
FROM [Gold].fact_orders
WHERE review_score IS NULL

UNION ALL

SELECT
    'revenue_reconciliation' AS check_name,
    CASE
        WHEN
            ABS(fr.revenue_total - sr.revenue_total)
            / NULLIF(sr.revenue_total, 0) * 100 <= 1.0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS result,
    CONCAT(
        'fact=', ROUND(fr.revenue_total, 2),
        ' silver=', ROUND(sr.revenue_total, 2)
    ) AS detail,
    @run_ts AS run_timestamp
FROM fact_revenue AS fr
CROSS JOIN silver_revenue AS sr;

-- Review this run's results:
SELECT
    check_name,
    result,
    detail,
    run_timestamp
FROM [Gold].gold_quality_log
WHERE run_timestamp = @run_ts
ORDER BY check_name;
