"""
generate_data.py
-----------------
Generates the sample dataset used in this project (products, suppliers,
inventory, and sales) and writes it to data/seed_data.sql.

  - Demand varies by category (Electronics moves faster than Home
    Appliances, matching real-world velocity differences).
  - Weekend demand is higher than weekday demand for consumer categories.
  - A handful of products are deliberately made slow-movers (to produce
    genuine Overstock cases) and a handful fast-movers (to produce
    genuine Understock cases) — so the resulting dashboard actually has
    a distribution to talk about, not just uniform noise.
  - Stock levels are set relative to each product's own demand profile,
    not drawn independently, so turnover ratios and reorder points come
    out in a believable range.
"""

import random
from datetime import date, timedelta

random.seed(42)  # reproducible output

# ----------------------------------------------------------------
# Reference data
# ----------------------------------------------------------------
CATEGORIES = {
    "Electronics": {
        "products": ["Laptop", "Mobile", "Tablet", "Smartwatch", "Monitor",
                     "Router", "Webcam", "Power Bank", "Bluetooth Speaker", "SSD Drive"],
        "base_demand": (3, 9),      # units/day range before modifiers
        "weekend_boost": 1.4,
    },
    "Accessories": {
        "products": ["Headphones", "Keyboard", "Mouse", "Laptop Stand", "USB Hub",
                     "Phone Case", "Charging Cable", "Screen Protector", "Mouse Pad", "Cooling Fan"],
        "base_demand": (2, 6),
        "weekend_boost": 1.2,
    },
    "Home Appliances": {
        "products": ["Mixer Grinder", "Electric Kettle", "Toaster", "Iron", "Vacuum Cleaner",
                     "Air Fryer", "Induction Cooktop", "Water Purifier", "Ceiling Fan", "Room Heater"],
        "base_demand": (1, 4),
        "weekend_boost": 1.1,
    },
}

SUPPLIERS = [
    (1, "ABC Electronics", 7),
    (2, "XYZ Distributors", 14),
    (3, "Prime Supply Co", 5),
    (4, "Global Traders", 10),
    (5, "Metro Wholesalers", 12),
    (6, "Nova Logistics", 8),
]

START_DATE = date(2024, 3, 1)
END_DATE = date(2024, 3, 31)


def build_products():
    products = []
    pid = 1
    for category, cfg in CATEGORIES.items():
        for name in cfg["products"]:
            products.append({
                "product_id": pid,
                "product_name": name,
                "category": category,
                "base_demand": random.uniform(*cfg["base_demand"]),
                "weekend_boost": cfg["weekend_boost"],
            })
            pid += 1
    return products


