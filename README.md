# Inventory-Analytics-Optimization-Using-MySQL

Project Objective : The objective of this project is to analyze inventory performance and optimize replenishment decisions using MySQL.
The project focuses on transforming raw sales and inventory data into actionable business metrics such as:

🔹 Sales Velocity

Measures how fast a product sells over time.
Sales Velocity = Total Units Sold ÷ Number of Days.

High velocity → fast-moving product
Low velocity → slow-moving or overstocked item


🔹 Inventory Turnover Efficiency

Measures how efficiently inventory is sold and replenished.
Inventory Turnover = Total Units Sold ÷ Average Inventory

High turnover → efficient inventory usage
Low turnover → excess or dead stock

🔹 Reorder Point (ROP)

The inventory level at which a new order should be placed.
Reorder Point = Sales Velocity × Supplier Lead Time
(Lead Time:days supplier take to deliver )

          OR

  ROP = Sales Velocity × Supplier Lead Time + Safety Stock

Ensures inventory does not run out during supplier delivery time.

if ROP is low :stockout ,lost sales .
        is high  : overstock , storage cost .

🔹 Inventory Status Logic

Convert numeric stock data into actionable decisions
 
 (OK / Low Stock / Reorder / Out of Stock)


This project simulates a real-world supply chain analytics use case.

🧩 Business Problem

Businesses often face:

Stockouts due to late replenishment

Excess inventory increasing holding costs

Lack of data-driven reorder decisions

This project solves these problems by:

Estimating demand using historical sales

Considering supplier lead time

Automatically flagging inventory risks


🗂️ Database Tables Used
1️⃣ sales

Stores historical product sales.
Used to calculate sales velocity and demand trends.

2️⃣ inventory

Stores current stock levels.
Used to determine inventory health and availability.

3️⃣ suppliers

Stores supplier-related details.
Provides lead time, which is critical for reorder planning.


📌 Project Assumptions

Sales data represents consistent time intervals

Supplier lead time is constant per product

Safety stock is not included (can be extended)

Inventory quantity reflects real-time stock
