# Data Dictionary — Olist E-Commerce Dataset

## Source Dataset

Brazilian E-Commerce Public Dataset by Olist
Date range: 2016–2018 | ~100K orders

All 9 tables are registered under the `Bronze` schema in `ecommerce_lakehouse`
(e.g. `Bronze.orders`), separate from the `dbo` schema, which is reserved for
cross-layer infrastructure (`pipeline_run_log`, `watermark_table`,
`bronze_quality_log`).

---

## Tables

### 1. olist_orders_dataset

- **Grain:** One row per order
- **Primary Key:** `order_id`
- **Row Count (true source):** 99,441
- **Row Count (Bronze):** 99,441
- **Key Columns:** order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date

### 2. olist_order_items_dataset

- **Grain:** One row per order item (an order can have multiple items)
- **Primary Key:** `order_id` + `order_item_id` (composite)
- **Row Count (true source):** 112,650
- **Row Count (Bronze):** 112,650
- **Key Columns:** order_id, order_item_id, product_id, seller_id, shipping_limit_date, price, freight_value
- **Notes:** order_id non-unique by design

### 3. olist_order_payments_dataset

- **Grain:** One row per payment installment per order
- **Primary Key:** `order_id` + `payment_sequential` (composite)
- **Row Count (true source):** 103,886
- **Row Count (Bronze):** 103,886
- **Key Columns:** order_id, payment_sequential, payment_type, payment_installments, payment_value
- **Notes:** order_id non-unique by design

### 4. olist_order_reviews_dataset

- **Grain:** One row per review
- **Primary Key:** `review_id` (non-unique — see notes)
- **Row Count (true source):** 99,224
- **Row Count (Bronze):** 99,224
- **Key Columns:** review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp
- **Notes:** `review_comment_message` contains embedded newlines and doubled
  quote characters in a meaningful number of rows, requiring `multiLine`,
  `quote`, and `escape` CSV read options set explicitly (see inline comments
  in `nb_bronze_order_reviews`). 789 `review_id` values repeat (764 appear
  twice, 25 appear three times) — confirmed these are genuine distinct
  review/order pairings (same review_id, different order_id, review_score,
  and review_creation_date each time), not duplicate rows; zero rows are
  fully identical across all columns. review_id is therefore treated as
  non-unique by design, consistent with order_items/order_payments/
  geolocation. Zero nulls confirmed across review_id, order_id,
  review_creation_date, and review_score.

### 5. olist_customers_dataset

- **Grain:** One row per customer order profile (note: customer_unique_id deduplicates repeat customers)
- **Primary Key:** `customer_id`
- **Row Count (true source):** 99,441
- **Row Count (Bronze):** 99,441
- **Key Columns:** customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state

### 6. olist_sellers_dataset

- **Grain:** One row per seller
- **Primary Key:** `seller_id`
- **Row Count (true source):** 3,095
- **Row Count (Bronze):** 3,095
- **Key Columns:** seller_id, seller_zip_code_prefix, seller_city, seller_state

### 7. olist_products_dataset

- **Grain:** One row per product
- **Primary Key:** `product_id`
- **Row Count (true source):** 32,951
- **Row Count (Bronze):** 32,951
- **Key Columns:** product_id, product_category_name, product_name_lenght, product_description_lenght, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm
- **Notes:** `product_name_lenght` and `product_description_lenght` are
  spelling typos in the source dataset's own column headers, not an error
  in this project — preserved as-is at Bronze since Bronze mirrors the
  source exactly; corrected to proper spelling at Silver.

### 8. olist_product_category_name_translation

- **Grain:** One row per product category
- **Primary Key:** `product_category_name`
- **Row Count (true source):** 71
- **Row Count (Bronze):** 71
- **Key Columns:** product_category_name (Portuguese), product_category_name_english
- **Notes:** Lookup/mapping table — no natural row-level uniqueness check beyond the category name itself.

### 9. olist_geolocation_dataset

- **Grain:** One row per zip code prefix + lat/lng entry (NOT unique per zip — has duplicates)
- **Primary Key:** None (composite: zip_code_prefix + lat + lng)
- **Row Count (true source):** 1,000,163
- **Row Count (Bronze):** 1,000,163
- **Key Columns:** geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state
- **Notes:** geolocation_zip_code_prefix non-unique by design — multiple lat/lng per zip prefix. Will deduplicate in Silver.

---

## Silver Layer

All Silver tables registered under the `Silver` schema in `ecommerce_lakehouse`
(e.g. `Silver.orders`), conformed from their Bronze counterparts via 7
Dataflow Gen2 items plus one PySpark notebook (`geolocation`, deduplicated).

