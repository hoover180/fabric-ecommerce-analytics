-- =============================================================
-- Validation: no null surrogate keys in fact_orders
-- Expected: 0 nulls on all four key columns
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

SELECT
    'null_customer_key' AS check_name,
    COUNT(*) AS null_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.fact_orders WHERE customer_key IS NULL

UNION ALL

SELECT
    'null_seller_key' AS check_name,
    COUNT(*) AS null_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.fact_orders WHERE seller_key IS NULL

UNION ALL

SELECT
    'null_product_key' AS check_name,
    COUNT(*) AS null_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.fact_orders WHERE product_key IS NULL

UNION ALL

SELECT
    'null_order_date_key' AS check_name,
    COUNT(*) AS null_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.fact_orders WHERE order_date_key IS NULL;
