# DAX Measures Library

**Semantic model:** `ecommerce_semantic_model` (Direct Lake on OneLake, over `[Gold]` schema in `ecommerce_warehouse`)
**21 measures**, organized into 5 Display Folders: Revenue, Delivery, Quality, Customer, Seller.

All measures live on a single physical `_Measures` table — a one-row placeholder table in `[Gold]` with a hidden dummy column, created because Direct Lake doesn't reliably support DAX-defined calculated tables. Display Folders group measures within that one table's field list.

---

## Revenue

### Total Revenue

```dax
Total Revenue =
SUMX(
    VALUES(fact_orders[order_id]),
    CALCULATE(MAX(fact_orders[payment_value]))
)
```

Format: Currency, `"R$" #,0.00`, Display Folder: Revenue

`payment_value` is order-level data (summed once per order across all payment installments in the Gold build) broadcast identically across every item row of that order in the item-grain `fact_orders` table. A plain `SUM` would multiply-count every multi-item order. `SUMX` over distinct `order_id` with `CALCULATE(MAX(...))` picks the already-correct order total once per order via context transition, rather than summing a repeated value.

This is a corrective DAX pattern necessitated by the current fact table's item grain carrying an order-level attribute — a production redesign splitting `fact_orders` into a separate order-grain fact (payments, reviews, delivery) and item-grain fact (price, freight, seller, product) would let this be a plain `SUM` with no iterator. Not implemented here; a documented, conscious trade-off given this project's scope.

**Validated: R$15,846,280.17** (unfiltered)

### YoY Revenue

```dax
YoY Revenue =
[Total Revenue] - CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dim_date[full_date]))
```

Format: Currency, `"R$" #,0.00`, Display Folder: Revenue

Requires `dim_date` marked as Date Table. Undefined (blank) wherever the selected period has no corresponding prior-year data in the dataset.

### YoY Revenue %

```dax
YoY Revenue % =
DIVIDE([YoY Revenue], CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dim_date[full_date])))
```

Format: Percentage, 1 decimal, Display Folder: Revenue

---

## Delivery

### Total Orders

```dax
Total Orders = DISTINCTCOUNT(fact_orders[order_id])
```

Format: Whole Number, Display Folder: Delivery

Count of distinct orders — lower than the fact row count (112,650) because the fact table is order-item grain, not order grain. Also lower than the full `orders` source table (99,441) because ~775 orders never received a line item (cancelled/unavailable before fulfillment) and so never appear in `fact_orders` at all.

**Validated: 98,666** (unfiltered)

### Late Orders

```dax
Late Orders =
CALCULATE(
    DISTINCTCOUNT(fact_orders[order_id]),
    fact_orders[is_late] = 1
)
```

Format: Whole Number, Display Folder: Delivery

**Validated: 7,827**

### On-Time Delivery Rate

```dax
On-Time Delivery Rate =
VAR DeliveredOrders = CALCULATE([Total Orders], fact_orders[is_delivered] = 1)
RETURN
    DIVIDE(DeliveredOrders - [Late Orders], DeliveredOrders)
```

Format: Percentage, 1 decimal, Display Folder: Delivery

Percentage of _delivered_ orders that arrived on or before the estimated date. The denominator is restricted to `is_delivered = 1` — an earlier version of this measure used `Total Orders` (all statuses) as the denominator, which implicitly counted every cancelled/unavailable order as "on-time" (since `is_late` defaults to 0, not blank, for orders with no delivery date). `Late Orders` is reused as-is for the numerator, since `is_late = 1` can only occur on an already-delivered order — no additional filter needed there.

**Validated: 91.9%** (91.89%)

### Avg Delivery Days

```dax
Avg Delivery Days =
AVERAGEX(
    VALUES(fact_orders[order_id]),
    CALCULATE(MAX(fact_orders[delivery_days]))
)
```

Format: Decimal Number, 1 decimal, Display Folder: Delivery

