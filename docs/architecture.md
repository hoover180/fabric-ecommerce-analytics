# Architecture — E-Commerce Analytics Platform

## Medallion Architecture Rationale

**Bronze (Raw):** Exact copy of source CSVs as Delta tables. No transformations. Schema drift detection runs at ingest. Watermark table enables incremental loads. Purpose: preserve raw data fidelity and enable full reprocessing if Silver logic changes.

**Silver (Conformed):** Business-ready staging layer. Type casting, null handling, derived columns (delivery_days, is_late, days_late), deduplication (geolocation). Not yet star-schema shaped — still source-aligned.

**Gold (Aggregated/Modeled):** Kimball star schema (fact_orders + dim_customers + dim_sellers + dim_products + dim_date). Optimized for BI consumption. T-SQL DDL with surrogate keys and header comments.

## Fabric-Native Transformation Decision

**dbt is excluded from this project,** opting to use the Fabric-native toolchain (Dataflows Gen2 + PySpark + T-SQL) with CI/CD via GitHub Actions, demonstrating DP-600 and DP-700 competency.

## Incremental Load Pattern

Watermark-based: `watermark_table` stores last loaded date per table. On each run, the pipeline reads the watermark, filters source data for new rows only, writes to Delta, updates the watermark on success, and logs the run to `pipeline_run_log`. Tables without timestamp columns use full-replace with a run date stamp.
