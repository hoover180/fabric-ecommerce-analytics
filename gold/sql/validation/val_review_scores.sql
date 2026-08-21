-- =============================================================
-- Validation: review_score range check and null count
-- Expected: 0 out-of-range scores
-- Null count: all review_score values in Silver.order_reviews pass
--             validity conversion, so nulls here represent orders
--             with no submitted review, not conversion failures.
-- Author: Michael Hoover | github.com/hoover180
-- =============================================================

SELECT
    'review_score_out_of_range' AS check_name,
    COUNT(*) AS count,
    CASE WHEN COUNT(*) = 0 THEN 'PASS' ELSE 'FAIL' END AS result
FROM [Gold].fact_orders
WHERE
    review_score IS NOT NULL
    AND review_score NOT BETWEEN 1 AND 5

UNION ALL

SELECT
    'review_score_null_count (no-review orders only)' AS check_name,
    COUNT(*) AS count,
    CASE WHEN COUNT(*) <= 1500 THEN 'PASS' ELSE 'FAIL' END AS result
FROM [Gold].fact_orders
WHERE review_score IS NULL;
