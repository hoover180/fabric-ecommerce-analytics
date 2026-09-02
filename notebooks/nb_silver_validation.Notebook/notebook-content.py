# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {
# META     "lakehouse": {
# META       "default_lakehouse": "617c7d27-1fd8-4d56-aee6-f661ec30e2cc",
# META       "default_lakehouse_name": "ecommerce_lakehouse",
# META       "default_lakehouse_workspace_id": "c811303c-173d-4678-afcc-1ed657361bd9",
# META       "known_lakehouses": [
# META         {
# META           "id": "617c7d27-1fd8-4d56-aee6-f661ec30e2cc"
# META         }
# META       ]
# META     }
# META   }
# META }

# CELL ********************

from pyspark.sql import functions as F
from pyspark.sql import Row
from datetime import datetime

quality_rows = []
run_timestamp = datetime.utcnow()

def log_check(table_name, check_type, result, passed):
    quality_rows.append(Row(
        table_name=table_name, check_type=check_type,
        result=str(result), passed=passed, run_timestamp=run_timestamp,
    ))

ONE_TO_ONE_TABLES = [
    "orders", "customers", "sellers", "products",
    "order_items", "order_payments", "order_reviews",
]

all_passed = True

for table_name in ONE_TO_ONE_TABLES:
    bronze_count = spark.table(f"Bronze.{table_name}").count()
    silver_count = spark.table(f"Silver.{table_name}").count()
    passed = bronze_count == silver_count
    log_check(table_name, "row_count_parity", f"Bronze {bronze_count} vs Silver {silver_count}", passed)
    print(f"{'✓' if passed else '✗'} {table_name:<20} Bronze {bronze_count:>10,}  Silver {silver_count:>10,}")
    if not passed:
        all_passed = False

bronze_geo = spark.table("Bronze.geolocation").count()
silver_geo = spark.table("Silver.geolocation").count()
geo_passed = 0 < silver_geo < bronze_geo
log_check("geolocation", "dedup_sanity", f"Bronze {bronze_geo} -> Silver {silver_geo}", geo_passed)
print(f"{'✓' if geo_passed else '✗'} geolocation           Bronze {bronze_geo:>10,}  Silver {silver_geo:>10,}  (deduplicated)")
if not geo_passed:
    all_passed = False

orders_check = spark.table("Silver.orders")
null_delivery_days = orders_check.filter(F.col("delivery_days").isNull() & orders_check.order_delivered_customer_date.isNotNull()).count()
delivery_days_passed = null_delivery_days == 0
log_check("orders", "derived_column_sanity", f"{null_delivery_days} delivered orders with null delivery_days", delivery_days_passed)
if not delivery_days_passed:
    all_passed = False

reviews_check = spark.table("Silver.order_reviews")
invalid_scores = reviews_check.filter(F.col("review_score_valid") == 0).count()
review_score_passed = invalid_scores == 0
log_check("order_reviews", "review_score_validity", f"{invalid_scores} invalid review scores", review_score_passed)
if not review_score_passed:
    all_passed = False

null_zip_count = spark.table("Silver.customers").filter(F.col("customer_zip_code_prefix").isNull()).count()
zip_passed = null_zip_count == 0
log_check("customers", "zip_completeness", f"{null_zip_count} null customer zip codes", zip_passed)
if not zip_passed:
    all_passed = False

print(f"\nResult: {'ALL CHECKS PASSED' if all_passed else 'FAILURES DETECTED — review above'}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

spark.sql("""
    CREATE TABLE IF NOT EXISTS dbo.silver_quality_log (
        table_name STRING, check_type STRING, result STRING,
        passed BOOLEAN, run_timestamp TIMESTAMP
    )
    USING DELTA
""")

df_quality = spark.createDataFrame(quality_rows)
df_quality.write.format("delta").mode("append").saveAsTable("dbo.silver_quality_log")
print(f"Wrote {df_quality.count()} quality check rows to dbo.silver_quality_log.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
