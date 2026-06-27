# Transformation Log

## Silver Layer — Tooling Note

Dataflows Gen2 was attempted for Silver conformation but the Get Data picker
initially failed to surface registered Bronze Delta tables. Resolved by opening
the SQL Analytics Endpoint in the Lakehouse to trigger metadata sync before
each new Dataflow session. All Silver tables except geolocation were implemented
as Dataflows Gen2. Geolocation used PySpark due to groupBy + aggregate
deduplication requirements exceeding Dataflows Gen2 capabilities.

## df_silver_orders

Cast five timestamp columns from string to DateTime to enable date arithmetic.
Derived delivery_days (days from purchase to delivery), is_late (binary flag —
1 if delivered after estimated date), days_late (signed delta — negative means
early), and is_delivered (0 for undelivered). Undelivered and cancelled orders
retained with null delivery metrics. is_late defaults to 0 for undelivered rows
since late status is undefined until delivery occurs.

## df_silver_order_items

Cast price and freight_value to Decimal. Numeric columns explicitly typed at destination mapping.

## df_silver_customers

Standardized customer_state to uppercase for consistent join behavior. Added
has_zip boolean flag for null zip code prefix rows. has_zip retained as boolean — data quality flag only, does not flow to Gold layer. No rows removed.

## df_silver_sellers

Standardized seller_state to uppercase. No other transforms required.

## df_silver_order_reviews

Cast review_creation_date and review_answer_timestamp to DateTime. review_score
contained 23 rows with non-numeric text values (Portuguese review comments
loaded into wrong column — known source data issue). Handled via
`try Number.From() otherwise null` before casting to Whole Number. Added
review_score_valid flag (1 if score 1–5, 0 if null or invalid).
review_comment_message nulls retained — score-only reviews are valid. Rows with
null review_creation_date were already excluded at Bronze ingestion (8,894 rows).

## df_silver_order_payments

Cast payment_value to Decimal. Cast payment_installments and payment_sequential
to Whole Number. Added payment_type_valid flag (1 if known type, 0 otherwise)
against known set: credit_card, boleto, voucher, debit_card. Olist dataset
contains a small number of not_defined payment types — flagged as 0 but retained.

## df_silver_products

Merged product_category_name_translation on product_category_name (left outer
join) to add product_category_english column. Cast measurement columns to Whole
Number. Null dimension values retained — missing measurements don't invalidate
the product record.

## nb_silver_geolocation_dedup (PySpark)

Dataflows Gen2 insufficient for groupBy + aggregate deduplication at 1M row
scale. Used PySpark to group by zip prefix, state, and city — averaging lat/lng
to produce one canonical coordinate per location. Reduces ~1M source rows to
27,912 unique zip prefix/state/city combinations. Read from Bronze.geolocation
catalog table; written to Silver.geolocation via saveAsTable.
