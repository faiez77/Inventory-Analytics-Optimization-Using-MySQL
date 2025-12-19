CREATE DATABASE db;
USE db;

CREATE TABLE products (
    product_id INT PRIMARY KEY,
    product_name VARCHAR(100),
    category VARCHAR(50)
);
CREATE TABLE suppliers (
    supplier_id INT PRIMARY KEY,
    supplier_name VARCHAR(100),
    lead_time_days INT
);
CREATE TABLE product_supplier (
    product_id INT,
    supplier_id INT,
    PRIMARY KEY (product_id, supplier_id),
    FOREIGN KEY (product_id) REFERENCES products(product_id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);
CREATE TABLE inventory (
    product_id INT PRIMARY KEY,
    stock_quantity INT,
    last_updated DATE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
CREATE TABLE sales (
    sale_id INT PRIMARY KEY,
    product_id INT,
    sale_date DATE,
    quantity_sold INT,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

INSERT INTO products VALUES
(1,'Laptop','Electronics'),
(2,'Mobile','Electronics'),
(3,'Headphones','Accessories'),
(4,'Keyboard','Accessories');

INSERT INTO suppliers VALUES
(1,'ABC Electronics',7),
(2,'XYZ Distributors',14);

INSERT INTO product_supplier VALUES
(1,1),(2,1),(3,2),(4,2);

INSERT INTO inventory VALUES
(1,20,'2024-04-01'),
(2,50,'2024-04-01'),
(3,200,'2024-04-01'),
(4,15,'2024-04-01');

INSERT INTO sales VALUES
(1,1,'2024-03-01',5),
(2,1,'2024-03-05',3),
(3,2,'2024-03-02',10),
(4,3,'2024-03-10',2),
(5,4,'2024-03-08',4);

-- select * from products;
-- select * from suppliers;
-- select * from product_supplier;
-- select * from inventory;
-- select * from sales;

-- Daily Demand  : Sales table capture demand 
CREATE VIEW daily_demand AS
SELECT
    product_id,
    ROUND(SUM(quantity_sold) / COUNT(DISTINCT sale_date), 2) AS avg_daily_demand
FROM sales
GROUP BY product_id;

select * from daily_demand;

-- Inventory turnover(efficiency metric)
CREATE VIEW inventory_turnover AS
SELECT
    s.product_id,
    SUM(s.quantity_sold) / i.stock_quantity AS turnover_ratio
FROM sales s
JOIN inventory i ON s.product_id = i.product_id
GROUP BY s.product_id;

select * from inventory_turnover;

-- Reorder point (Reorder Point = Daily Demand × Lead Time) :
CREATE VIEW reorder_analysis AS
SELECT
    p.product_id,
    p.product_name,
    i.stock_quantity,
    d.avg_daily_demand,
    sup.lead_time_days,
    ROUND(d.avg_daily_demand * sup.lead_time_days) AS reorder_point
FROM products p
JOIN inventory i ON p.product_id = i.product_id
JOIN daily_demand d ON p.product_id = d.product_id
JOIN product_supplier ps ON p.product_id = ps.product_id
JOIN suppliers sup ON ps.supplier_id = sup.supplier_id;

select * from reorder_analysis;

-- inventory status
CREATE VIEW inventory_status AS
SELECT
    *,
    CASE
        WHEN stock_quantity < reorder_point THEN 'Understock'
        WHEN stock_quantity BETWEEN reorder_point AND reorder_point * 1.5 THEN 'Optimal'
        ELSE 'Overstock'
    END AS stock_status
FROM reorder_analysis;

