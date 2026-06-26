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

# Create and seed watermark_table
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
