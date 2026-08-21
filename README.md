# E-Commerce Delivery Analytics Platform

[![SQL Lint](https://github.com/hoover180/ecommerce-analytics/actions/workflows/sql_lint.yml/badge.svg)](https://github.com/hoover180/ecommerce-analytics/actions/workflows/sql_lint.yml)

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

Full medallion architecture (Bronze → Silver → Gold) on Microsoft Fabric, orchestrated end-to-end and ending in a Direct Lake semantic model and Power BI report.

```
[Kaggle CSVs]
  ↓
[Bronze Layer — Delta Lake, incremental loads, watermark pattern, schema drift detection]
  ↓
[Enforced Validation Gate — row-count reconciliation vs. true source counts; pipeline fails on variance beyond threshold]
  ↓
[Silver Layer — Dataflows Gen2 + PySpark, conforming, derived columns, deduplication]
  ↓
[Gold Layer — T-SQL Kimball star schema, surrogate keys, SCD Type 1]
  ↓
[Semantic Model — Direct Lake, DAX measures, RLS]
  ↓
[Power BI Report (.pbip) — 3 pages: Executive Summary, Delivery Performance, Seller Performance]
```

Orchestrated via a Data Factory pipeline (Notebook → Validation → Dataflow → Gold SQL activities, with explicit dependency and success conditions) rather than run manually step-by-step.

---

## Tech Stack

| Tool                            | Purpose                                           | Cert Demonstrated |
| ------------------------------- | ------------------------------------------------- | ----------------- |
| Microsoft Fabric (Data Factory) | Pipeline orchestration, incremental loads         | DP-700            |
| PySpark + Delta Lake            | Bronze ingestion, Silver deduplication            | DP-700            |
| Fabric Notebook Validation Gate | Enforced Bronze→Silver data-quality gate          | DP-700            |
| Dataflows Gen2                  | Silver conforming layer                           | DP-600            |
| T-SQL (Fabric Warehouse)        | Gold star schema DDL                              | DP-600            |
| Semantic Model (Direct Lake)    | BI layer, DAX measures, RLS                       | DP-600 / PL-300   |
| Power BI (.pbip)                | Final reporting layer, Git-diffable report format | PL-300            |
| GitHub Actions                  | CI/CD — SQL linting                               | —                 |

**Certifications:** [PL-300](https://learn.microsoft.com/en-us/users/michaelhoover-2613/credentials/9c0581e743fc1bf9) ✅ Passed · [DP-600](https://learn.microsoft.com/en-us/users/michaelhoover-2613/credentials/fa6879dec0a2a917) ✅ Passed · [DP-700](https://learn.microsoft.com/en-us/users/michaelhoover-2613/credentials/365699f83003135b) ✅ Passed

---

## Progress Tracker

- [x] Phase 0 — Setup, scaffold, business case, data dictionary
- [x] Phase 1 — Bronze layer (incremental ingestion, pipeline logging, schema drift, watermark logic)
- [x] Phase 2 — Silver layer (Dataflows Gen2, PySpark validation)
- [x] Phase 3 — Gold layer (T-SQL star schema, Kimball modeling)
- [ ] Phase 4 — Data quality: enforced validation gate (fail-fast threshold), incremental-load demo (proven via three-run test — full load, no-op re-run, incremental-only re-run), GitHub Actions CI
- [ ] Phase 5 — Semantic Model, Direct Lake, DAX library
- [ ] Phase 6 — Power BI report (3 pages, `.pbip` format)
- [ ] Phase 7 — Export, README final, executive memo, publish

---

_Built by Michael Hoover · [linkedin.com/in/michael-hoover-365data](https://linkedin.com/in/michael-hoover-365data) · [github.com/hoover180](https://github.com/hoover180)_
