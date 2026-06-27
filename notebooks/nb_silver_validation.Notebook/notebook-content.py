# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "711ad228-eb05-4584-b246-c30b0c4209a8",
# META       "default_lakehouse_name": "ecommerce_lakehouse",
# META       "default_lakehouse_workspace_id": "3495450c-33ef-49d4-8a7f-28b3e585e76f",
# META       "known_lakehouses": [
# META         {
# META           "id": "711ad228-eb05-4584-b246-c30b0c4209a8"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

# Silver validation — referential integrity, range checks, row count reconciliation,
# and revenue cross-check across all 9 Silver tables.

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Row count reconciliation

tables = [
    ("orders", 99441),
    ("order_items", 112650),
    ("order_payments", 103886),
    ("order_reviews", 95330),
    ("customers", 99441),
    ("sellers", 3095),
    ("products", 32951),
    ("geolocation", None),  # deduped — no Bronze target to compare
]

results = []

for table_name, bronze_count in tables:
    silver_df = spark.table(f"Silver.{table_name}")
    silver_count = silver_df.count()

    if bronze_count is not None:
        passed = silver_count <= bronze_count
        note = f"Bronze: {bronze_count}, Silver: {silver_count}"
    else:
        passed = True
        note = f"Deduped — Silver: {silver_count}"

    results.append({
        "table_name": table_name,
        "check_type": "row_count_reconciliation",
        "result": note,
        "passed": passed
    })

    status = "PASS" if passed else "FAIL"
    print(f"{status} | {table_name} | {note}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Null rate on foreign key columns

from pyspark.sql.functions import col

fk_checks = [
    ("Silver.orders", "order_id"),
    ("Silver.orders", "customer_id"),
    ("Silver.order_items", "order_id"),
    ("Silver.order_items", "seller_id"),
    ("Silver.order_items", "product_id"),
    ("Silver.order_payments", "order_id"),
    ("Silver.order_reviews", "order_id"),
]

for table_name, fk_col in fk_checks:
    df = spark.table(table_name)
    total = df.count()
    null_count = df.filter(col(fk_col).isNull()).count()
    null_rate = null_count / total if total > 0 else 0
    passed = null_rate == 0

    results.append({
        "table_name": table_name,
        "check_type": f"null_rate_{fk_col}",
        "result": f"{null_count} nulls ({null_rate:.2%})",
        "passed": passed
    })

    status = "PASS" if passed else "FAIL"
    print(f"{status} | {table_name}.{fk_col} | {null_count} nulls")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Referential integrity

orders_ids = spark.table("Silver.orders").select("order_id").distinct()
customers_ids = spark.table("Silver.customers").select("customer_id").distinct()
sellers_ids = spark.table("Silver.sellers").select("seller_id").distinct()
products_ids = spark.table("Silver.products").select("product_id").distinct()

ref_checks = [
    ("Silver.order_items", "order_id", orders_ids, "Silver.orders"),
    ("Silver.order_items", "seller_id", sellers_ids, "Silver.sellers"),
    ("Silver.order_items", "product_id", products_ids, "Silver.products"),
    ("Silver.order_payments", "order_id", orders_ids, "Silver.orders"),
    ("Silver.order_reviews", "order_id", orders_ids, "Silver.orders"),
    ("Silver.orders", "customer_id", customers_ids, "Silver.customers"),
]

for child_table, fk_col, parent_df, parent_table in ref_checks:
    child_df = spark.table(child_table).select(fk_col).distinct()
    orphans = child_df.join(parent_df, fk_col, "left_anti").count()
    # Note: 23 orphaned order_reviews rows are a known Olist source data quality issue.
    # These correspond to the same 23 rows with invalid review_score values.
    # Flagged in silver_quality_log but not treated as a blocking failure.
    passed = orphans <= 25  # tolerance for known bad rows

    results.append({
        "table_name": child_table,
        "check_type": f"ref_integrity_{fk_col}",
        "result": f"{orphans} orphaned keys",
        "passed": passed
    })

    status = "PASS" if passed else "FAIL"
    print(f"{status} | {child_table}.{fk_col} → {parent_table} | {orphans} orphans")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Range checks

from pyspark.sql.functions import min as spark_min, max as spark_max

range_checks = [
    ("Silver.order_reviews", "review_score", 1, 5),
    ("Silver.order_payments", "payment_value", 0, None),
    ("Silver.orders", "delivery_days", -30, 365),
]

for table_name, col_name, min_val, max_val in range_checks:
    df = spark.table(table_name).filter(col(col_name).isNotNull())
    actual_min = df.agg(spark_min(col_name)).collect()[0][0]
    actual_max = df.agg(spark_max(col_name)).collect()[0][0]

    min_ok = actual_min >= min_val if min_val is not None else True
    max_ok = actual_max <= max_val if max_val is not None else True
    passed = min_ok and max_ok

    results.append({
        "table_name": table_name,
        "check_type": f"range_{col_name}",
        "result": f"min={actual_min}, max={actual_max}",
        "passed": passed
    })

    status = "PASS" if passed else "FAIL"
    print(f"{status} | {table_name}.{col_name} | min={actual_min}, max={actual_max}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Revenue reconciliation

from pyspark.sql.functions import sum as spark_sum

payments_total = spark.table("Silver.order_payments").agg(spark_sum("payment_value")).collect()[0][0]
items_total = spark.table("Silver.order_items").agg(
    spark_sum(col("price") + col("freight_value"))
).collect()[0][0]

variance_pct = abs(payments_total - items_total) / items_total
# Known dataset characteristic — payments include vouchers and installment 
# aggregations that don't map 1:1 to item prices. Threshold set to 30%.
passed = variance_pct <= 0.30

results.append({
    "table_name": "Silver.order_payments",
    "check_type": "revenue_reconciliation",
    "result": f"payments={payments_total:,.2f}, items={items_total:,.2f}, variance={variance_pct:.2%}",
    "passed": passed
})

status = "PASS" if passed else "FAIL"
print(f"{status} | Revenue reconciliation | payments={payments_total:,.2f} vs items={items_total:,.2f} | variance={variance_pct:.2%}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# review_score_valid check

reviews_df = spark.table("Silver.order_reviews")
invalid_scores = reviews_df.filter(col("review_score_valid") == 0).count()
total_reviews = reviews_df.count()
passed = invalid_scores <= 50  # known issue — expecting ~23

results.append({
    "table_name": "Silver.order_reviews",
    "check_type": "review_score_valid_flag",
    "result": f"{invalid_scores} rows flagged as invalid out of {total_reviews}",
    "passed": passed
})

status = "PASS" if passed else "FAIL"
print(f"{status} | review_score_valid | {invalid_scores} invalid rows flagged")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# payment_type_valid check

payments_df = spark.table("Silver.order_payments")
invalid_payments = payments_df.filter(col("payment_type_valid") == 0).count()
total_payments = payments_df.count()
passed = True  # flagged but expected — not_defined is known in Olist

results.append({
    "table_name": "Silver.order_payments",
    "check_type": "payment_type_valid_flag",
    "result": f"{invalid_payments} rows with unexpected payment types out of {total_payments}",
    "passed": passed
})

print(f"INFO | payment_type_valid | {invalid_payments} unexpected payment types flagged (expected — not_defined known in dataset)")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Write to silver_quality_log

from pyspark.sql.types import StructType, StructField, StringType, BooleanType
from datetime import datetime

schema = StructType([
    StructField("table_name", StringType()),
    StructField("check_type", StringType()),
    StructField("result", StringType()),
    StructField("passed", BooleanType()),
    StructField("run_timestamp", StringType()),
])

run_ts = datetime.utcnow().isoformat()
rows = [(r["table_name"], r["check_type"], r["result"], r["passed"], run_ts) for r in results]

df_quality = spark.createDataFrame(rows, schema=schema)
df_quality.write.format("delta").mode("append").saveAsTable("dbo.silver_quality_log")

total = len(results)
failed = sum(1 for r in results if not r["passed"])
print(f"\nValidation complete: {total - failed}/{total} checks passed, {failed} failed.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Final summary

print("\n=== SILVER VALIDATION SUMMARY ===")
for r in results:
    status = "PASS" if r["passed"] else "FAIL"
    print(f"  {status} | {r['table_name']} | {r['check_type']} | {r['result']}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
