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

_Updated: Phase 1 complete — all 9 Bronze tables loaded and validated against
true source row counts, zero variance across every table._
