-- ============================================================
-- Inventory Analytics & Optimization — Schema
-- Defines all tables. Run this first, then data/seed_data.sql,
-- then sql/queries.sql.
-- ============================================================

CREATE DATABASE inventory_db;
USE inventory_db;

CREATE TABLE products (
    product_id      INT PRIMARY KEY,
    product_name    VARCHAR(100),
    category        VARCHAR(50)
);

CREATE TABLE suppliers (
    supplier_id     INT PRIMARY KEY,
    supplier_name   VARCHAR(100),
    lead_time_days  INT
);

CREATE TABLE product_supplier (
    product_id      INT,
    supplier_id     INT,
    PRIMARY KEY (product_id, supplier_id),
    FOREIGN KEY (product_id)  REFERENCES products(product_id),
    FOREIGN KEY (supplier_id) REFERENCES suppliers(supplier_id)
);

CREATE TABLE inventory (
    product_id      INT PRIMARY KEY,
    stock_quantity  INT,
    last_updated    DATE,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);

CREATE TABLE sales (
    sale_id         INT PRIMARY KEY,
    product_id      INT,
    sale_date       DATE,
    quantity_sold   INT,
    FOREIGN KEY (product_id) REFERENCES products(product_id)
);