`delivery_days` is order-level, broadcast across item rows — `AVERAGEX` over distinct `order_id` prevents multi-item orders from being overweighted relative to single-item orders. `MAX` inside `CALCULATE` picks the per-order constant (functionally identical to `AVERAGE` here, used for idiom consistency with `Total Revenue`).

**Validated: 12.09 days** (delivered orders only, since `delivery_days` is blank for undelivered orders and `AVERAGEX` silently skips blanks)

### Bucket Drop %

```dax
Bucket Drop % =
VAR CurrentScore = [Avg Review Score - Delivered]
VAR PreviousBucket =
    SWITCH(
        SELECTEDVALUE(fact_orders[days_late_bucket]),
        "1-3 Days Late", "On-Time",
        "4-6 Days Late", "1-3 Days Late",
        "7+ Days Late", "4-6 Days Late",
        BLANK()
    )
VAR PreviousScore =
    CALCULATE(
        [Avg Review Score - Delivered],
        REMOVEFILTERS(
            fact_orders[days_late_bucket],
            fact_orders[days_late_bucket_sort]
        ),
        fact_orders[days_late_bucket] = PreviousBucket
    )
RETURN
    DIVIDE(CurrentScore - PreviousScore, PreviousScore)
```

Format: Percentage (`0%;-0%;0%`), Display Folder: Delivery

Percentage change in `Avg Review Score - Delivered` versus the _immediately preceding_ lateness bucket (On-Time → 1-3 Days Late → 4-6 Days Late → 7+ Days Late), looked up dynamically via `days_late_bucket`. Returns a negative value, reflecting the decline. Blank on the On-Time bucket, which has no prior bucket to compare against.

### Carrier Transit Std Dev

```dax
Carrier Transit Std Dev =
STDEVX.P(
    VALUES(fact_orders[order_id]),
    CALCULATE(MAX(fact_orders[carrier_transit_days]))
)
```

Format: `0.0`, Display Folder: Delivery

Standard deviation of carrier transit time (`order_delivered_carrier_date` to `order_delivered_customer_date`, computed via `DATEDIFF(MINUTE, ...) / 1440` for true floor-based elapsed days — matching `delivery_days`/`days_late`'s semantics rather than `DATEDIFF(DAY, ...)`'s calendar-boundary-crossing count) across distinct orders.

`STDEVX.P` (population, not sample) — this measures observed variability across the full order population in the current filter context, not an estimate drawn from a sample of a larger population. De-fans-out via `VALUES(order_id)` + `CALCULATE(MAX(...))`, the same pattern as `Total Revenue` and `Avg Delivery Days`, since `carrier_transit_days` is order-level, broadcast across item-grain `fact_orders` rows.

**Validated:** RJ 10.7 vs. SP 5.7 — despite São Paulo handling roughly 3x Rio de Janeiro's order volume, RJ's carrier-transit variability is nearly double SP's, indicating a reliability problem rather than a scale problem.

### Avg Days Late

```dax
Avg Days Late =
AVERAGEX(
    CALCULATETABLE(VALUES(fact_orders[order_id]), fact_orders[is_late] = 1),
    CALCULATE(MAX(fact_orders[days_late]))
)
```

Format: Decimal Number, 1 decimal, Display Folder: Delivery

`CALCULATETABLE` pre-filters the iteration table to late orders (~7,827 of 98,666) before `AVERAGEX` runs, rather than iterating all orders and relying on blank-propagation to skip on-time ones.

**Validated: 8.87 days**

### Orders Delivered

```dax
Orders Delivered =
CALCULATE(
    [Total Orders],
    USERELATIONSHIP(fact_orders[delivery_date_key], dim_date[date_key]),
    NOT(ISBLANK(fact_orders[delivery_date_key]))
)
```

Format: Whole Number, Display Folder: Delivery

Activates the inactive `delivery_date_key → dim_date` relationship for this measure only. `USERELATIONSHIP` _replaces_ the active `order_date_key` relationship's filter propagation for the scope of this `CALCULATE` — it does not run alongside it as a simultaneous condition (standard role-playing-dimension semantics).

