# Data Dictionary — Olist E-Commerce Dataset

## Source Dataset

Brazilian E-Commerce Public Dataset by Olist  
Date range: 2016–2018 | ~100K orders

---

## Tables

### 1. olist_orders_dataset

- **Grain:** One row per order
- **Primary Key:** `order_id`
- **Row Count (Kaggle):** 99,441
- **Row Count (Bronze):** 99,441
- **Key Columns:** order_id, customer_id, order_status, order_purchase_timestamp, order_approved_at, order_delivered_carrier_date, order_delivered_customer_date, order_estimated_delivery_date

### 2. olist_order_items_dataset

- **Grain:** One row per order item (an order can have multiple items)
- **Primary Key:** `order_id` + `order_item_id` (composite)
- **Row Count (Kaggle):** 112,650
- **Row Count (Bronze):** 112,650
- **Key Columns:** order_id, order_item_id, product_id, seller_id, price, freight_value
- **Notes:** order_id non-unique by design

### 3. olist_order_payments_dataset

- **Grain:** One row per payment installment per order
- **Primary Key:** `order_id` + `payment_sequential` (composite)
- **Row Count (Kaggle):** 103,886
- **Row Count (Bronze):** 103,886
- **Key Columns:** order_id, payment_sequential, payment_type, payment_installments, payment_value
- **Notes:** order_id non-unique by design

### 4. olist_order_reviews_dataset

- **Grain:** One row per review
- **Primary Key:** `review_id`
- **Row Count (Kaggle):** 99,224
- **Row Count (Bronze):** 95,330
- **Key Columns:** review_id, order_id, review_score, review_comment_title, review_comment_message, review_creation_date, review_answer_timestamp
- **Notes:** ~3.9% variance — 8,894 rows excluded due to null review_creation_date; 1 null review_id in source data

### 5. olist_customers_dataset

- **Grain:** One row per customer order profile (note: customer_unique_id deduplicates repeat customers)
- **Primary Key:** `customer_id`
- **Row Count (Kaggle):** 99,441
- **Row Count (Bronze):** 99,441
- **Key Columns:** customer_id, customer_unique_id, customer_zip_code_prefix, customer_city, customer_state

### 6. olist_sellers_dataset

- **Grain:** One row per seller
- **Primary Key:** `seller_id`
- **Row Count (Kaggle):** 3,095
- **Row Count (Bronze):** 3,095
- **Key Columns:** seller_id, seller_zip_code_prefix, seller_city, seller_state

### 7. olist_products_dataset

- **Grain:** One row per product
- **Primary Key:** `product_id`
- **Row Count (Kaggle):** 32,951
- **Row Count (Bronze):** 32,951
- **Key Columns:** product_id, product_category_name, product_name_lenght, product_description_lenght, product_photos_qty, product_weight_g, product_length_cm, product_height_cm, product_width_cm
- **Notes:** product_name_lenght and product_description_lenght are source typos, preserved at Bronze

### 8. olist_product_category_name_translation

- **Grain:** One row per product category
- **Primary Key:** `product_category_name`
- **Row Count (Kaggle):** 71
- **Row Count (Bronze):** 71
- **Key Columns:** product_category_name (Portuguese), product_category_name_english

### 9. olist_geolocation_dataset

- **Grain:** One row per zip code prefix + lat/lng entry (NOT unique per zip — has duplicates)
- **Primary Key:** None (composite: zip_code_prefix + lat + lng)
- **Row Count (Kaggle):** 1,000,163
- **Row Count (Bronze):** 1,000,163
- **Key Columns:** geolocation_zip_code_prefix, geolocation_lat, geolocation_lng, geolocation_city, geolocation_state
- **Notes:** geolocation_zip_code_prefix non-unique by design — multiple lat/lng per zip prefix. Will deduplicate in Silver.

---

_Updated: [6/26/2026] | Bronze layer complete — all 9 tables validated_
