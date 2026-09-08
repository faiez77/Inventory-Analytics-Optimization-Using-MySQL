# Inventory Analytics & Reorder Optimization (MySQL)


An end-to-end inventory analytics project that turns raw sales and stock
data into reorder decisions. Written in MySQL, using views and window-style
aggregation to calculate demand, turnover, and reorder points — then flags
each product as **Understock / Optimal / Overstock**.

"Project Objective: Analyze inventory performance and optimize replenishment decisions using MySQL — transforming raw sales and inventory data into actionable business metrics."

## Project structure

```
inventory-project/
├── sql/
│   ├── schema.sql          -- table definitions only
│   └── queries.sql         -- views + analysis queries
├── data/
│   └── seed_data.sql       -- generated sample data (see note below)
├── scripts/
│   └── generate_data.py    -- reproducible data generator
└── README.md
```

## A note on the data

This is a portfolio project, so the dataset is **synthetically generated**
rather than pulled from a live business — there's no real bank, retailer,
or supplier behind it. `scripts/generate_data.py` builds the data with
realistic retail patterns rather than pure randomness:

- Demand varies by category (Electronics moves faster than Home Appliances)
- Weekend demand is boosted vs. weekdays, like real consumer retail
- A subset of products are deliberately made slow-movers or fast-movers,
  so the final dashboard shows a genuine spread of stock statuses instead
  of everything landing in the same bucket
- Stock levels are set relative to each product's own computed reorder
  point (not an arbitrary number), so turnover ratios and reorder flags
  come out in a believable range

Run `python scripts/generate_data.py` to regenerate `data/seed_data.sql`
with a different random seed if you want a different distribution.

## Business questions this answers

- How fast is each product actually selling? (`daily_demand`)
- How efficiently is stock being used? (`inventory_turnover`)
- At what stock level should we reorder, given each supplier's lead time?
  (`reorder_analysis`)
- Which products need action right now — reorder, fine, or overstocked?
  (`inventory_status`)
- Which suppliers are a bottleneck (slow lead time + products often
  understocked)?

## Schema

| Table              | Purpose                                             |
|--------------------|------------------------------------------------------|
| `products`         | Product catalog (name, category)                    |
| `suppliers`         | Supplier name + lead time in days                    |
| `product_supplier` | Maps each product to its supplier                    |
| `inventory`        | Current stock level per product                      |
| `sales`            | Transaction-level sales history                      |

## Key formulas

```
Avg Daily Demand = Total Units Sold / Number of Distinct Sale Days
Reorder Point    = Avg Daily Demand x Supplier Lead Time
Turnover Ratio   = Total Units Sold / Current Stock Quantity
```

**Stock status logic:**
- `stock_quantity < reorder_point` → **Understock** (risk of stockout)
- `reorder_point <= stock_quantity <= 1.5x reorder_point` → **Optimal**
- above that → **Overstock** (tying up capital/storage)

## Assumptions

- Sales data represents consistent, comparable time intervals
- Supplier lead time is treated as constant per product
- Safety stock is not included in the reorder point formula (kept simple
  by design — see "What I'd extend next")
- Inventory quantity reflects a real-time stock snapshot

## Sample findings (from the generated dataset)

- Out of 30 products, the reorder logic correctly isolates the 4 products
  deliberately simulated as fast-movers as **Understock**, and 3 of the 4
  simulated slow-movers as **Overstock** — confirming the SQL logic
  produces sensible, actionable output.
- Electronics products carry a noticeably higher average daily demand
  than Home Appliances, consistent with the category-level demand
  multipliers used to generate the data.
- Suppliers with longer lead times (10–14 days) are disproportionately
  linked to Understock flags — exactly the "slow supplier feeding a
  fast-moving product" risk this project is designed to surface.

## How to run

```bash
mysql -u root -p < sql/schema.sql
mysql -u root -p < data/seed_data.sql
mysql -u root -p < sql/queries.sql
```

Then, in MySQL Workbench or CLI:

```sql
USE inventory_db;
SELECT * FROM inventory_status ORDER BY stock_status, product_name;
```

## What I'd extend next

- Add a `safety_stock` column and fold it into the reorder point formula
  (currently omitted — see Assumptions below)
- Connect to Power BI for a KPI dashboard (stock status by category,
  supplier risk matrix)
- Swap in a real public retail dataset (e.g. a Kaggle inventory dataset)
  once the pipeline logic is validated, as a natural "v2"

## Author

Faiez — final-year engineering student, IIT Indore.
