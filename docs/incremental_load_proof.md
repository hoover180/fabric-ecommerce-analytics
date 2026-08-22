# Incremental Load Proof

## Scope

Of the 9 Bronze tables, only 3 have a genuine business timestamp to
incrementally filter on: `orders` (`order_purchase_timestamp`),
`order_items` (`shipping_limit_date` — no purchase-date column exists on
this table; shipping deadline is the closest available proxy and
correlates tightly with purchase date), and `order_reviews`
(`review_creation_date`). These 3 were converted to true incremental
loading.

The remaining 6 tables are correctly full-replace by design, because none
of them has a usable timestamp column: `customers`, `sellers`, `products`,
`product_category_translation`, `geolocation` (all static/dimension data
with nothing to filter on), and `order_payments`
(`order_id, payment_sequential, payment_type, payment_installments,
payment_value` — transactional, but no timestamp exists on this
particular table). The dividing line is "has a natural business
timestamp," not "transactional vs. dimension" — `order_payments` is
transactional but still has to be full-replace. At production scale, a
hash-based change-detection pattern (hashing each row's non-key columns,
comparing against a stored hash per natural key, and only writing on a
diff) would reduce write volume for these tables; not implemented here
given their small, static size at this project's scale — see the
"Production consideration" note at the end of this document.

| Table                          | Load pattern | Watermark column           |
| ------------------------------ | ------------ | -------------------------- |
| `orders`                       | Incremental  | `order_purchase_timestamp` |
| `order_items`                  | Incremental  | `shipping_limit_date`      |
| `order_reviews`                | Incremental  | `review_creation_date`     |
| `order_payments`               | Full-replace | — (no timestamp column)    |
| `customers`                    | Full-replace | — (no timestamp column)    |
| `sellers`                      | Full-replace | — (no timestamp column)    |
| `products`                     | Full-replace | — (no timestamp column)    |
| `product_category_translation` | Full-replace | — (no timestamp column)    |
| `geolocation`                  | Full-replace | — (no timestamp column)    |

## Watermark filter implementation

`orders`, `order_items`, and `order_reviews` apply a `.filter()` against
each table's stored watermark before writing, using `mode("append")`
rather than `mode("overwrite")` — only rows newer than the last
successful load are written on each run. The remaining 6 tables use
`mode("overwrite")` with no filter, since none has a business timestamp
to filter on.

## Three-run proof

All three runs executed through the full orchestration pipeline
(`pl_ecommerce_orchestration`), including the Bronze/Silver/Gold
validation gates.

### Run 1 — full load

`orders`, `order_items`, and `order_reviews` were dropped and their
watermarks reset to `1900-01-01` before this run, giving a genuine first
load under the corrected code (not a re-run against already-existing
data).

| Table           | Rows loaded | Status  |
| --------------- | ----------- | ------- |
| `orders`        | 99,441      | success |
| `order_items`   | 112,650     | success |
| `order_reviews` | 99,224      | success |

### Run 2 — no-op re-run

Triggered immediately after Run 1, no source file changes.

| Table           | Rows loaded | Status  |
| --------------- | ----------- | ------- |
| `orders`        | 0           | success |
| `order_items`   | 0           | success |
| `order_reviews` | 0           | success |

Confirms the watermark filter correctly excludes all rows when nothing
newer than the last load exists — a 0-row result with `status = success`
is the correct outcome here, not a failure.

### Run 3 — incremental-only re-run

5 synthetic rows injected in-memory into `orders`' raw DataFrame
(`df_raw.union(...)`) before the watermark filter, dated after the
current watermark (`2026-08-23` through `2026-08-24`). The source CSV
was never modified — injection happened entirely within the notebook's
Spark session, removed after the test.

| Table           | Rows loaded | Status  |
| --------------- | ----------- | ------- |
| `orders`        | 5           | success |
| `order_items`   | 0           | success |
| `order_reviews` | 0           | success |

Confirms the filter correctly isolates only the genuinely new rows, not
the full table. `Silver.orders` row-count parity showed `99,446` on this
run (99,441 + 5), confirming the increment propagated correctly through
Silver. `fact_orders` stayed at 112,650 unchanged, since the 5 synthetic
orders have no matching `order_items` rows and are correctly excluded by
the fact table's `INNER JOIN` — expected, not a discrepancy.

## Cleanup performed after Run 3

- Temporary synthetic-row injection code removed from `nb_bronze_orders`
- 5 test rows deleted from `Bronze.orders` and `Silver.orders`
  (`WHERE order_id LIKE 'test-order-%'`)
- `orders` watermark reset to `2026-08-22` (the last genuine load date)
- `gold_quality_log.sql` re-run to confirm a clean validation batch
  post-cleanup — 12/12 PASS, all figures matching the pre-test baseline
  (112,650 fact rows, R$15,846,280.17 revenue reconciliation)

## Production consideration: hash-based change detection

For the 6 full-replace tables, a hash-based change-detection pattern is
the standard production approach when no natural timestamp exists.
Compute a hash of each row's non-key columns, keyed by the table's
natural key, and store it in a small tracking table. On each run,
recompute hashes against the full source read and only write rows whose
hash differs from what's stored — new keys are inserts, changed hashes
are updates, unchanged hashes are skipped. This doesn't reduce read cost
(the full source still has to be scanned every run, since there's no
timestamp or CDC feed to filter on upstream) but meaningfully reduces
write volume and downstream processing on large tables — a real
consideration at `geolocation`'s scale (1,000,163 rows) in a system with
actual compute costs. Not implemented here: these tables are small,
static reference/dimension data at this project's scale, and the added
complexity (a persistent hash-store table per source, `MERGE` logic) isn't
justified by the practical benefit at this size.
