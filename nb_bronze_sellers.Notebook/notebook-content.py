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

# Bronze ingestion for [sellers] — full replace load.

from datetime import date

TABLE_NAME       = "sellers"
SOURCE_FILE      = "Files/Bronze/raw/olist_sellers_dataset.csv"
DELTA_PATH       = "Tables/Bronze/sellers"
EXPECTED_COLUMNS = [
    "seller_id", "seller_zip_code_prefix",
    "seller_city", "seller_state",
]

run_id = generate_run_id()
print(f"Run ID: {run_id} | Table: {TABLE_NAME}")

df_raw = spark.read.option("header", True).option("inferSchema", True).csv(SOURCE_FILE)
print(f"Raw row count: {df_raw.count()}")

# Fail fast on schema drift before writing anything
drift   = [c for c in df_raw.columns if c not in EXPECTED_COLUMNS]
missing = [c for c in EXPECTED_COLUMNS if c not in df_raw.columns]
if drift or missing:
    msg = f"Schema drift — unexpected: {drift} | missing: {missing}"
    log_pipeline_run(run_id, TABLE_NAME, SOURCE_FILE, 0, "schema_drift", msg)
    raise Exception(msg)

rows_loaded = df_raw.count()

try:
    df_raw.write.format("delta").mode("overwrite").save(DELTA_PATH)
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
