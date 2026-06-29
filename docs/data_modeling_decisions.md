# Data Modeling Decisions

> This document records every significant modeling choice made in this project, with explicit rationale. Intended as both a project record and an interview reference.

---

## 1. Grain of fact_orders

**Decision:** One row per order item (order_id + order_item_id composite key)

**Why not one row per order?**  
The source data's atomic unit of analysis is the order item — each item has its own product, seller, price, and freight value. Collapsing to order-level would require pre-aggregating price and losing the ability to slice revenue by product category or seller at the item level. The order item is the correct analytical grain for this dataset.

**Implication:** `payment_value` is joined from `order_payments` aggregated to order level (sum per order_id), then denormalized onto each item row. This is a deliberate trade-off: it introduces controlled redundancy to preserve item-level slicing without requiring runtime aggregation in DAX.

---

## 2. Kimball Dimensional Modeling vs Data Vault 2.0

**Decision:** Kimball star schema

**Why Kimball:**

- The analytical questions are pre-defined: delivery performance, regional analysis, seller segmentation. This is a read-optimized reporting use case — exactly what Kimball is designed for.
- Star schema delivers simpler DAX, better query performance in Direct Lake, and an immediately readable ERD for stakeholders and reviewers.
- Data Vault excels at auditability, historization, and integrating disparate source systems at enterprise scale. None of those requirements apply here: single source system, no complex historization needed, no enterprise integration workload.

**When Data Vault would be correct:** If this were a financial data warehouse integrating 12 source systems with strict audit requirements, Data Vault would be the right call.

---

## 3. Direct Lake vs Import Mode vs DirectQuery

**Decision:** Direct Lake

**Why Direct Lake:**

- Direct Lake reads Delta Parquet files directly from the Lakehouse without importing data into a compressed dataset (as Import mode does) and without live query translation (as DirectQuery does).
- For this dataset (~112K order items), Direct Lake provides near-Import-mode query speed while eliminating the data refresh scheduling requirement.
- Direct Lake also demonstrates DP-600 competency — it's a Fabric-native capability not available in traditional Power BI Premium.

**When Import mode would be correct:** If the semantic model needed to be shared outside Fabric (e.g., published to Power BI Service for external stakeholders), Import mode with scheduled refresh is more portable.

**When DirectQuery would be correct:** If the data updated in real-time (streaming) and sub-minute freshness was required.

---

## 4. Dataflows Gen2 vs PySpark for the Silver Layer

**Decision:** Use both — each for what it does best

**Dataflows Gen2 (Power Query engine):**

- Used for: column renaming, type casting, basic derived columns, null handling
- Why: Low-code, fast to build, natively integrated with Fabric Lakehouse output
- Best for: transformations a business analyst could own and modify

**PySpark notebooks:**

- Used for: geolocation deduplication (requires groupBy + avg aggregation logic that Power Query handles awkwardly)
- Why: Full programmatic control, better for complex multi-step transformations and custom logic
- Best for: transformations requiring conditional logic, complex aggregations, or production-grade error handling

---

## 5. Hash Surrogate Keys vs Auto-Increment

**Decision:** MD5 hash of natural key(s)

**Why hash keys:**

- Deterministic: the same natural key always produces the same surrogate key, enabling idempotent loads without an identity column dependency
- Pipeline-safe: does not require a sequence or identity column in the database — the key can be computed in PySpark or T-SQL at load time
- Merge-friendly: enables UPSERT logic in incremental loads without needing to look up existing surrogate key assignments

**Trade-off:** MD5 is not collision-proof at extreme scale (billions of rows). For this dataset (~100K rows), collision risk is negligible. At enterprise scale, SHA-256 or a composite natural key is preferred.

---

## 6. SCD (Slowly Changing Dimension) Type

**Decision:** SCD Type 1 (overwrite) applied to all dimensions

**Why Type 1:**

- No business requirement exists in this dataset to track historical attribute changes (e.g., a customer moving from one state to another, or a seller changing city).
- The dataset is historical and static — SCD behavior is academic for a frozen dataset.
- Type 1 simplifies the pipeline significantly.

**What Type 2 would require in production:**

- Add `effective_start_date`, `effective_end_date`, and `is_current` columns to each dimension
- Change MERGE logic from overwrite to insert-when-changed
- Update the semantic model to filter on `is_current = TRUE` for default analysis
- DAX measures would need to handle role-playing date dimensions against SCD date ranges