**Validated: 96,476**

---

## Quality

### Avg Review Score

```dax
Avg Review Score =
AVERAGEX(
    VALUES(fact_orders[order_id]),
    CALCULATE(MAX(fact_orders[review_score]))
)
```

Format: Decimal Number, 2 decimals, Display Folder: Quality

`review_score` is order-level (the most recent review per order), broadcast across item rows — same de-fan-out pattern as `Avg Delivery Days`. 942 null `review_score` rows are excluded automatically by `AVERAGEX`'s blank-skip behavior.

Verified via direct replication against the raw source CSVs: the review dataset itself has zero null or invalid scores. The 942 nulls are exactly 749 orders that received no review submission at all — 636 single-item orders and 113 multi-item orders (76 with 2 items, 22 with 3, 8 with 4, 6 with 6, one with 20), fully accounting for the 942-vs-749 gap.

**Validated: 4.10** (across 97,917 reviewed orders)

### Avg Review Score - Delivered

```dax
Avg Review Score - Delivered =
CALCULATE([Avg Review Score], fact_orders[order_status] = "delivered")
```

Format: Decimal Number, 2 decimals, Display Folder: Quality

Deliberate exception to the "include all statuses" policy applied to money measures — satisfaction is a delivery-outcome question, not a revenue-inclusion question. Score is slightly higher than the unfiltered figure (orders that never arrived skew toward lower/angrier reviews when reviewed at all).

**Validated: 4.16** (across 95,832 delivered-and-reviewed orders)

### Review Score Rolling 3M

```dax
Review Score Rolling 3M =
CALCULATE(
    [Avg Review Score],
    DATESINPERIOD(dim_date[full_date], LASTDATE(dim_date[full_date]), -3, MONTH)
)
```

Format: Decimal Number, 2 decimals, Display Folder: Quality

Purchase-dated (uses the active `order_date_key` relationship) — "orders placed in the last 3 months," not "reviews received in the last 3 months." Confirm this matches the intended business definition before building visuals on it; a review-date-based version would need a different relationship.

---

## Customer

### Total Customers

```dax
Total Customers = DISTINCTCOUNT(fact_orders[customer_key])
```

Format: Whole Number, Display Folder: Customer

`customer_key` is derived from `customer_unique_id` (the real person), not the order-scoped `customer_id` — verified against the Gold SQL's `customer_lookup` CTE. Lower than `dim_customers`'s row count (96,096) because 676 customers' only order(s) fall among the ~775 orders with no line items, so they never appear in `fact_orders`.

**Validated: 95,420**

### Repeat Customer Rate

```dax
Repeat Customer Rate =
VAR CustomerOrderCounts =
    ADDCOLUMNS(
        VALUES(fact_orders[customer_key]),
        "cnt", CALCULATE(DISTINCTCOUNT(fact_orders[order_id]))
    )
VAR RepeatCustomers = COUNTROWS(FILTER(CustomerOrderCounts, [cnt] >= 2))
VAR TotalCustomers = COUNTROWS(CustomerOrderCounts)
RETURN
    DIVIDE(RepeatCustomers, TotalCustomers)
```

Format: Percentage, 1 decimal, Display Folder: Customer

**Period-aware, not lifetime** — reflects repeat behavior within whatever filter context is active (a date slicer changes this number), not a fixed lifetime-loyalty metric. 92,507 of 95,420 customers (97%) ordered exactly once — a low repeat rate, but realistic given Olist's marketplace of small/regional sellers and the dataset's ~2-year span.

**Validated: 3.1%** (2,913 repeat customers of 95,420)

### Avg Revenue per Customer

```dax
Avg Revenue per Customer = DIVIDE([Total Revenue], [Total Customers])
```

Format: Currency, `"R$" #,0.00`, Display Folder: Customer

