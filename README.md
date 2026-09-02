# E-Commerce Delivery Analytics Platform

[![SQL Lint](https://github.com/hoover180/ecommerce-analytics/actions/workflows/sql_lint.yml/badge.svg)](https://github.com/hoover180/ecommerce-analytics/actions/workflows/sql_lint.yml)

> **Business Problem:**
>
> What delivery and seller factors drive customer dissatisfaction in a Brazilian e-commerce marketplace?
>
> Can we identify which regions and seller segments are responsible for the highest rates of delayed deliveries and negative reviews?

---

## Key Findings

- **Late deliveries drive dissatisfaction.** Review scores fall 16% in the first 1–3 days late, then drop a further 40% from that already-lower level in days 4–6 (a ~49% cumulative decline from the on-time baseline), before largely leveling off by day 7.
- **Rio de Janeiro (RJ) is disproportionately unreliable — not just high-volume.** RJ generates 21.3% of all late deliveries on just 12.8% of order volume. The cause is carrier-transit inconsistency (10.7-day std. dev.), nearly double São Paulo's (5.7), despite São Paulo handling ~3x RJ's order volume.
- **10.6% of sellers carry outsized reputational risk.** Sellers below an 80% on-time delivery standard average a 3.35 review score vs. 4.19 for compliant sellers — a 0.84-point (20%) gap tied directly to delivery reliability.

📄 **[Executive Recommendation Memo (PDF)](exports/executive_memo.pdf)** — 1-page, non-technical summary for leadership

📊 **[Full Report (PDF)](exports/ecommerce_analytics_report.pdf)** — all 3 pages, view without Power BI installed

---

## Report Pages

**Executive Summary**
![Executive Summary page: KPI Cards for Total Revenue, Orders Delivered, Late Orders, On-Time Rate, and Avg Review Score; Customer Review Score Trend over Time; Customer Satisfaction by Delivery Lateness](docs/screenshots/report_page1_executive_summary.png)

**Delivery Performance**
![Delivery Performance page: Late Orders by Customer State, Late Orders and Carrier Transit Std Dev by Customer State, Carrier Transit Variability Trend over Time for RJ vs SP](docs/screenshots/report_page2_delivery_performance.png)

**Seller Performance**
![Seller Performance page: Seller Reliability vs Customer Satisfaction Scatter, SLA compliance buckets, Seller Table, KPI Cards](docs/screenshots/report_page3_seller_performance.png)

---

## Architecture

Full medallion architecture (Bronze → Silver → Gold) on Microsoft Fabric, orchestrated end-to-end and ending in a Direct Lake semantic model and Power BI report.

```mermaid
flowchart TD
    SRC["Kaggle CSVs<br/>(Olist Brazilian E-Commerce Dataset)"]

    subgraph ORCH["pl_ecommerce_orchestration.DataPipeline — orchestrated, not manual"]
        direction TB

        subgraph BRONZESEQ["Bronze Layer — sequential (chained due to Delta sync-write conflicts)"]
            direction LR
            B1["customers"] --> B2["orders"] --> B3["order_items"] --> B4["order_payments"] --> B5["order_reviews"] --> B6["sellers"] --> B7["products"] --> B8["product_category_translation"] --> B9["geolocation"]
        end

        GATE1{{"Bronze Validation Gate<br/>Lookup: check results → If Condition: halt on failure"}}

        SILVER["Silver Layer<br/>Dataflows Gen2 (7 tables) + PySpark notebook (geolocation dedup)<br/>Conforming · derived columns · deduplication"]

        GATE2{{"Silver Validation Gate<br/>Lookup: check results → If Condition: halt on failure"}}

        subgraph GOLDSEQ["Gold Layer — 4 dimension scripts (parallel) → fact_orders (depends on all 4)"]
            direction TB
            GD1["dim_date"]
            GD2["dim_customers"]
            GD3["dim_sellers"]
            GD4["dim_products"]
            GF["fact_orders"]
            GD1 --> GF
            GD2 --> GF
            GD3 --> GF
            GD4 --> GF
        end

        GATE3{{"Gold Validation Gate<br/>Lookup: check results → If Condition: halt on failure"}}

        BRONZESEQ --> GATE1
        GATE1 -->|"pass"| SILVER
        SILVER --> GATE2
        GATE2 -->|"pass"| GOLDSEQ
        GOLDSEQ --> GATE3
    end

    MODEL["Semantic Model<br/>ecommerce_semantic_model.SemanticModel<br/>Direct Lake · DAX measures · RLS (seller_rls, region_rls)"]
    REPORT["Power BI Report — .pbip (git-tracked source)<br/>ecommerce_report.Report<br/>3 pages: Executive Summary · Delivery Performance · Seller Performance"]

    SRC --> B1
    GATE3 -.->|"pass or fail — Direct Lake reads live regardless;<br/>failure only marks the pipeline run as Failed"| MODEL
    MODEL --> REPORT
    GATE1 -->|"fail → pipeline halts, Silver never runs"| FAIL["Run marked Failed<br/>pipeline_run_log / quality logs record failure"]
    GATE2 -->|"fail → pipeline halts, Gold never runs"| FAIL
    GATE3 -->|"fail → run marked Failed<br/>(no downstream activity to block)"| FAIL

    classDef stage fill:#eef4ff,stroke:#5b7fd4,stroke-width:1px,color:#1a2340;
    classDef gate fill:#fff2e6,stroke:#d98c3a,stroke-width:1px,color:#402a10;
    classDef fail fill:#fdecec,stroke:#c0504d,stroke-width:1px,color:#4a1a18;
    classDef source fill:#f2f2f2,stroke:#888,stroke-width:1px,color:#222;

    class SRC source;
    class B1,B2,B3,B4,B5,B6,B7,B8,B9,SILVER,GD1,GD2,GD3,GD4,GF,MODEL,REPORT stage;
    class GATE1,GATE2,GATE3 gate;
    class FAIL fail;
```

---

## Pipeline

Orchestrated via a Data Factory pipeline (Notebook → Validation → Dataflow → Validation → Gold SQL activities → Validation, with explicit dependency and success conditions) rather than run manually step-by-step.

![Pipeline](docs/screenshots/ecommerce_pipeline.png)

---

## Data Model

![Star Schema](docs/screenshots/star_schema.png)

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
- [x] Phase 4 — Orchestration pipeline, fail-fast validation gates, incremental loading
- [x] Phase 5 — Semantic Model, Direct Lake, DAX library
- [x] Phase 6 — Power BI report (3 pages, `.pbip` format)
- [ ] Phase 7 — Export, README final, executive memo, publish

---

_Built by Michael Hoover · [linkedin.com/in/michael-hoover-365data](https://linkedin.com/in/michael-hoover-365data) · [github.com/hoover180](https://github.com/hoover180)_
