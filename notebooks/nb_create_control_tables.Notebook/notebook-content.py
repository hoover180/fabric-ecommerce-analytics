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

# Create pipeline_run_log as managed Delta table under dbo
spark.sql("""
    CREATE TABLE IF NOT EXISTS dbo.pipeline_run_log (
        run_id        STRING,
        table_name    STRING,
        source_file   STRING,
        run_timestamp TIMESTAMP,
        rows_loaded   BIGINT,
        status        STRING,
        error_message STRING
    )
    USING DELTA
""")

print("pipeline_run_log created.")
spark.sql("DESCRIBE dbo.pipeline_run_log").show()

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Create and seed watermark_table.
# Seeded to 1900-01-01 rather than left NULL so every table has a defined
# starting point for the first real load to compare against.
spark.sql("""
    CREATE TABLE IF NOT EXISTS dbo.watermark_table (
        table_name       STRING,
        last_loaded_date DATE,
        last_run_id      STRING
    )
    USING DELTA
""")

spark.sql("""
    INSERT INTO dbo.watermark_table VALUES
    ('orders',                       DATE'1900-01-01', NULL),
    ('order_items',                  DATE'1900-01-01', NULL),
    ('order_payments',               DATE'1900-01-01', NULL),
    ('order_reviews',                DATE'1900-01-01', NULL),
    ('customers',                    DATE'1900-01-01', NULL),
    ('sellers',                      DATE'1900-01-01', NULL),
    ('products',                     DATE'1900-01-01', NULL),
    ('product_category_translation', DATE'1900-01-01', NULL),
    ('geolocation',                  DATE'1900-01-01', NULL)
""")

spark.sql("SELECT * FROM dbo.watermark_table").show()
print("watermark_table created and seeded.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
