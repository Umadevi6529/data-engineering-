# Phase 4: Data Warehousing & Dimensional Modeling 🏗️

## 🎯 Goal
Master Data Warehousing architecture and dimensional modeling fundamentals — Kimball vs. Inmon methodologies, Star Schema vs. Snowflake Schema, Fact & Dimension table design, and Slowly Changing Dimensions (SCD Types 1, 2, and 3).

---

## 🧠 Why Data Warehousing Matters for Data Engineers

An OLTP database (like our PostgreSQL database in Phase 2) is designed for **fast single-row transactions** (e.g., placing an order, updating a profile). 

However, running analytical queries (e.g., *"Show 5-year sales trends across 50 million customers"*) on an OLTP database will lock tables and crash production applications.

Data Engineers build **Data Warehouses** optimized for **OLAP (Online Analytical Processing)**. We extract data from OLTP databases, transform it into **Dimensional Models**, and load it into analytical warehouses like **Snowflake**, **Amazon Redshift**, or **Google BigQuery**.

---

## 🏛️ 1. OLTP vs. OLAP Architecture

```
                                  DATA WAREHOUSE ARCHITECTURE
                                  
  ┌─────────────────┐                                                 ┌──────────────────┐
  │  OLTP SOURCES   │                                                 │   OLAP WAREHOUSE │
  ├─────────────────┤                                                 ├──────────────────┤
  │ PostgreSQL      │ ───[ ETL / ELT Pipeline ]───▶                   │ Star Schema      │
  │ MongoDB (NoSQL) │   (Extract - Transform - Load)                  │ (Fact & Dim)     │
  │ APIs & Logs     │                                                 │ Redshift/BigQuery│
  └─────────────────┘                                                 └──────────────────┘
   • 3rd Normal Form (3NF)                                             • De-normalized
   • High Write Throughput                                             • Columnar Storage
   • Row-oriented                                                      • Fast Aggregations
```

| Feature | OLTP (Transactional DB) | OLAP (Data Warehouse) |
| :--- | :--- | :--- |
| **Primary Purpose** | Operational applications (orders, payments) | Analytics, BI reporting, Data Science |
| **Data Structure** | Highly Normalized (3NF) to prevent redundancy | De-normalized Dimensional Models (Star Schema) |
| **Read vs. Write** | Balanced Reads & Writes (Single-row operations) | **Read-Heavy** (Scanning millions of rows) |
| **Storage Layout** | Row-oriented | Columnar-oriented |
| **Historical Data** | Current state only (frequently updated) | Years of historical snapshots (Append-only) |

---

## 📐 2. Kimball's 4-Step Dimensional Design Process

Enterprise Data Warehouse architect **Ralph Kimball** defined 4 steps to design any dimensional model:

1. **Select the Business Process**: Identify the business event (e.g., Sales Orders, Monthly Subscriptions, Support Tickets).
2. **Declare the Grain**: Define what one row in the fact table represents (e.g., *"One row per line item in a completed sales order"*).
3. **Identify the Dimensions**: Determine the context (*Who, What, Where, When, Why, How*) surrounding the event.
4. **Identify the Facts**: Numeric measures that can be aggregated (e.g., `quantity`, `unit_price`, `discount_amount`, `net_revenue`).

---

## 🌟 3. Star Schema vs. Snowflake Schema

```
        STAR SCHEMA                                  SNOWFLAKE SCHEMA

        ┌──────────┐                                   ┌──────────┐
        │ Dim_Date │                                   │ Dim_Date │
        └────┬─────┘                                   └────┬─────┘
             │                                              │
┌──────────┐ │ ┌──────────────┐                ┌──────────┐ │ ┌──────────────┐
│Dim_Custom│─┼─│  FACT_SALES  │                │Dim_Custom│─┼─│  FACT_SALES  │
└──────────┘ │ └──────┬───────┘                └────┬─────┘ │ └──────┬───────┘
             │        │                             │       │        │
        ┌────┴─────┐  │                        ┌────┴─────┐ │   ┌────┴─────┐
        │Dim_Produc│──┘                        │Dim_Produc│─┘   │Dim_Produc│
        └──────────┘                           └────┬─────┘     └────┬─────┘
                                                    │                │
                                               ┌────┴─────┐     ┌────┴─────┐
                                               │Dim_Catego│     │Dim_SubCat│
                                               └──────────┘     └──────────┘
```

### Star Schema (Recommended for Data Warehouses)
- **Structure**: Center Fact table surrounded by flat, de-normalized Dimension tables.
- **Pros**: Simple SQL queries; fewer JOINs; optimized for columnar execution engines.
- **Cons**: Minor data redundancy in dimension tables (negligible in modern DWs).

### Snowflake Schema
- **Structure**: Dimension tables are normalized into sub-dimensions (e.g., `Dim_Product` -> `Dim_SubCategory` -> `Dim_Category`).
- **Pros**: Eliminates data redundancy in dimension tables.
- **Cons**: Requires complex multi-table JOINs; slower analytical query performance.

---

## ⏱️ 4. Slowly Changing Dimensions (SCD)

Dimension data changes over time (e.g., a customer moves to a new city or updates their membership tier). How we handle changes defines the **SCD Type**:

### 🔹 SCD Type 0: Retain Original
- The attribute never changes (e.g., `original_signup_date`).

### 🔹 SCD Type 1: Overwrite (No History)
- Overwrites old value with the new value. Past history is lost.
- **Use Case**: Correcting typos in names or emails.

### 🔹 SCD Type 2: Add New Row (Full History - Most Important in DE!)
- Inserts a new row with a new **Surrogate Key**. Sets `effective_date`, `end_date`, and `is_current` flags.
- **Use Case**: Tracking customer address or tier changes to preserve historical reporting accuracy.

```sql
-- Example SCD Type 2 Table Structure:
customer_sk | customer_id | name        | city   | effective_date | end_date   | is_current
------------+-------------+-------------+--------+----------------+------------+-----------
101         | CUST_1      | Priya Sharma| Mumbai | 2023-01-15     | 2024-06-01 | FALSE
205         | CUST_1      | Priya Sharma| Delhi  | 2024-06-01     | 9999-12-31 | TRUE
```

### 🔹 SCD Type 3: Add New Column (Current & Previous Only)
- Adds a `previous_city` column to store the prior value alongside the current value.
- **Use Case**: When only the immediate previous state is needed.

---

## 🛠️ Project: Star Schema DW & SCD Type 2 Pipeline

In `projects/star_schema_dw/`:
1. **`01_dw_schema.sql`**: PostgreSQL DDL script creating a Star Schema Data Warehouse (`dim_customers_scd2`, `dim_products`, `dim_date`, `fact_sales`).
2. **`scd_loader.py`**: Python engine implementing SCD Type 2 updates and SCD Type 1 corrections.
3. **`main.py`**: Runs an end-to-end DW load and executes historical vs. current state analytical queries.

---

## 📁 File Structure

```
phase-04-data-warehousing/
├── README.md                              ← This overview
├── notes/
│   └── dimensional_modeling_and_scd.md   ← Deep dive notes on Kimball, Grain, & SCD Types
├── projects/
│   └── star_schema_dw/
│       ├── 01_dw_schema.sql               ← Star Schema DDL with Surrogate Keys & SCD2
│       ├── scd_loader.py                  ← Python engine for SCD Type 1 & 2 loading
│       └── main.py                        ← DW pipeline runner & analytical queries
└── quiz/
    └── phase04_quiz.md                    ← Test your understanding
```

---

## 🏃 Running the Project

```bash
cd phase-04-data-warehousing/projects/star_schema_dw
python main.py
```
