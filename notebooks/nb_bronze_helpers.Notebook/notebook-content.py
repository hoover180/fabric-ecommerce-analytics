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

# Shared utility functions for Bronze ingestion notebooks — watermark
# reads/updates and run logging. Called via `%run nb_bronze_helpers` from
# each per-table ingestion notebook rather than duplicated nine times.

import uuid
from datetime import date


def generate_run_id() -> str:
    return str(uuid.uuid4())


def get_watermark(table_name: str) -> date:
    df = spark.sql(
        f"SELECT last_loaded_date FROM dbo.watermark_table WHERE table_name = '{table_name}'"
    )
    row = df.collect()
    if not row:
        raise ValueError(f"No watermark found for table: {table_name}")
    return row[0]["last_loaded_date"]


def update_watermark(table_name: str, new_date: date, run_id: str):
    spark.sql(f"""
        UPDATE dbo.watermark_table
        SET last_loaded_date = DATE'{new_date}',
            last_run_id = '{run_id}'
        WHERE table_name = '{table_name}'
    """)


def log_pipeline_run(run_id: str, table_name: str, source_file: str,
                      rows_loaded: int, status: str, error_message: str = None):
    error_val = f"'{error_message}'" if error_message else "NULL"
    spark.sql(f"""
        INSERT INTO dbo.pipeline_run_log VALUES (
            '{run_id}',
            '{table_name}',
            '{source_file}',
            CURRENT_TIMESTAMP(),
            {rows_loaded},
            '{status}',
            {error_val}
        )
    """)


def register_delta_table(table_name: str, delta_path: str, schema: str = "dbo"):
    # Registers the written Delta path under the given schema so it's
    # queryable by name (e.g. Bronze.customers) rather than only by raw
    # path in the Lakehouse. Defaults to dbo for cross-layer infrastructure
    # tables (pipeline_run_log, watermark_table); Bronze/Silver/Gold
    # ingestion notebooks pass their own layer's schema explicitly.
    location = spark.sql(f"DESCRIBE DETAIL delta.`{delta_path}`").collect()[0]["location"]
    spark.sql(f"CREATE SCHEMA IF NOT EXISTS {schema}")
    spark.sql(f"""
        CREATE TABLE IF NOT EXISTS {schema}.{table_name}
        USING DELTA
        LOCATION '{location}'
    """)

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
