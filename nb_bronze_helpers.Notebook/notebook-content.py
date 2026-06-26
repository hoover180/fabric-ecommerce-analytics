# Fabric notebook source

# METADATA ********************

# META {
# META   "kernel_info": {
# META     "name": "synapse_pyspark"
# META   },
# META   "dependencies": {}
# META }

# CELL ********************

# Utility functions for Bronze ingestion pipelines — logging, watermark reads/updates.

import uuid
from datetime import datetime, date
from pyspark.sql.functions import lit
from delta.tables import DeltaTable


def get_watermark(table_name: str) -> date:
    """Read the current watermark date for a given table."""
    df = spark.sql(f"SELECT last_loaded_date FROM dbo.watermark_table WHERE table_name = '{table_name}'")
    row = df.collect()
    if not row:
        raise ValueError(f"No watermark found for table: {table_name}")
    return row[0]["last_loaded_date"]


def update_watermark(table_name: str, new_date: date, run_id: str):
    """Update the watermark date for a given table."""
    spark.sql(f"""
        UPDATE dbo.watermark_table
        SET last_loaded_date = DATE'{new_date}',
            last_run_id = '{run_id}'
        WHERE table_name = '{table_name}'
    """)


def log_pipeline_run(run_id: str, table_name: str, source_file: str,
                     rows_loaded: int, status: str, error_message: str = None):
    """Append a row to pipeline_run_log."""
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


def generate_run_id() -> str:
    return str(uuid.uuid4())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