| Table          | Bronze rows | Silver rows | Transformation                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| -------------- | ----------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| orders         | 99,441      | 99,441      | Added `delivery_days`, `is_late`, `days_late`, `is_delivered` (all null-safe on undelivered orders)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                        |
| customers      | 99,441      | 99,441      | Uppercased `customer_state`; explicit integer type on `customer_zip_code_prefix`. `has_zip` considered and deliberately **not** added — `customer_zip_code_prefix` is 100% non-null in this dataset, so the flag would be constant and add no signal; a null-count check was moved into `nb_silver_validation` instead of stored as a table column                                                                                                                                                                                                                                                                                         |
| sellers        | 3,095       | 3,095       | Uppercased `seller_state`; explicit integer type on `seller_zip_code_prefix`                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                               |
| products       | 32,951      | 32,951      | Left-outer joined against `product_category_translation`; added `product_category_english`; renamed `product_name_lenght`→`product_name_length` and `product_description_lenght`→`product_description_length` (source typos corrected here, not at Bronze); explicit integer type on `product_weight_g`, `product_length_cm`, `product_height_cm`, `product_width_cm`, `product_photos_qty`. 610 products (1.85%) have no `product_category_name` in the source and therefore no English translation; ~13 additional products have a category name not present in the translation lookup — both preserved via left-outer join, not dropped |
| order_items    | 112,650     | 112,650     | Explicit types on `price`, `freight_value` (number), `order_item_id` (integer), `shipping_limit_date` (datetime)                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                           |
| order_payments | 103,886     | 103,886     | Explicit types on `payment_value` (number), `payment_installments`/`payment_sequential` (integer); added `payment_type_valid` (1 if payment_type is one of credit_card/boleto/voucher/debit_card, else 0) — 100% valid on this dataset, retained as a standing guard against unexpected values                                                                                                                                                                                                                                                                                                                                             |
| order_reviews  | 99,224      | 99,224      | `review_score` re-derived via safe numeric conversion (`try Number.From(...) otherwise null`); added `review_score_valid` (1 if conversion succeeded) — 100% valid, confirming zero non-numeric scores in the source                                                                                                                                                                                                                                                                                                                                                                                                                       |
| geolocation    | 1,000,163   | **27,912**  | Deduplicated via `nb_silver_geolocation_dedup` — grouped by zip_code_prefix + state + city, lat/lng averaged per group. Not a 1:1 conforming table; row-count reduction is expected and correct                                                                                                                                                                                                                                                                                                                                                                                                                                            |

**Validation:** `nb_silver_validation` confirmed all 7 conforming tables at
exact row-count parity with Bronze, `geolocation`'s dedup ratio sane
(27,912 < 1,000,163, non-zero), zero delivered orders with a null
`delivery_days`, zero invalid `review_score` conversions, and zero null
customer zip codes. 11 checks logged to `dbo.silver_quality_log`, all
passed.

---

_Updated: Phase 2 complete — all 8 Silver tables (7 conformed + 1
deduplicated) validated against Bronze, zero discrepancies._

---

## Gold Layer

All Gold tables registered under a dedicated `Gold` schema in
`ecommerce_warehouse`, extending the schema-per-layer convention used for
Bronze/Silver in the lakehouse. Built via 6 T-SQL scripts (4 dimensions,
1 fact table, 1 quality-log table) plus 5 standalone validation scripts,
all under `gold/sql/`.

**Identifier quoting:** `[Gold]` and `[Silver]` are bracket-quoted
throughout every Gold script. `sqlfluff`'s `capitalisation.identifiers`
rule (policy: `consistent`) requires uniform casing across all unquoted
identifiers in a file; since every column name is lowercase snake_case,
an unquoted capitalized schema name breaks that consistency. Bracket
quoting removes the identifier from that check entirely — the same
pattern already used for `[year]`/`[month]` in `dim_date`.

**Surrogate keys:** MD5 hash of the natural key
(`LOWER(CONVERT(VARCHAR(32), HASHBYTES('MD5', <natural_key>), 2))`),
`VARCHAR(32)`, used on every dimension and the fact table. Deterministic —
the same natural key always produces the same surrogate key, so
dimension reloads (SCD Type 1 overwrite) don't shift keys for unchanged
rows. `dim_date` is the exception: its `date_key` is a plain
`INT` (`YYYYMMDD`), per standard convention for date dimensions.

**SCD Type:** 1 (overwrite on reload) applied to all dimensions — no
business requirement exists to track historical attribute changes for
this dataset.