def assign_movement_profile(products):
    """
    Tag ~15% of products as deliberately slow-moving and ~15% as
    deliberately fast-moving, so the final dataset has a real spread
    of Understock/Optimal/Overstock instead of everything landing
    in the middle.
    """
    shuffled = products[:]
    random.shuffle(shuffled)
    n = len(shuffled)
    slow_cut = max(1, n // 7)
    fast_cut = max(1, n // 7)

    for p in shuffled[:slow_cut]:
        p["movement"] = "slow"
        p["base_demand"] *= 0.35
    for p in shuffled[slow_cut:slow_cut + fast_cut]:
        p["movement"] = "fast"
        p["base_demand"] *= 2.2
    for p in shuffled[slow_cut + fast_cut:]:
        p["movement"] = "normal"

    return products


def generate_sales(products):
    sales = []
    sale_id = 1
    day_count = (END_DATE - START_DATE).days + 1

    for p in products:
        for offset in range(day_count):
            current_date = START_DATE + timedelta(days=offset)
            is_weekend = current_date.weekday() >= 5

            expected = p["base_demand"] * (p["weekend_boost"] if is_weekend else 1.0)
            # Not every product sells every day — probability scales with demand
            sell_chance = min(0.95, 0.25 + expected / 12)
            if random.random() > sell_chance:
                continue

            qty = max(1, round(random.gauss(expected, expected * 0.35)))
            sales.append({
                "sale_id": sale_id,
                "product_id": p["product_id"],
                "sale_date": current_date,
                "quantity_sold": qty,
            })
            sale_id += 1

    return sales


def compute_stock_levels(products, sales, product_supplier, suppliers):
    """
    Set each product's current stock relative to its own reorder point
    (avg daily demand x its supplier's lead time), not an arbitrary
    multiplier — this is what the reorder_analysis / inventory_status
    views actually compare stock against, so the resulting Understock /
    Optimal / Overstock split reflects the same math the SQL will run,
    just previewed here in Python before loading it.

      slow movers  -> stock set to ~2.5-4x their reorder point (Overstock)
      fast movers  -> stock set to ~0.4-0.7x their reorder point (Understock)
      normal       -> stock set to ~0.9-1.4x their reorder point (mostly Optimal,
                       since Optimal is defined as reorder_point <= stock <= 1.5x it)
    """
    lead_time_by_supplier = {sid: lead for sid, name, lead in suppliers}
    lead_time_by_product = {
        pid: lead_time_by_supplier[sid] for pid, sid in product_supplier
    }

    demand_by_product = {}
    for s in sales:
        demand_by_product.setdefault(s["product_id"], []).append(s["quantity_sold"])
    sale_days_by_product = {}
    for s in sales:
        sale_days_by_product.setdefault(s["product_id"], set()).add(s["sale_date"])

    inventory = []
    for p in products:
        pid = p["product_id"]
        qtys = demand_by_product.get(pid, [1])
        days = max(1, len(sale_days_by_product.get(pid, {1})))
        avg_daily = sum(qtys) / days  # matches SQL: SUM(qty) / COUNT(DISTINCT sale_date)

        lead_time = lead_time_by_product[pid]
        reorder_point = avg_daily * lead_time

        if p["movement"] == "slow":
            stock = reorder_point * random.uniform(2.5, 4.0)
        elif p["movement"] == "fast":
            stock = reorder_point * random.uniform(0.4, 0.7)
        else:
            stock = reorder_point * random.uniform(0.9, 1.4)

        inventory.append({
            "product_id": pid,
            "stock_quantity": max(3, round(stock)),
            "last_updated": date(2024, 4, 1),
        })
    return inventory


def build_product_supplier(products):
    mapping = []
    for p in products:
        supplier_id = random.randint(1, len(SUPPLIERS))
        mapping.append((p["product_id"], supplier_id))
    return mapping


def esc(s):
    return s.replace("'", "''")


def write_sql(products, suppliers, product_supplier, inventory, sales, path):
    lines = [
        "-- ============================================================",
        "-- Seed data for inventory_db",
        "-- Synthetically generated by scripts/generate_data.py",
        "-- (see that file for the generation logic and disclosure notes)",
        "-- ============================================================",
        "",
        "USE inventory_db;",
        "",
        "INSERT INTO products (product_id, product_name, category) VALUES",
    ]
    lines.append(",\n".join(
        f"({p['product_id']},'{esc(p['product_name'])}','{esc(p['category'])}')" for p in products
    ) + ";")
    lines.append("")

    lines.append("INSERT INTO suppliers (supplier_id, supplier_name, lead_time_days) VALUES")
    lines.append(",\n".join(
        f"({sid},'{esc(name)}',{lead})" for sid, name, lead in suppliers
    ) + ";")
    lines.append("")

    lines.append("INSERT INTO product_supplier (product_id, supplier_id) VALUES")
    lines.append(",\n".join(f"({pid},{sid})" for pid, sid in product_supplier) + ";")
    lines.append("")

    lines.append("INSERT INTO inventory (product_id, stock_quantity, last_updated) VALUES")
    lines.append(",\n".join(
        f"({i['product_id']},{i['stock_quantity']},'{i['last_updated'].isoformat()}')" for i in inventory
    ) + ";")
    lines.append("")

    lines.append("INSERT INTO sales (sale_id, product_id, sale_date, quantity_sold) VALUES")
    lines.append(",\n".join(
        f"({s['sale_id']},{s['product_id']},'{s['sale_date'].isoformat()}',{s['quantity_sold']})" for s in sales
    ) + ";")
    lines.append("")

    with open(path, "w") as f:
        f.write("\n".join(lines))


def main():
    products = build_products()
    products = assign_movement_profile(products)
    sales = generate_sales(products)
    product_supplier = build_product_supplier(products)
    inventory = compute_stock_levels(products, sales, product_supplier, SUPPLIERS)

    write_sql(products, SUPPLIERS, product_supplier, inventory, sales, "../data/seed_data.sql")

    print(f"Products:   {len(products)}")
    print(f"Suppliers:  {len(SUPPLIERS)}")
    print(f"Sales rows: {len(sales)}")
    print("Movement profile counts:",
          {m: sum(1 for p in products if p["movement"] == m) for m in ("slow", "normal", "fast")})


if __name__ == "__main__":
    main()
