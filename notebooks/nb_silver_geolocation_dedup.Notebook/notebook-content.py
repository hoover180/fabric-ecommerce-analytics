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
# META     },
# META     "warehouse": {}
# META   }
# META }

# CELL ********************

# Silver conformation for geolocation — deduplication via average lat/lng
# per zip prefix. Averaging consolidates the ~1,000,163 raw coordinate
# samples down to one canonical coordinate per zip/state/city combination.
# Chosen over first-row or mode selection, since those would introduce
# arbitrary selection bias — averaging is a defensible, reproducible
# centroid given zip-prefix boundaries are small enough that this is a
# reasonable representative point.

from pyspark.sql.functions import avg, col

df_geo = spark.table("Bronze.geolocation")
print(f"Bronze row count: {df_geo.count()}")

df_deduped = (
    df_geo
    .groupBy(
        col("geolocation_zip_code_prefix"),
        col("geolocation_state"),
        col("geolocation_city"),
    )
    .agg(
        avg("geolocation_lat").alias("geolocation_lat"),
        avg("geolocation_lng").alias("geolocation_lng"),
    )
)
print(f"Silver row count after dedup: {df_deduped.count()}")

df_deduped.write.format("delta").mode("overwrite").option("overwriteSchema", "true").saveAsTable("Silver.geolocation")
print("Write complete.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
