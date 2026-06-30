# E-Commerce Delivery Analytics Platform

[![SQL Lint](https://github.com/hoover180/fabric-ecommerce-analytics/actions/workflows/sql_lint.yml/badge.svg)](https://github.com/hoover180/fabric-ecommerce-analytics/actions/workflows/sql_lint.yml)

> **Business Problem:**
>
> What delivery and seller factors drive customer dissatisfaction in a Brazilian e-commerce marketplace?
>
> Can we identify which regions and seller segments are responsible for the highest rates of delayed deliveries and negative reviews?

---

## Key Findings

_To be populated after Power BI analysis_

---

## Architecture

Full medallion architecture (Bronze → Silver → Gold) on Microsoft Fabric, ending in a Direct Lake semantic model and Power BI report.

[Kaggle CSVs]

↓

[Bronze Layer — Delta Lake, incremental loads, watermark pattern, schema drift detection]

↓

[Silver Layer — Dataflows Gen2 + PySpark, conforming, derived columns, deduplication]

↓

[Gold Layer — T-SQL Kimball star schema, surrogate keys, SCD Type 1]

↓

[Semantic Model — Direct Lake, DAX measures, RLS]

↓

[Power BI Report — 3 pages: Executive Summary, Delivery Performance, Seller Performance]

---

## Tech Stack

| Tool                            | Purpose                                   | Cert Demonstrated |
| ------------------------------- | ----------------------------------------- | ----------------- |
| Microsoft Fabric (Data Factory) | Pipeline orchestration, incremental loads | DP-700            |
| PySpark + Delta Lake            | Bronze ingestion, Silver deduplication    | DP-700            |
| Dataflows Gen2                  | Silver conforming layer                   | DP-600            |
| T-SQL (Fabric Warehouse)        | Gold star schema DDL                      | DP-600            |
| Semantic Model (Direct Lake)    | BI layer, DAX measures, RLS               | DP-600 / PL-300   |
| Power BI                        | Final reporting layer                     | PL-300            |
| GitHub Actions                  | CI/CD — SQL linting                       | —                 |

**Certifications:** PL-300 ✅ Passed · DP-600 ✅ Passed · DP-700 ✅ Passed

---

## Progress Tracker

- [x] Phase 0 — Setup, scaffold, business case, data dictionary
- [x] Phase 1 — Bronze layer (incremental ingestion, pipeline logging, schema drift)
- [x] Phase 2 — Silver layer (Dataflows Gen2, PySpark validation)
- [x] Phase 3 — Gold layer (T-SQL star schema, Kimball modeling)
- [ ] Phase 4 — Data quality validation, GitHub Actions CI
- [ ] Phase 5 — Semantic Model, Direct Lake, DAX library
- [ ] Phase 6 — Power BI report (3 pages)
- [ ] Phase 7 — Export, README final, executive memo, publish

---

_Built by Michael Hoover · [linkedin.com/in/michael-hoover-365data](https://linkedin.com/in/michael-hoover-365data) · [github.com/hoover180](https://github.com/hoover180)_
