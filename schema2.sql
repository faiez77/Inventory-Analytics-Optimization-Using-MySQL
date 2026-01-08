-- WITH DIFFERENT APPROACH


create database xyz;
use xyz;

CREATE table products (
 product_id int Primary key auto_increment,
 product_name varchar(100)  NOT NULL ,
 category varchar(50) ,
 unit_price Decimal(10,2)  NOT NULL,
 stock_quantity  int NOT NULL,
 reorder_level  int DEFAULT 10 ,
 created_at TIMESTAMP DEFAUlT CURRENT_TIMESTAMP
);

CREATE table sales(
sale_id int PRIMARY KEY auto_increment,
product_id int ,
quantity_sold  int NOT NULL,
sale_date date NOT NULL,
total_price DECIMAL (10,2) ,
FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE view sales_product_view as 
select 
s.sale_date,
s.sale_id,
p.product_id,
p.product_name,
p.category,
p.unit_price,
p.stock_quantity,
p.reorder_level,
s.quantity_sold,
s.total_price
 from sales  s 
 JOIN products p ON s.product_id = p.product_id ;
 
 INSERT INTO products (product_name, category, unit_price, stock_quantity, reorder_level)
VALUES
('Pasta', 'Grocery', 40.00, 100, 20),
('Rice', 'Grocery', 55.00, 200, 30),
('Milk', 'Dairy', 25.00, 80, 15),
('Soap', 'Personal Care', 30.00, 150, 25);

INSERT INTO sales (product_id, quantity_sold, sale_date, total_price)
VALUES
(1, 5, '2024-07-01', 200.00),
(1, 8, '2024-07-02', 320.00),
(2, 10, '2024-07-01', 550.00),
(3, 6, '2024-07-03', 150.00),
(4, 12, '2024-07-02', 360.00);

-- Revenue analysis
select  product_name , SUM(total_price) as REVENUE
from sales_product_view 
GROUP BY product_name;

-- sales volume
select  product_name , SUM(quantity_sold) as total_units_sold
from sales_product_view 
GROUP BY product_name;

-- sales velocity(avg no. of unit sold per day = total unit sold/no. of selling dates)
CREATE VIEW sales_velocity AS
SELECT
    product_name,
    ROUND(SUM(quantity_sold) / COUNT(DISTINCT sale_date), 2) AS sales_velocity
FROM sales_product_view
GROUP BY product_name;

-- turnover efficiency
-- stock quant is current snap , sales happen over time ,inventory change daily 
CREATE TABLE inventory_history (
    inventory_id INT PRIMARY KEY AUTO_INCREMENT,
    product_id INT,
    inventory_date DATE NOT NULL,
    stock_quantity INT NOT NULL,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
INSERT INTO inventory_history (inventory_id, product_id, inventory_date, stock_quantity)
VALUES
(1, 1, '2025-01-01', 120.00),
(2, 2, '2025-01-02', 115.00),
(3, 1, '2025-01-01', 110.00),
(4, 1, '2025-01-03', 108.00),
(5, 4, '2025-01-04', 105.00);


-- avg inventory
CREATE VIEW avg_inventory_view AS
SELECT
    product_id,
    AVG(stock_quantity) AS avg_inventory
FROM inventory_history
GROUP BY product_id;


-- inventory turnover(how efficiently inventory sold or replaced = unit_sold/avg inventory)
SELECT
    spv.product_name,
    ROUND(SUM(spv.quantity_sold) / ai.avg_inventory, 2) AS inventory_turnover
FROM sales_product_view spv
JOIN avg_inventory_view ai
    ON spv.product_id = ai.product_id
GROUP BY spv.product_name, ai.avg_inventory;


-- Reorder point(iventory level at which new stock must be orderd)
 
-- ROP = sale velocity*lead time + safety stock(lead time = day supplier take )
 
ALTER TABLE products add column lead_time_days int default 5,
add column safety_stock int default 10;

CREATE VIEW dynamic_rop_view AS
SELECT
    p.product_id,
    p.product_name,
    sv.sales_velocity,
    p.lead_time_days,
    p.safety_stock,
    CEIL(
        (sv.sales_velocity * p.lead_time_days)
        + p.safety_stock
    ) AS dynamic_reorder_point
FROM products p
JOIN sales_velocity sv
    ON p.product_name = sv.product_name;

CREATE VIEW latest_inventory_view AS
SELECT
    ih.product_id,
    ih.stock_quantity
FROM inventory_history ih
WHERE ih.inventory_date = (
    SELECT MAX(inventory_date)
    FROM inventory_history
);

SELECT
    p.product_name,
    li.stock_quantity AS current_stock,
    dr.dynamic_reorder_point,
    CASE
        WHEN li.stock_quantity <= dr.dynamic_reorder_point THEN 'REORDER'
        ELSE 'OK'
    END AS reorder_status
FROM products p
JOIN latest_inventory_view li
    ON p.product_id = li.product_id
JOIN dynamic_rop_view dr
    ON p.product_id = dr.product_id;
    
