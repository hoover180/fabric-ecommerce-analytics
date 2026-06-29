-- =============================================================
-- Validation: review_score range check and null count
-- Expected: 0 out-of-range scores
-- Null count: 5,556 tolerated — 4,562 orders with no review submitted;
--             ~994 orders with invalid scores nulled at Silver.
--             Confirmed: 0 orders with a valid review row have a null score in fact_orders.
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

SELECT 'review_score_out_of_range' AS check_name,
    COUNT(*) AS count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM dbo.fact_orders
WHERE review_score IS NOT NULL
  AND review_score NOT BETWEEN 1 AND 5

UNION ALL

SELECT 'review_score_null_count (5556 tolerated — see note)',
    COUNT(*),
    CASE WHEN COUNT(*) <= 6000 THEN 'PASS' ELSE 'FAIL' END
FROM dbo.fact_orders
WHERE review_score IS NULL;