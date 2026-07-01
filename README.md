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

## DAX Measures Highlights

Five measures that demonstrate semantic modeling depth. Full library: [`/docs/dax_measures_library.md`](docs/dax_measures_library.md)

**Total Revenue** — Solves the fan-out problem on an item-grain fact table. `payment_value` is order-level; summing directly overcounts on multi-item orders. Deduplicates at `order_id` before aggregating:

```dax
Total Revenue =
SUMX(
    SUMMARIZE(fact_orders, fact_orders[order_id], "pv", MAX(fact_orders[payment_value])),
    [pv]
)
```

Validated against `val_revenue.sql` — both return **$15,846,280.17**.

---

**On-Time Delivery Rate** — Uses `CALCULATE` with a boolean column filter rather than `FILTER(fact_orders, ...)` to leverage VertiPaq column indexes. More efficient in Direct Lake mode at scale:

```dax
On-Time Delivery Rate =
DIVIDE(
    CALCULATE(COUNTROWS(fact_orders), fact_orders[is_late] = 0),
    COUNTROWS(fact_orders)
)
```

---

**Review Score Rolling 3M** — Time intelligence with `DATESINPERIOD`. The 3-month window shifts dynamically with the filter context — useful for trend analysis on the Delivery Performance page:

```dax
Review Score Rolling 3M =
CALCULATE(
    [Avg Review Score],
    DATESINPERIOD(dim_date[full_date], LASTDATE(dim_date[full_date]), -3, MONTH)
)
```

---

**Repeat Customer Rate** — Two-pass aggregation using nested `SUMMARIZE` + `FILTER`. Builds a per-customer order count, isolates customers with 2+ orders, divides by total distinct customers:

```dax
Repeat Customer Rate =
DIVIDE(
    COUNTROWS(
        FILTER(
            SUMMARIZE(fact_orders, fact_orders[customer_key], "cnt", COUNTROWS(fact_orders)),
            [cnt] >= 2
        )
    ),
    DISTINCTCOUNT(fact_orders[customer_key])
)
```

---

**YoY Revenue %** — Year-over-year revenue comparison using `SAMEPERIODLASTYEAR`. Requires `dim_date` marked as a Date Table on `full_date`:

```dax
YoY Revenue % =
DIVIDE(
    [YoY Revenue],
    CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dim_date[full_date]))
)
```

---

## Progress Tracker

- [x] Phase 0 — Setup, scaffold, business case, data dictionary
- [x] Phase 1 — Bronze layer (incremental ingestion, pipeline logging, schema drift)
- [x] Phase 2 — Silver layer (Dataflows Gen2, PySpark validation)
- [x] Phase 3 — Gold layer (T-SQL star schema, Kimball modeling)
- [x] Phase 4 — CI/CD & Deployment Documentation
- [x] Phase 5 — Semantic Model, Direct Lake, DAX library
- [ ] Phase 6 — Power BI report (3 pages)
- [ ] Phase 7 — Export, README final, executive memo, publish

---

_Built by Michael Hoover · [linkedin.com/in/michael-hoover-365data](https://linkedin.com/in/michael-hoover-365data) · [github.com/hoover180](https://github.com/hoover180)_
