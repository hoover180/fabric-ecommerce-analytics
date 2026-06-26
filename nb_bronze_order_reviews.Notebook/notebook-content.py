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

# Bronze ingestion for order_reviews — incremental load via review_creation_date watermark.

from datetime import date
from pyspark.sql import functions as F

TABLE_NAME    = "order_reviews"
SOURCE_FILE   = "Files/Bronze/raw/olist_order_reviews_dataset.csv"
DELTA_PATH    = "Tables/Bronze/order_reviews"
TIMESTAMP_COL = "review_creation_date"

EXPECTED_COLUMNS = [
    "review_id", "order_id", "review_score",
    "review_comment_title", "review_comment_message",
    "review_creation_date", "review_answer_timestamp",
]

run_id = generate_run_id()
watermark_date = get_watermark(TABLE_NAME)
print(f"Run ID: {run_id} | Watermark: {watermark_date}")

df_raw = spark.read.option("header", True).option("inferSchema", True).csv(SOURCE_FILE)
print(f"Raw row count: {df_raw.count()}")

# Fail fast on schema drift before writing anything
drift   = [c for c in df_raw.columns if c not in EXPECTED_COLUMNS]
missing = [c for c in EXPECTED_COLUMNS if c not in df_raw.columns]
if drift or missing:
    msg = f"Schema drift — unexpected: {drift} | missing: {missing}"
    log_pipeline_run(run_id, TABLE_NAME, SOURCE_FILE, 0, "schema_drift", msg)
    raise Exception(msg)

# First run watermark is 1900-01-01, so this loads all rows on initial execution
df_filtered = df_raw.filter(F.to_date(F.col(TIMESTAMP_COL)) > F.lit(watermark_date))
rows_loaded = df_filtered.count()
print(f"Rows to load: {rows_loaded}")

try:
    df_filtered.write.format("delta").mode("append").save(DELTA_PATH)
    register_delta_table(TABLE_NAME, DELTA_PATH)
    update_watermark(TABLE_NAME, date.today(), run_id)
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
