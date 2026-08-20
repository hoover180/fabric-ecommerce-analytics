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

%run nb_bronze_helpers

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Validates all 9 Bronze Delta tables — row counts vs. true source counts,
# PK nulls, duplicates, date ranges. Results written to dbo.bronze_quality_log.
#
# Tolerance is set tight (0.1%) since these are static, fully-known source
# files with documented true row counts — any variance beyond rounding/
# platform noise indicates a real parsing or load issue worth investigating,
# not something to tolerate. This notebook reports only; wiring it into an
# enforced pipeline gate is Phase 4 work, once a pipeline exists to gate.

from pyspark.sql import functions as F
from pyspark.sql import Row
from datetime import datetime

# (table_name, pk_col, timestamp_col, true_source_count, skip_duplicate_check)
TABLE_REGISTRY = [
    ("orders",                       "order_id",                    "order_purchase_timestamp", 99441,   False),
    ("order_items",                  "order_id",                    None,                        112650,  True),
    ("order_payments",               "order_id",                    None,                        103886,  True),
    ("order_reviews",                "review_id",                   "review_creation_date",      99224,   True),
    ("customers",                    "customer_id",                 None,                        99441,   False),
    ("sellers",                      "seller_id",                   None,                        3095,    False),
    ("products",                     "product_id",                  None,                        32951,   False),
    ("product_category_translation", "product_category_name",       None,                        71,      False),
    ("geolocation",                  "geolocation_zip_code_prefix", None,                         1000163, True),
]

TOLERANCE_PCT = 0.1  # tight — see comment above

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

print(f"{'':2} {'Table':<32} {'Rows':>10} {'True':>10} {'Var%':>6} {'PK Nulls':>9} {'PK Dups':>8} {'Date Range'}")
print("-" * 105)

all_passed = True

for (table_name, pk_col, ts_col, true_count, skip_dup) in TABLE_REGISTRY:

    df = spark.table(f"Bronze.{table_name}")
    actual_count = df.count()

    variance_pct = abs(actual_count - true_count) / true_count * 100
    count_passed = variance_pct <= TOLERANCE_PCT
    log_check(table_name, "row_count", f"{actual_count} (expected {true_count}, variance {variance_pct:.3f}%)", count_passed)
    if not count_passed:
        all_passed = False

    null_count = df.filter(F.col(pk_col).isNull()).count()
    null_passed = null_count == 0
    log_check(table_name, "pk_null_rate", f"{null_count} nulls in {pk_col}", null_passed)
    if not null_passed:
        all_passed = False

    if skip_dup:
        dup_count = 0
        log_check(table_name, "pk_duplicates", "skipped — non-unique PK by design", True)
    else:
        dup_count = actual_count - df.select(pk_col).distinct().count()
        dup_passed = dup_count == 0
        log_check(table_name, "pk_duplicates", f"{dup_count} duplicates on {pk_col}", dup_passed)
        if not dup_passed:
            all_passed = False

    if ts_col:
        df_ts = df.filter(F.col(ts_col).isNotNull())
        min_date = df_ts.agg(F.min(ts_col)).collect()[0][0]
        max_date = df_ts.agg(F.max(ts_col)).collect()[0][0]
        date_range_str = f"{min_date} → {max_date}"
        log_check(table_name, "date_range", date_range_str, True)
    else:
        date_range_str = "N/A"

    status = "✓" if count_passed and null_passed and (skip_dup or dup_count == 0) else "✗"
    print(f"{status}  {table_name:<32} {actual_count:>10,} {true_count:>10,} {variance_pct:>5.2f}% {null_count:>9} {dup_count if not skip_dup else 'skip':>8}  {date_range_str}")

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