| Table           | Rows    | Grain                                                 | Notes                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                             |
| --------------- | ------- | ----------------------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dim_date`      | 1,096   | One row per calendar date, 2016-01-01–2018-12-31      | Generated via `GENERATE_SERIES` (a recursive-CTE approach with `OPTION (MAXRECURSION 0)` was tried first and rejected — Fabric Warehouse does not support that query hint). Covers the full span of `order_purchase_timestamp` plus estimated-delivery dates with margin.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                         |
| `dim_customers` | 96,096  | One row per `customer_unique_id`                      | `Silver.customers` grain is `customer_id` (order-scoped, one row per order). Deduplicated to `customer_unique_id` here via `ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY customer_id DESC)`, keeping the most recent record. Geolocation resolved via a zip-prefix join to `Silver.geolocation`, averaged (`AVG(lat)`, `AVG(lng)`) per prefix — no standalone `dim_geolocation` table. Adds `customer_state_country` (full state name) to disambiguate Brazilian state codes from colliding place names in map visuals.                                                                                                                                                                                                                                                                            |
| `dim_sellers`   | 3,095   | One row per `seller_id`                               | Same geolocation-averaging join as customers. Adds pre-aggregated `total_orders`, `on_time_rate`, `avg_review_score`, `sla_compliance_bucket` for reporting performance. **Grain note:** these metrics are computed from a `seller_order_grain` CTE that first collapses `order_items` (item grain) to distinct `(seller_id, order_id)` pairs _before_ aggregating `is_late` — aggregating directly from item-grain rows would overweight sellers with more multi-item orders, inflating or deflating `on_time_rate` incorrectly.                                                                                                                                                                                                                                                                                 |
| `dim_products`  | 32,951  | One row per `product_id`                              | Category translation already resolved at Silver. 623 rows have a null `product_category_english` — matches the null count in the underlying Silver data exactly; a known, tolerated source gap, not a pipeline defect.                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                            |
| `fact_orders`   | 112,650 | One row per order item (`order_id` + `order_item_id`) | Joins `Silver.order_items`/`orders` to all four dimensions via `INNER JOIN` (an order-item whose seller/product/customer didn't resolve to a dimension row would silently drop — verified not to occur via the row-count-parity check below). `payment_value` aggregated to order level (`SUM` grouped by `order_id`) before joining, to avoid fanning payment totals across multi-item orders. `review_score` sourced from the most recent review per order (`ROW_NUMBER()` on `review_answer_timestamp`), filtered to `review_score_valid = 1`. `days_late_bucket`/`days_late_bucket_sort` computed in T-SQL rather than DAX, since Direct Lake semantic models don't support calculated columns; `NULL` `days_late` (non-delivered orders) maps explicitly to a `"Not Delivered"` bucket with sort value `-1`. |

**`fact_orders.review_score` nulls:** 942. All 99,224 rows in
`Silver.order_reviews` pass `review_score_valid` (0 invalid numeric
conversions), so every null in `fact_orders` represents an order with no
submitted review — none are conversion failures. Traceable to explicit
`quote`/`escape` CSV read options applied during Bronze ingestion of
`order_reviews`.

**`fact_orders.payment_value` nulls:** 3 — order items with no matching
aggregated payment row.

**Validation:** `gold_quality_log` (12 checks: 4 null-surrogate-key
checks, 4 referential-integrity checks, row-count parity against
`Silver.order_items`, review-score range/null-count, revenue
reconciliation) — **all 12 passing.** Revenue reconciliation:
`fact_orders` (deduplicated to order level before summing) vs.
`Silver.order_payments` (scoped via `EXISTS` to orders with matching
`order_items` rows) — **R$15,846,280.17 on both sides, 0% variance.**

---

## Phase 4 — Orchestration, Validation Gates, Incremental Loading

Full Bronze → Silver → Gold orchestration pipeline
(`pl_ecommerce_orchestration`) with fail-fast validation gates after
each layer — tested against a deliberate Bronze schema-drift failure,
confirmed it halts all downstream execution. `orders`, `order_items`,
and `order_reviews` converted from full-replace to genuine watermark-
based incremental loading; the remaining 6 Bronze tables are correctly
full-replace, having no natural business timestamp to filter on. Full
three-run proof (full load → no-op → incremental-only) documented in
`docs/incremental_load_proof.md`.

_Updated: Phase 4 complete — orchestration pipeline with fail-fast
validation gates, incremental loading (orders/order_items/order_reviews),
full three-run proof documented in docs/incremental_load_proof.md._
