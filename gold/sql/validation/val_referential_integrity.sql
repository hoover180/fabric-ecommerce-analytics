-- =============================================================
-- Validation: every surrogate key in fact_orders exists in
--             its corresponding dimension table
-- Expected: 0 orphans on all four dimensions
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

SELECT
    'customer_key_orphans' AS check_name,
    COUNT(*) AS orphan_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.fact_orders AS f
LEFT JOIN dbo.dim_customers AS dc ON f.customer_key = dc.customer_key
WHERE dc.customer_key IS NULL

UNION ALL

SELECT
    'seller_key_orphans' AS check_name,
    COUNT(*) AS orphan_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.fact_orders AS f
LEFT JOIN dbo.dim_sellers AS ds ON f.seller_key = ds.seller_key
WHERE ds.seller_key IS NULL

UNION ALL

SELECT
    'product_key_orphans' AS check_name,
    COUNT(*) AS orphan_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.fact_orders AS f
LEFT JOIN dbo.dim_products AS dp ON f.product_key = dp.product_key
WHERE dp.product_key IS NULL

UNION ALL

SELECT
    'order_date_key_orphans' AS check_name,
    COUNT(*) AS orphan_count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.fact_orders AS f
LEFT JOIN dbo.dim_date AS dd ON f.order_date_key = dd.date_key
WHERE dd.date_key IS NULL AND f.order_date_key IS NOT NULL;
