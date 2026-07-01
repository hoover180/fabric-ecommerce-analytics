# DAX Measures Library

**Project:** E-Commerce Delivery Analytics Platform  
**Model:** ecommerce_semantic_model (Direct Lake)  
**Author:** Michael Hoover | github.com/hoover180  
**Updated:** July 2026

All measures live in the `_Measures` table. None are attached to individual
dimension or fact tables — this separates the semantic layer from the physical
model and keeps the field panel clean for report authors.

---

## Important Data Notes

**payment_value fan-out:** `payment_value` is an order-level attribute stored
on an item-grain fact table. Each order with multiple items fans out the payment
value across all item rows. Any measure that aggregates `payment_value` must
deduplicate at the `order_id` level before summing. See `Total Revenue` for the
canonical pattern. This matches the `SELECT DISTINCT order_id, payment_value`
logic used in `val_revenue.sql` — both approaches return **$15,846,280.17**.

**Null review_score:** 5,556 rows in `fact_orders` have null `review_score` —
4,562 represent orders with no review submitted; ~994 failed Silver validity
checks. DAX aggregate functions (`AVERAGE`, `SUM`) ignore nulls by default.
Measures that count or filter on `review_score` should account for this null
population.

**Inactive relationship:** `fact_orders[delivery_date_key]` →
`dim_date[date_key]` is marked inactive. Only `order_date_key` drives the
active date relationship. Any measure filtering by delivery date must activate
this relationship explicitly using `USERELATIONSHIP()`.

---

## Revenue Measures

### Total Revenue

**Category:** Revenue  
**Format:** Currency, 2 decimal places, thousands separator on

```dax
Total Revenue =
SUMX(
    SUMMARIZE(fact_orders, fact_orders[order_id], "pv", MAX(fact_orders[payment_value])),
    [pv]
)
```

**Description:** Total revenue across all orders in the current filter context.
Deduplicates `payment_value` at the `order_id` level before summing to prevent
fan-out overcount on multi-item orders. `MAX()` per `order_id` selects the
single payment value for that order before `SUMX` aggregates across all orders.

**Validation:** Returns **$15,846,280.17** unfiltered — matches `val_revenue.sql`
to the penny.

**Edge cases:** 774 orders appear in `order_payments` but have no corresponding
items in `fact_orders` (legitimately excluded at the Gold layer). These do not
affect this measure.

---

### YoY Revenue

**Category:** Revenue  
**Format:** Currency, 2 decimal places, thousands separator on

```dax
YoY Revenue =
[Total Revenue] - CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dim_date[full_date]))
```

**Description:** Year-over-year revenue change in absolute dollars. Compares
current period `Total Revenue` to the same period in the prior year using
`SAMEPERIODLASTYEAR`. Inherits the fan-out deduplication from `Total Revenue`
automatically.

**Edge cases:** Returns blank when no prior year data exists. 2016 will return
blank because the dataset begins mid-2016 with no 2015 data to compare against.
Requires `dim_date` to be marked as a Date Table — this is configured on
`full_date`.

---

### YoY Revenue %

**Category:** Revenue  
**Format:** Percentage, 1 decimal place

```dax
YoY Revenue % =
DIVIDE(
    [YoY Revenue],
    CALCULATE([Total Revenue], SAMEPERIODLASTYEAR(dim_date[full_date]))
)
```

**Description:** Year-over-year revenue change as a percentage. Divides
`YoY Revenue` by prior year `Total Revenue`. `DIVIDE()` is used instead of
`/` to handle division by zero gracefully — returns blank rather than an error
when prior year revenue is zero or blank.

**Edge cases:** Returns blank for 2016 (no prior year). Negative values indicate
revenue decline year-over-year.

---

## Delivery Measures

### On-Time Delivery Rate

**Category:** Delivery  
**Format:** Percentage, 1 decimal place

```dax
On-Time Delivery Rate =
DIVIDE(
    CALCULATE(COUNTROWS(fact_orders), fact_orders[is_late] = 0),
    COUNTROWS(fact_orders)
)
```

**Description:** Percentage of orders delivered on or before the estimated
delivery date. Uses `CALCULATE` with a boolean column filter rather than
`FILTER(fact_orders, ...)` to leverage VertiPaq column indexes — more
efficient in Direct Lake mode at scale. `DIVIDE()` handles the zero
denominator case gracefully.

**Edge cases:** Includes undelivered orders (`is_delivered = 0`) in the
denominator. Undelivered orders have null `is_late` — they are not counted
in the numerator, which slightly suppresses the on-time rate. This is
intentional and correctly reflects marketplace performance.

---

### Late Orders

**Category:** Delivery  
**Format:** Whole number, thousands separator on

