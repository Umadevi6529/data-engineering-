"""
main.py — Star Schema DW & SCD Type 2 Pipeline Runner
=====================================================
Demonstrates:
1. Creating a Kimball Star Schema (Fact + Dimension Tables)
2. Generating a Date Dimension Spine (dim_date)
3. Loading & Updating SCD Type 2 Customer History (scd_loader.py)
4. Point-in-Time Historical Reporting vs Current State Reporting

Run:
    python main.py
"""

import sqlite3
import sys
from datetime import datetime, timedelta
from scd_loader import SCD2Loader

# Force UTF-8 encoding on Windows terminals
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")


def create_sqlite_dw_schema(conn: sqlite3.Connection):
    """Creates the SQLite Star Schema DDL."""
    cursor = conn.cursor()

    cursor.executescript(
        """
        DROP TABLE IF EXISTS fact_sales;
        DROP TABLE IF EXISTS dim_customers_scd2;
        DROP TABLE IF EXISTS dim_products;
        DROP TABLE IF EXISTS dim_date;

        CREATE TABLE dim_date (
            date_key        INTEGER PRIMARY KEY,
            full_date       TEXT NOT NULL,
            year            INTEGER NOT NULL,
            quarter         INTEGER NOT NULL,
            month           INTEGER NOT NULL,
            month_name      TEXT NOT NULL,
            day_of_month    INTEGER NOT NULL,
            day_name        TEXT NOT NULL,
            is_weekend      INTEGER NOT NULL
        );

        CREATE TABLE dim_customers_scd2 (
            customer_sk     INTEGER PRIMARY KEY AUTOINCREMENT,
            customer_id     TEXT NOT NULL,
            first_name      TEXT NOT NULL,
            last_name       TEXT NOT NULL,
            email           TEXT NOT NULL,
            city            TEXT NOT NULL,
            region          TEXT NOT NULL,
            tier            TEXT NOT NULL,
            effective_date  TEXT NOT NULL,
            end_date        TEXT NOT NULL DEFAULT '9999-12-31',
            is_current      INTEGER NOT NULL DEFAULT 1
        );

        CREATE TABLE dim_products (
            product_sk      INTEGER PRIMARY KEY AUTOINCREMENT,
            product_id      TEXT NOT NULL,
            product_name    TEXT NOT NULL,
            category        TEXT NOT NULL,
            current_price   REAL NOT NULL
        );

        CREATE TABLE fact_sales (
            sales_fact_id   INTEGER PRIMARY KEY AUTOINCREMENT,
            order_id        TEXT NOT NULL,
            date_key        INTEGER NOT NULL,
            customer_sk     INTEGER NOT NULL,
            product_sk      INTEGER NOT NULL,
            quantity        INTEGER NOT NULL,
            unit_price      REAL NOT NULL,
            gross_amount    REAL NOT NULL,
            discount_amount REAL DEFAULT 0.0,
            net_revenue     REAL NOT NULL,
            FOREIGN KEY (date_key) REFERENCES dim_date(date_key),
            FOREIGN KEY (customer_sk) REFERENCES dim_customers_scd2(customer_sk),
            FOREIGN KEY (product_sk) REFERENCES dim_products(product_sk)
        );
        """
    )
    conn.commit()


def populate_date_dimension(conn: sqlite3.Connection, start_date_str: str, days_count: int):
    """Populates dim_date table for a date range."""
    cursor = conn.cursor()
    start_dt = datetime.strptime(start_date_str, "%Y-%m-%d")

    date_rows = []
    for i in range(days_count):
        dt = start_dt + timedelta(days=i)
        date_key = int(dt.strftime("%Y%m%d"))
        full_date = dt.strftime("%Y-%m-%d")
        year = dt.year
        quarter = (dt.month - 1) // 3 + 1
        month = dt.month
        month_name = dt.strftime("%B")
        day_of_month = dt.day
        day_name = dt.strftime("%A")
        is_weekend = 1 if dt.weekday() in (5, 6) else 0

        date_rows.append(
            (date_key, full_date, year, quarter, month, month_name, day_of_month, day_name, is_weekend)
        )

    cursor.executemany(
        """
        INSERT INTO dim_date (
            date_key, full_date, year, quarter, month, month_name, day_of_month, day_name, is_weekend
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)
        """,
        date_rows,
    )
    conn.commit()


def populate_products(conn: sqlite3.Connection):
    """Populates dim_products."""
    cursor = conn.cursor()
    products = [
        ("PROD_1001", "Laptop Pro 15", "Electronics", 75000.00),
        ("PROD_1002", "Wireless Mouse", "Electronics", 450.00),
        ("PROD_1003", "Mechanical Keyboard", "Electronics", 4200.00),
        ("PROD_1004", "Ergonomic Chair", "Furniture", 15000.00),
    ]
    cursor.executemany(
        "INSERT INTO dim_products (product_id, product_name, category, current_price) VALUES (?, ?, ?, ?)",
        products,
    )
    conn.commit()


