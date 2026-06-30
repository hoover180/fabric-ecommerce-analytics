-- =============================================================
-- Validation: fact_orders row count matches Silver.order_items
-- Expected: exact match (0 variance)
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

SELECT
    'fact_vs_silver_order_items' AS check_name,
    (SELECT COUNT(*) FROM dbo.fact_orders) AS fact_count,
    (SELECT COUNT(*) FROM ecommerce_lakehouse.silver.order_items)
        AS silver_count,
    CASE
        WHEN
            (SELECT COUNT(*) FROM dbo.fact_orders)
            = (SELECT COUNT(*) FROM ecommerce_lakehouse.silver.order_items)
            THEN 'PASS'
        ELSE 'FAIL'
    END AS result;
