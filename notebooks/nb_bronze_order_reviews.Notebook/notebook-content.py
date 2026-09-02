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

# Bronze ingestion for [order_reviews] — incremental load via review_creation_date
# watermark.

from datetime import date
from pyspark.sql import functions as F

TABLE_NAME       = "order_reviews"
SOURCE_FILE      = "Files/Bronze/raw/olist_order_reviews_dataset.csv"
DELTA_PATH       = "Tables/Bronze/order_reviews"
TIMESTAMP_COL    = "review_creation_date"
EXPECTED_COLUMNS = [
    "review_id", "order_id", "review_score",
    "review_comment_title", "review_comment_message",
    "review_creation_date", "review_answer_timestamp",
]

run_id = generate_run_id()
watermark_date = get_watermark(TABLE_NAME)
print(f"Run ID: {run_id} | Table: {TABLE_NAME} | Watermark: {watermark_date}")

df_raw = (
    spark.read
    .option("header", True)
    .option("inferSchema", True)
    .option("multiLine", True)   # review_comment_message contains embedded
                                   # newlines in ~3,850 source rows; without
                                   # this, Spark's line-based CSV reader
                                   # splits those rows and shifts every
                                   # subsequent column — silently dropping
                                   # rows downstream via the watermark filter.
    .option("quote", "\"")
    .option("escape", "\"")       # RFC 4180 escapes a literal quote inside a
                                   # quoted field by doubling it (""). Spark's
                                   # CSV reader defaults to backslash-escaping
                                   # instead, which misparses any review
                                   # comment containing a doubled quote —
                                   # this is what was producing 99,249 rows
                                   # with scattered nulls and duplicate
                                   # review_ids instead of the true 99,224.
    .csv(SOURCE_FILE)
)
print(f"Raw row count: {df_raw.count()}")

drift   = [c for c in df_raw.columns if c not in EXPECTED_COLUMNS]
missing = [c for c in EXPECTED_COLUMNS if c not in df_raw.columns]
if drift or missing:
    msg = f"Schema drift — unexpected: {drift} | missing: {missing}"
    log_pipeline_run(run_id, TABLE_NAME, SOURCE_FILE, 0, "schema_drift", msg)
    raise Exception(msg)

df_filtered = df_raw.filter(F.to_date(F.col(TIMESTAMP_COL)) > F.lit(watermark_date))
rows_loaded = df_filtered.count()
print(f"Rows to load (incremental): {rows_loaded}")

try:
    df_filtered.write.format("delta").mode("append").save(DELTA_PATH)
    register_delta_table(TABLE_NAME, DELTA_PATH, schema="Bronze")
    if rows_loaded > 0:
        new_watermark = df_filtered.agg(F.max(F.to_date(F.col(TIMESTAMP_COL)))).collect()[0][0]
        update_watermark(TABLE_NAME, new_watermark, run_id)
    log_pipeline_run(run_id, TABLE_NAME, SOURCE_FILE, rows_loaded, "success")
    print(f"Success — {rows_loaded} rows loaded.")
except Exception as e:
    log_pipeline_run(run_id, TABLE_NAME, SOURCE_FILE, 0, "failed", str(e))
    raise

spark.sql(f"SELECT * FROM dbo.pipeline_run_log WHERE table_name = '{TABLE_NAME}'").show(truncate=False)
spark.sql(f"SELECT * FROM dbo.watermark_table WHERE table_name = '{TABLE_NAME}'").show()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
