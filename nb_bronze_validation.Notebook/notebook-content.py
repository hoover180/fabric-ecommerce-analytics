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

%run nb_bronze_helpers

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Validates all 9 Bronze Delta tables — row counts, PK nulls, duplicates, date ranges.
# Results written to dbo.bronze_quality_log.

from pyspark.sql import functions as F
from pyspark.sql import Row
from datetime import datetime

TABLE_REGISTRY = [
    ("orders",                     "Tables/Bronze/orders",                     "order_id",                    "order_purchase_timestamp", 99441),
    ("order_items",                "Tables/Bronze/order_items",                "order_id",                    None,                       112650),
    ("order_payments",             "Tables/Bronze/order_payments",             "order_id",                    None,                       103886),
    ("order_reviews",              "Tables/Bronze/order_reviews",              "review_id",                   "review_creation_date",     99224),
    ("customers",                  "Tables/Bronze/customers",                  "customer_id",                 None,                       99441),
    ("sellers",                    "Tables/Bronze/sellers",                    "seller_id",                   None,                       3095),
    ("products",                   "Tables/Bronze/products",                   "product_id",                  None,                       32951),
    ("product_category_translation","Tables/Bronze/product_category_translation","product_category_name",     None,                       71),
    ("geolocation",                "Tables/Bronze/geolocation",                "geolocation_zip_code_prefix", None,                       1000163),
]

quality_rows = []
run_timestamp = datetime.utcnow()

def log_check(table_name, check_type, result, passed):
    quality_rows.append(Row(
        table_name=table_name,
        check_type=check_type,
        result=str(result),
        passed=passed,
        run_timestamp=run_timestamp,
    ))

print(f"{'':2} {'Table':<38} {'Rows':>8} {'Kaggle':>8} {'Var%':>6} {'PK Nulls':>9} {'PK Dups':>8} {'Date Range'}")
print("-" * 105)

all_passed = True

for (table_name, delta_path, pk_col, ts_col, kaggle_count) in TABLE_REGISTRY:

    df = spark.read.format("delta").load(delta_path)
    actual_count = df.count()

    # Row count vs Kaggle documented count — flag if variance exceeds 5%
    variance_pct = abs(actual_count - kaggle_count) / kaggle_count * 100
    count_passed = variance_pct <= 5.0
    log_check(table_name, "row_count", f"{actual_count} (expected ~{kaggle_count}, variance {variance_pct:.1f}%)", count_passed)
    if not count_passed:
        all_passed = False

    # Null check on primary key column
    null_count = df.filter(F.col(pk_col).isNull()).count()
    # order_reviews has known null review_ids in source data — flagged, not blocking
    null_passed = null_count == 0 if table_name != "order_reviews" else True
    log_check(table_name, "pk_null_rate", f"{null_count} nulls in {pk_col}", null_passed)
    if not null_passed:
        all_passed = False

    # Duplicate check — skipped for tables where order_id is intentionally non-unique
    skip_dup = table_name in ("order_items", "order_payments", "order_reviews", "geolocation")
    if skip_dup:
        dup_count = 0
        log_check(table_name, "pk_duplicates", "skipped — non-unique PK by design", True)
    else:
        dup_count = actual_count - df.select(pk_col).distinct().count()
        dup_passed = dup_count == 0
        log_check(table_name, "pk_duplicates", f"{dup_count} duplicates on {pk_col}", dup_passed)
        if not dup_passed:
            all_passed = False

    # Date range check on timestamp columns
    if ts_col:
        df_ts = df.filter(F.col(ts_col).isNotNull())
        min_date = df_ts.agg(F.min(ts_col)).collect()[0][0]
        max_date = df_ts.agg(F.max(ts_col)).collect()[0][0]
        date_range_str = f"{min_date} → {max_date}"
        log_check(table_name, "date_range", date_range_str, True)
    else:
        date_range_str = "N/A"

    status = "✓" if count_passed and null_passed and (skip_dup or dup_count == 0) else "✗"
    print(f"{status}  {table_name:<38} {actual_count:>8,} {kaggle_count:>8,} {variance_pct:>5.1f}% {null_count:>9} {dup_count if not skip_dup else 'skip':>8}  {date_range_str}")

print("-" * 105)
print(f"\nResult: {'ALL CHECKS PASSED' if all_passed else 'FAILURES DETECTED — review above'}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

spark.sql("""
    CREATE TABLE IF NOT EXISTS dbo.bronze_quality_log (
        table_name    STRING,
        check_type    STRING,
        result        STRING,
        passed        BOOLEAN,
        run_timestamp TIMESTAMP
    )
    USING DELTA
""")

df_quality = spark.createDataFrame(quality_rows)
df_quality.write.format("delta").mode("append").saveAsTable("dbo.bronze_quality_log")

print(f"Wrote {df_quality.count()} quality check rows to dbo.bronze_quality_log.")

print("\nFailed checks:")
spark.sql("SELECT * FROM dbo.bronze_quality_log WHERE passed = false").show(truncate=False)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
