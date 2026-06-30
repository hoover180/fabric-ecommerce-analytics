-- =============================================================
-- Validation: payment_value sum in fact_orders within 1% of
--             Silver.order_payments total
-- Expected: variance <= 1.0% (actual: 0%)
-- Note: fact_orders is stored at order-item grain while
--       payment_value is an order-level attribute. Revenue is
--       aggregated after collapsing to one row per order to
--       prevent payment duplication across multiple items.
--       Silver baseline excludes 774 orders with no order_items
--       rows — legitimately excluded from fact_orders since
--       the fact grain is order-item.
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

WITH fact_total AS (
    SELECT SUM(payment_value) AS fact_revenue
    FROM (
        SELECT DISTINCT
            order_id,
            payment_value
        FROM dbo.fact_orders
        WHERE payment_value IS NOT NULL
    ) AS f
),

silver_total AS (
    SELECT SUM(op.payment_value) AS silver_revenue
    FROM ecommerce_lakehouse.silver.order_payments AS op
    WHERE EXISTS (
        SELECT 1
        FROM ecommerce_lakehouse.silver.order_items AS oi
        WHERE oi.order_id = op.order_id
    )
)

SELECT
    'revenue_reconciliation' AS check_name,
    ROUND(f.fact_revenue, 2) AS fact_revenue,
    ROUND(s.silver_revenue, 2) AS silver_revenue,
    ROUND(
        ABS(f.fact_revenue - s.silver_revenue)
        / NULLIF(s.silver_revenue, 0) * 100, 4
    ) AS variance_pct,
    CASE
        WHEN
            ABS(f.fact_revenue - s.silver_revenue)
            / NULLIF(s.silver_revenue, 0) * 100 <= 1.0
            THEN 'PASS'
        ELSE 'FAIL'
    END AS result
FROM fact_total AS f
CROSS JOIN silver_total AS s; -- both CTEs return one aggregate row