---

## 7. Business Metric Definitions

| Metric                            | Definition                                                                           |
| --------------------------------- | ------------------------------------------------------------------------------------ |
| **Delivery Days**                 | `order_delivered_customer_date` − `order_purchase_timestamp` in calendar days        |
| **Late Delivery**                 | `order_delivered_customer_date` > `order_estimated_delivery_date` → is_late = 1      |
| **Days Late**                     | `order_delivered_customer_date` − `order_estimated_delivery_date` (negative = early) |
| **On-Time Rate**                  | COUNT(is_late = 0) / COUNT(all delivered orders)                                     |
| **Repeat Customer**               | A `customer_unique_id` appearing in 2+ orders                                        |
| **CLV (Customer Lifetime Value)** | SUM(payment_value) per customer_unique_id                                            |
| **Seller SLA Compliance**         | COUNT(on-time orders per seller) / COUNT(all orders per seller)                      |

---

## 8. Scaling Considerations

_These patterns are implemented to demonstrate production readiness — designed to scale to enterprise data volumes._

| Concern                  | Pattern Applied                                                                       | Enterprise Consideration                                                             |
| ------------------------ | ------------------------------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| Large Bronze tables      | Partition `orders` Delta table by `order_purchase_timestamp` year/month               | At 500M+ rows, partitioning is mandatory for query pruning                           |
| Delta table maintenance  | OPTIMIZE + VACUUM cadence (weekly)                                                    | At scale, automate via pipeline trigger; VACUUM retention window affects time-travel |
| Direct Lake limits       | Direct Lake falls back to DirectQuery when row/column framing thresholds are exceeded | At enterprise scale, test framing limits under concurrent load                       |
| Orchestration complexity | Master pipeline → child pipeline pattern                                              | At scale, add retry logic, circuit breakers, and dead-letter queues                  |

---

## 9. dim_customers Grain and Deduplication

**Decision:** Deduplicate to `customer_unique_id` grain at Gold load via `ROW_NUMBER()`

**Context:** `Silver.customers` grain is `customer_id` (order-scoped per Olist schema) — one row per order, not per person. The same `customer_unique_id` can appear multiple times with slightly different `customer_city` values due to data entry inconsistency in the source data.

**Why deduplication belongs at Gold, not Silver:**

- Silver correctly preserves the source grain (`customer_id`) — flattening to `customer_unique_id` at Silver would lose the order-to-customer mapping needed for referential integrity checks
- `dim_customers` requires person-scoped grain for correct DAX measure behavior — duplicate `customer_unique_id` rows in a dimension cause fan-out and double-counting in fact table joins
- The dimensional grain decision is a Gold-layer concern; Silver is the conforming layer, not the modeling layer

**Implementation:** `ROW_NUMBER() OVER (PARTITION BY customer_unique_id ORDER BY customer_id DESC)` selects the most recent record as canonical customer attributes. `WHERE rn = 1` enforces exactly one row per unique customer.

**Result:** 96,096 unique customers (vs 99,441 rows in `Silver.customers`)

---

## 10. Known Null Values in Gold Layer

| Table          | Column                     | Null Count | Disposition                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      |
| -------------- | -------------------------- | ---------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `dim_products` | `product_category_english` | 623        | Tolerated — source data gap in Olist dataset. Products exist in `order_items` without a category assignment. Nulls propagate to `fact_orders` and are excluded from category-level DAX filters naturally.                                                                                                                                                                                                                                                                                                                                                                                                                        |
| `fact_orders`  | `review_score`             | 5,556      | Tolerated — fully investigated and confirmed as legitimate source data gaps, not pipeline errors. Breakdown: 4,562 orders have no review row in `Silver.order_reviews` (customers never submitted a review); remaining ~994 orders had reviews that failed Silver validity check (`review_score_valid = 0`). Confirmed via query: 0 orders with a valid review row have a null score in `fact_orders`. DAX measures using `review_score` naturally exclude nulls — averages and distributions are unaffected. Excluding these rows would corrupt revenue and order count metrics since the fact grain is order item, not review. |

_No action taken — both are known source data characteristics, not pipeline errors._

---

_Author: Michael Hoover | github.com/hoover180_  
_Last updated: [6/28/2026]_
