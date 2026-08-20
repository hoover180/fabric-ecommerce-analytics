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

# Bronze ingestion for [geolocation] — full replace load.

from datetime import date

TABLE_NAME       = "geolocation"
SOURCE_FILE      = "Files/Bronze/raw/olist_geolocation_dataset.csv"
DELTA_PATH       = "Tables/Bronze/geolocation"
EXPECTED_COLUMNS = [
    "geolocation_zip_code_prefix", "geolocation_lat",
    "geolocation_lng", "geolocation_city", "geolocation_state",
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
    df_raw.write.format("delta").mode("overwrite").option("overwriteSchema", "true").save(DELTA_PATH)
    register_delta_table(TABLE_NAME, DELTA_PATH, schema="Bronze")
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