```dax
Late Orders = CALCULATE(COUNTROWS(fact_orders), fact_orders[is_late] = 1)
```

**Description:** Count of orders where the actual delivery date exceeded the
estimated delivery date (`is_late = 1`).

**Edge cases:** Undelivered orders have null `is_late` and are not counted.

---

### Avg Delivery Days

**Category:** Delivery  
**Format:** Decimal number, 1 decimal place

```dax
Avg Delivery Days = AVERAGE(fact_orders[delivery_days])
```

**Description:** Average number of days from order purchase timestamp to
customer delivery date. DAX `AVERAGE()` ignores nulls automatically —
undelivered orders (null `delivery_days`) are correctly excluded.

---

### Avg Days Late

**Category:** Delivery  
**Format:** Decimal number, 1 decimal place

```dax
Avg Days Late =
AVERAGEX(
    FILTER(fact_orders, fact_orders[is_late] = 1),
    fact_orders[days_late]
)
```

**Description:** Average number of days late for orders that missed the
estimated delivery date. Filters to `is_late = 1` rows only — on-time and
undelivered orders are excluded from this average. Uses `AVERAGEX` over a
filtered table rather than `AVERAGE` with a column filter to ensure the
filter is applied before aggregation.

---

## Quality Measures

### Avg Review Score

**Category:** Quality  
**Format:** Decimal number, 2 decimal places

```dax
Avg Review Score = AVERAGE(fact_orders[review_score])
```

**Description:** Average customer review score on a 1–5 scale across all
orders in the current filter context.

**Edge cases:** 5,556 rows have null `review_score` — 4,562 represent orders
with no review submitted; ~994 failed Silver validity checks. DAX `AVERAGE()`
ignores nulls by default, so these rows are correctly excluded without
additional filtering. Expected value: ~4.0–4.2 across the full unfiltered
dataset.

---

### Review Score Rolling 3M

**Category:** Quality  
**Format:** Decimal number, 2 decimal places

```dax
Review Score Rolling 3M =
CALCULATE(
    [Avg Review Score],
    DATESINPERIOD(dim_date[full_date], LASTDATE(dim_date[full_date]), -3, MONTH)
)
```

**Description:** Rolling 3-month average review score ending on the last date
in the current filter context. `DATESINPERIOD` dynamically shifts the 3-month
window as the filter context changes — useful for trend lines in the report.
Requires `dim_date` to be marked as a Date Table.

**Edge cases:** Inherits the null exclusion behavior from `Avg Review Score`.
At the start of the dataset (mid-2016), the 3-month window may include fewer
than 3 full months of data — the measure will still return a valid average
over whatever data exists in the window.

---

## Customer Measures

### Repeat Customer Rate

**Category:** Customer  
**Format:** Percentage, 1 decimal place

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

**Description:** Percentage of customers who placed more than one order.
`SUMMARIZE` builds a per-customer order count table; `FILTER` isolates
customers with 2 or more orders; `COUNTROWS` counts those customers;
`DISTINCTCOUNT` provides the total customer denominator.

**Note:** `customer_key` in `fact_orders` is derived from `customer_unique_id`
after deduplication at the Gold layer. The Silver `customers` table grain is
`customer_id` (order-scoped), not `customer_unique_id` — the Gold deduplication
step is what makes this measure meaningful.

---

### CLV

**Category:** Customer  
**Format:** Currency, 2 decimal places, thousands separator on

```dax
CLV =
AVERAGEX(
    SUMMARIZE(fact_orders, fact_orders[customer_key], "ltv", [Total Revenue]),
    [ltv]
)
```

**Description:** Average customer lifetime value — total revenue per customer
averaged across all customers in the current filter context. `SUMMARIZE`
calculates per-customer revenue using `[Total Revenue]` (the fan-out-corrected
SUMX measure), then `AVERAGEX` averages across all customers.

**Important:** Uses `[Total Revenue]` rather than `SUM(fact_orders[payment_value])`
directly — this inherits the order-level deduplication automatically. Substituting
the raw column would cause fan-out overcounting at the customer level.

---

## Seller Measures

### Seller SLA Compliance

**Category:** Seller  
**Format:** Percentage, 1 decimal place

```dax
Seller SLA Compliance = [On-Time Delivery Rate]
```

**Description:** Percentage of orders delivered on or before the estimated
delivery date, evaluated in the current filter context. References
`[On-Time Delivery Rate]` directly — the calculation is identical; the
distinction is semantic. This measure is intended for seller-level filtering
on the Seller Performance report page, where the filter context is scoped
to individual sellers or seller segments. Filter context handles the
seller-level scoping automatically — no additional logic required.

---

## Volume Measures

### Total Orders

