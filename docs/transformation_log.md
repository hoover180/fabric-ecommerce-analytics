# Transformation Log

## df_silver_orders

Cast five timestamp columns from string to DateTime to enable date arithmetic.
Derived delivery_days (days from purchase to delivery), is_late (binary flag —
1 if delivered after estimated date), days_late (signed delta — negative means
early), and is_delivered (0 for undelivered). Undelivered and cancelled orders
retained with null delivery metrics. is_late defaults to 0 for undelivered rows
since late status is undefined until delivery occurs.

## df_silver_order_items

Cast price and freight_value from string to Decimal. No rows removed. Table was
clean from Bronze.

## df_silver_customers

Standardized customer_state to uppercase for consistent join behavior. Added
has_zip boolean flag for null zip code prefix rows. No rows removed.

## df_silver_sellers

Standardized seller_state to uppercase. No other transforms required.
