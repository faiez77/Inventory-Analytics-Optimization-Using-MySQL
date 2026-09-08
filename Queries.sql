-- ============================================================
-- Inventory Analytics & Optimization — Analysis Queries
-- ============================================================

USE inventory_db;

-- ------------------------------------------------------------
-- 1. Daily Demand
--    Average units sold per day, per product.
--    Sales table is the source of demand signal.
-- ------------------------------------------------------------
CREATE VIEW daily_demand AS
SELECT
    product_id,
    ROUND(SUM(quantity_sold) / COUNT(DISTINCT sale_date), 2) AS avg_daily_demand
FROM sales
GROUP BY product_id;

-- ------------------------------------------------------------
-- 2. Inventory Turnover
--    How efficiently stock is being sold through.
--    Higher = efficient usage, Lower = excess / dead stock.
-- ------------------------------------------------------------
CREATE VIEW inventory_turnover AS
SELECT
    s.product_id,
    ROUND(SUM(s.quantity_sold) / i.stock_quantity, 2) AS turnover_ratio
FROM sales s
JOIN inventory i ON s.product_id = i.product_id
GROUP BY s.product_id, i.stock_quantity;

-- ------------------------------------------------------------
-- 3. Reorder Point Analysis
--    Reorder Point = Avg Daily Demand x Supplier Lead Time
--    Tells us the stock level at which a new order should be placed.
-- ------------------------------------------------------------
CREATE VIEW reorder_analysis AS
SELECT
    p.product_id,
    p.product_name,
    p.category,
    i.stock_quantity,
    d.avg_daily_demand,
    sup.lead_time_days,
    ROUND(d.avg_daily_demand * sup.lead_time_days) AS reorder_point
FROM products p
JOIN inventory i         ON p.product_id = i.product_id
JOIN daily_demand d      ON p.product_id = d.product_id
JOIN product_supplier ps ON p.product_id = ps.product_id
JOIN suppliers sup       ON ps.supplier_id = sup.supplier_id;

-- ------------------------------------------------------------
-- 4. Inventory Status
--    Converts numeric stock data into an actionable decision.
-- ------------------------------------------------------------
CREATE VIEW inventory_status AS
SELECT
    *,
    CASE
        WHEN stock_quantity < reorder_point THEN 'Understock'
        WHEN stock_quantity BETWEEN reorder_point AND reorder_point * 1.5 THEN 'Optimal'
        ELSE 'Overstock'
    END AS stock_status
FROM reorder_analysis;

-- ------------------------------------------------------------
-- 5. Supporting business queries
-- ------------------------------------------------------------

-- Top 5 fastest-moving products by average daily demand
SELECT p.product_name, p.category, d.avg_daily_demand
FROM daily_demand d
JOIN products p ON p.product_id = d.product_id
ORDER BY d.avg_daily_demand DESC
LIMIT 5;

-- Products currently flagged for reorder, most urgent first
-- (largest shortfall between stock on hand and reorder point)
SELECT
    product_name,
    category,
    stock_quantity,
    reorder_point,
    (reorder_point - stock_quantity) AS units_short,
    stock_status
FROM inventory_status
WHERE stock_status = 'Understock'
ORDER BY units_short DESC;

-- Category-level summary: average turnover and how many products
-- in each category are currently overstocked
SELECT
    p.category,
    ROUND(AVG(t.turnover_ratio), 2) AS avg_turnover,
    SUM(CASE WHEN s.stock_status = 'Overstock' THEN 1 ELSE 0 END) AS overstocked_products,
    COUNT(*) AS total_products
FROM products p
JOIN inventory_turnover t ON p.product_id = t.product_id
JOIN inventory_status s   ON p.product_id = s.product_id
GROUP BY p.category;

-- Supplier reliability view: average lead time vs. how many of
-- their products are currently understocked (a slow supplier
-- feeding fast-moving products is a real supply-chain risk)
SELECT
    sup.supplier_name,
    sup.lead_time_days,
    COUNT(*) AS products_supplied,
    SUM(CASE WHEN s.stock_status = 'Understock' THEN 1 ELSE 0 END) AS understocked_products
FROM suppliers sup
JOIN product_supplier ps ON sup.supplier_id = ps.supplier_id
JOIN inventory_status s  ON ps.product_id = s.product_id
GROUP BY sup.supplier_name, sup.lead_time_days
ORDER BY understocked_products DESC;