**Category:** Volume  
**Format:** Whole number, thousands separator on

```dax
Total Orders = DISTINCTCOUNT(fact_orders[order_id])
```

**Description:** Count of distinct orders. Lower than the fact table row count
(112,650) because the fact grain is order-item, not order — multi-item orders
span multiple rows. `DISTINCTCOUNT` on `order_id` collapses to the true order
count.

**Validation:** Expected value ~99,441 unfiltered.

---

### Total Customers

**Category:** Volume  
**Format:** Whole number, thousands separator on

```dax
Total Customers = DISTINCTCOUNT(fact_orders[customer_key])
```

**Description:** Count of distinct customers in the current filter context.
Based on `customer_key` (derived from `customer_unique_id` after Gold
deduplication) — not `customer_id`, which is order-scoped in the source data.
The Gold deduplication step is what makes this measure meaningful.

---

### Avg Order Value

**Category:** Volume  
**Format:** Currency, 2 decimal places, thousands separator on

```dax
Avg Order Value = DIVIDE([Total Revenue], [Total Orders])
```

**Description:** Average revenue per order. Divides the fan-out-corrected
`[Total Revenue]` by `[Total Orders]`. Inherits the order-level deduplication from `Total Revenue`
automatically.

---

### Orders Delivered

**Category:** Delivery  
**Format:** Whole number, thousands separator on

```dax
Orders Delivered =
CALCULATE(
    [Total Orders],
    USERELATIONSHIP(fact_orders[delivery_date_key], dim_date[date_key]),
    NOT(ISBLANK(fact_orders[delivery_date_key]))
)
```

**Description:** Counts distinct orders physically delivered within the
selected date period. Activates the inactive `delivery_date_key →
dim_date[date_key]` relationship, shifting the filter context from order
date to delivery date. Excludes orders with null `delivery_date_key`
(undelivered orders).

**Note:** This is the canonical `USERELATIONSHIP` example in this model —
demonstrating how to activate an inactive relationship to answer a different
business question with the same dimension table.

---

## README Highlights — Five Most Technically Impressive Measures

These five are called out in the README DAX Measures section:

| Measure                   | Why It's Notable                                                                                                |
| ------------------------- | --------------------------------------------------------------------------------------------------------------- |
| `Total Revenue`           | Solves the fan-out problem — order-level value on item-grain fact requires SUMX/SUMMARIZE deduplication pattern |
| `On-Time Delivery Rate`   | CALCULATE with boolean column filter — uses VertiPaq indexes instead of row-by-row FILTER scan                  |
| `Review Score Rolling 3M` | Time intelligence with DATESINPERIOD — dynamic window shifts with filter context                                |
| `Repeat Customer Rate`    | Nested SUMMARIZE + FILTER — two-pass aggregation to count qualifying customers                                  |
| `YoY Revenue %`           | SAMEPERIODLASTYEAR time comparison — requires Date Table marking on dim_date                                    |

---

## Interview Notes

**Most likely interview questions on this model:**

_"Walk me through your most complex DAX measure."_

Lead with `CLV` or `Repeat Customer Rate` — both demonstrate nested table
functions. Then transition to `Total Revenue` to explain the fan-out problem,
which shows data modeling awareness beyond just DAX syntax.

_"Why did you use SUMX instead of SUM for Total Revenue?"_

"`payment_value` is an order-level attribute stored on an item-grain fact table.
Each order with multiple items fans the value across all item rows. SUM would
overcount in proportion to average items per order. SUMX over SUMMARIZE
deduplicates at the order level first — the same logic as a SQL SELECT DISTINCT
before a SUM — and I validated it against my val_revenue.sql script which
returned the identical figure."

_"How does the inactive relationship affect your DAX?"_

"The delivery_date_key to dim_date relationship is inactive because Power BI
only allows one active relationship between two tables. The order_date_key
relationship is active by default. Any measure that needs to filter by delivery
date rather than order date activates that relationship explicitly using
USERELATIONSHIP inside a CALCULATE. The Orders Delivered measure is the
canonical example in this model."

_"Why did you put all measures in a \_Measures table instead of on fact_orders?"_

"It separates the semantic layer from the physical model. Report authors see a
clean field panel with measures grouped together and no surrogate key columns
or technical columns mixed in. It also makes the model easier to maintain —
all DAX logic is in one place regardless of which tables the measures reference."

_"Why CALCULATE instead of FILTER for Late Orders and On-Time Delivery Rate?"_

"FILTER(fact_orders, ...) forces DAX to iterate the fact table row by row.
CALCULATE with a boolean column filter passes the condition to VertiPaq's
column indexes directly, which is more efficient — especially in Direct Lake
mode where minimizing unnecessary row iteration matters for interactive
report performance."
