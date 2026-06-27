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

# Silver conformation for geolocation — deduplication via average lat/lng per zip prefix.
# Source has ~1M rows with multiple coordinate entries per zip prefix.
# Averaging consolidates to one canonical coordinate per zip/state/city combination.

df_geo = spark.table("Bronze.geolocation")

print(f"Bronze row count: {df_geo.count()}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

from pyspark.sql.functions import avg, col

df_deduped = (
    df_geo
    .groupBy(
        col("geolocation_zip_code_prefix"),
        col("geolocation_state"),
        col("geolocation_city")
    )
    .agg(
        avg("geolocation_lat").alias("geolocation_lat"),
        avg("geolocation_lng").alias("geolocation_lng")
    )
)

print(f"Silver row count after dedup: {df_deduped.count()}")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

# Averaging lat/lng is appropriate here — zip prefix boundaries are small enough
# that the centroid of multiple coordinate samples is a valid representative point.
# Alternatives (first row, mode) would introduce arbitrary selection bias.

df_deduped.write.format("delta").mode("overwrite").saveAsTable("Silver.geolocation")
print("Write complete.")

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }

# CELL ********************

print(spark.table("Silver.geolocation").count())

# METADATA ********************

# META {
# META   "language": "python",
# META   "language_group": "synapse_pyspark"
# META }