Average revenue per customer in the current filter context — not Customer Lifetime Value in the fuller analytics sense (no retention, margin, or acquisition-cost modeling), hence the more literal name. Implemented as a plain `DIVIDE` rather than a per-customer iterator: averaging each customer's total revenue across all customers is mathematically identical to `Total Revenue / Total Customers`, since per-customer totals partition the whole without overlap, so no iterator is needed to get the correct result.

**Validated: R$166.07**

### Avg Order Value

```dax
Avg Order Value = DIVIDE([Total Revenue], [Total Orders])
```

Format: Currency, `"R$" #,0.00`, Display Folder: Customer

**Validated: R$160.61**

---

## Seller

### Total Sellers

```dax
Total Sellers = DISTINCTCOUNT(dim_sellers[seller_id])
```

Format: Whole Number, Display Folder: Seller

Static count of every seller in the dimension. Does not respond to date/period filters — `dim_sellers` has no incoming filter path from `fact_orders` under this model's single cross-filter direction.

**Validated: 3,095**

### Seller SLA Compliance

```dax
Seller SLA Compliance = AVERAGE(dim_sellers[on_time_rate])
```

Format: Percentage, 1 decimal, Display Folder: Seller

Reads a pre-aggregated Gold-layer column directly (`dim_sellers.on_time_rate`) rather than recomputing from `fact_orders` — the Gold SQL already deduplicates to seller-order grain and restricts the calculation to delivered orders only. `AVERAGE()` natively ignores the 125 sellers whose `on_time_rate` is correctly `NULL` (zero delivered orders).

**Lifetime attribute** — does not respond to date/period filters, same reason as `Total Sellers`. Label clearly on any report page where it sits alongside period-aware measures like `On-Time Delivery Rate`.

**Validated: 91.6%**

### % Sellers Below 80% SLA

```dax
% Sellers Below 80% SLA =
DIVIDE(
    CALCULATE(DISTINCTCOUNT(dim_sellers[seller_id]), dim_sellers[sla_compliance_bucket] IN {"0-60%", "60-80%"}),
    CALCULATE(DISTINCTCOUNT(dim_sellers[seller_id]), NOT ISBLANK(dim_sellers[on_time_rate]))
)
```

Format: Percentage, 1 decimal, Display Folder: Seller

Denominator restricted to sellers with a measurable `on_time_rate` (2,970 of 3,095) — the 125 sellers with zero delivered orders can never appear in the numerator bucket set, but would otherwise silently dilute the percentage if left in the denominator too. Same lifetime caveat as `Seller SLA Compliance`.

**Validated: 10.6%** (315 of 2,970)

---

## Known limitations

- **Item-grain fact carrying order-level fields is a deliberate architectural trade-off**, not an oversight. `payment_value`, `review_score`, `delivery_days`, `days_late` all live on `fact_orders` (order-item grain) despite being order-level attributes, which is why so many measures above need a `VALUES(order_id)`-based de-fan-out pattern. A production redesign splitting this into a separate order-grain fact would eliminate most of that DAX complexity. Not implemented here, given this project's scope.
- **Olist's actual data range is short and ends mid-month** (roughly September 2016 – August 2018). `YoY Revenue`/`YoY Revenue %` will be undefined wherever no prior-year data exists, and `Review Score Rolling 3M` will look thin at the very start of the series and at the last partial month.
- **`Repeat Customer Rate` is period-aware, not lifetime** — it changes under a date slicer.
- **`Seller SLA Compliance`, `% Sellers Below 80% SLA`, and `Total Sellers` are lifetime/static, not period-aware** — `dim_sellers` has no incoming filter path from `fact_orders` under this model's single cross-filter direction, so a date slicer won't change these numbers even on the same report page as measures that do respond to it. Label clearly wherever this could cause confusion.
- **Money measures (`Total Revenue`, `Avg Order Value`, `Avg Revenue per Customer`, `YoY Revenue`) include every order status**, consistently with each other. `Avg Review Score - Delivered` is the one deliberate delivered-only exception.