def main():
    print("=" * 70)
    print("  🏗️ PHASE 4: DATA WAREHOUSING & SCD TYPE 2 ENGINE")
    print("=" * 70)

    # 1. Initialize In-Memory DW SQLite Connection
    conn = sqlite3.connect(":memory:")
    print("\n[STEP 1] Creating Star Schema Data Warehouse Tables...")
    create_sqlite_dw_schema(conn)

    # 2. Populate Conformed Date Dimension & Product Dimension
    print("  📅 Populating Date Dimension (dim_date) for year 2024...")
    populate_date_dimension(conn, "2024-01-01", 366)

    print("  📦 Populating Product Dimension (dim_products)...")
    populate_products(conn)

    # 3. Load Customer Data (SCD2 Initial Insert)
    print("\n[STEP 2] Loading Initial Customers into dim_customers_scd2...")
    scd_engine = SCD2Loader(conn)

    cust1 = {
        "customer_id": "CUST_001",
        "first_name": "Priya",
        "last_name": "Sharma",
        "email": "priya.sharma@gmail.com",
        "city": "Mumbai",
        "region": "West",
        "tier": "standard",
    }
    cust2 = {
        "customer_id": "CUST_002",
        "first_name": "Rahul",
        "last_name": "Verma",
        "email": "rahul.verma@gmail.com",
        "city": "Delhi",
        "region": "North",
        "tier": "standard",
    }

    res1 = scd_engine.process_customer_update(cust1, change_date="2024-01-01")
    res2 = scd_engine.process_customer_update(cust2, change_date="2024-01-01")
    print(f"  ✅ Initial Load Results: CUST_001 -> {res1}, CUST_002 -> {res2}")

    # 4. Insert Sales Facts for Q1 2024 (Jan & Feb)
    print("\n[STEP 3] Recording Q1 Sales Transactions into fact_sales...")
    cursor = conn.cursor()

    # Jan 15, 2024: Priya (in Mumbai) buys Laptop + Mouse
    priya_sk_jan = scd_engine.get_surrogate_key_for_date("CUST_001", "2024-01-15")
    cursor.execute(
        """
        INSERT INTO fact_sales (
            order_id, date_key, customer_sk, product_sk, quantity, unit_price, gross_amount, discount_amount, net_revenue
        ) VALUES ('ORD_101', 20240115, ?, 1, 1, 75000.0, 75000.0, 5000.0, 70000.0)
        """,
        (priya_sk_jan,),
    )
    cursor.execute(
        """
        INSERT INTO fact_sales (
            order_id, date_key, customer_sk, product_sk, quantity, unit_price, gross_amount, discount_amount, net_revenue
        ) VALUES ('ORD_101', 20240115, ?, 2, 2, 450.0, 900.0, 0.0, 900.0)
        """,
        (priya_sk_jan,),
    )
    conn.commit()
    print("  ✅ Q1 Sales recorded successfully.")

    # 5. Simulate SCD Type 2 Customer Update (June 1, 2024)
    print("\n[STEP 4] Simulating Customer Profile Update (SCD Type 2 Event)...")
    print("  UPDATE EVENT: Priya Sharma (CUST_001) moved from Mumbai (West) -> Delhi (North) & upgraded to 'VIP' tier!")

    cust1_updated = cust1.copy()
    cust1_updated["city"] = "Delhi"
    cust1_updated["region"] = "North"
    cust1_updated["tier"] = "VIP"

    res_scd = scd_engine.process_customer_update(cust1_updated, change_date="2024-06-01")
    print(f"  ✅ SCD Engine Result: CUST_001 -> {res_scd}")

    # Inspect dim_customers_scd2 history table
    print("\n  Customer History Dimension Table (dim_customers_scd2):")
    print("  " + "-" * 85)
    cursor.execute("SELECT customer_sk, customer_id, city, region, tier, effective_date, end_date, is_current FROM dim_customers_scd2")
    for r in cursor.fetchall():
        print(f"  SK={r[0]} | ID={r[1]} | City={r[2]:<8} | Region={r[3]:<5} | Tier={r[4]:<8} | Eff={r[5]} | End={r[6]} | Current={r[7]}")
    print("  " + "-" * 85)

    # 6. Insert Sales Facts for Q3 2024 (July 15, 2024)
    print("\n[STEP 5] Recording Q3 Sales Transaction (Post-Update)...")
    priya_sk_july = scd_engine.get_surrogate_key_for_date("CUST_001", "2024-07-15")
    cursor.execute(
        """
        INSERT INTO fact_sales (
            order_id, date_key, customer_sk, product_sk, quantity, unit_price, gross_amount, discount_amount, net_revenue
        ) VALUES ('ORD_205', 20240715, ?, 4, 1, 15000.0, 15000.0, 1500.0, 13500.0)
        """,
        (priya_sk_july,),
    )
    conn.commit()

    # 7. Execute Point-in-Time Historical Analytics Queries
    print("\n[STEP 6] Executing Point-in-Time Data Warehouse Queries:")

    print("\n  QUERY A: Sales Revenue by Region (Historical Attribution):")
    cursor.execute(
        """
        SELECT
            c.region,
            COUNT(DISTINCT f.order_id) AS order_count,
            SUM(f.net_revenue) AS total_revenue
        FROM fact_sales f
        JOIN dim_customers_scd2 c ON f.customer_sk = c.customer_sk
        GROUP BY c.region
        """
    )
    print("  ------------------------------------------------")
    print("  Region | Orders | Historical Revenue")
    print("  ------------------------------------------------")
    for r in cursor.fetchall():
        print(f"  {r[0]:<6} | {r[1]:<6} | ₹{r[2]:,.2f}")
    print("  ------------------------------------------------")
    print("  💡 INSIGHT: Jan 2024 revenue correctly attributed to 'West' (Mumbai), while July revenue correctly attributed to 'North' (Delhi)!")

    print("\n[DONE] Data Warehousing & SCD Type 2 Pipeline Run Complete! 🎉")


if __name__ == "__main__":
    main()
