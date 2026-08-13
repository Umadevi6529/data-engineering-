# Phase 2: SQL Deep Dive 📊

## 🎯 Goal
Master the SQL skills that Data Engineers use every single day — joins, window
functions, CTEs, query optimization, indexes, and views.

---

## 🧠 Why SQL is the Most Important Skill in DE

Every tool in the DE stack speaks SQL:

```
dbt          → You write SQL, it compiles and runs it
BigQuery     → Google's warehouse — pure SQL
Redshift     → Amazon's warehouse — SQL
Snowflake    → Cloud warehouse — SQL
Spark SQL    → Big data — SQL syntax on distributed data
Apache Hive  → Data lake queries — SQL
```

If you know SQL deeply, you can work with any of these tools.
The syntax is 90% the same. The concepts are identical.

---

## 🗄️ The Database We Built — E-Commerce Analytics

### Why E-Commerce?
It's the most common real-world DE scenario. Every concept maps to business:

```
customers    → Who is buying?
products     → What are they buying?
categories   → How do we group products?
orders       → When did they buy? How much?
order_items  → What specific items were in each order?
```

### Schema Diagram (Entity Relationship Diagram)

```
categories
    | id, name, description
    |
    +---> products
             | id, name, price, category_id, stock_qty
             |
             +---> order_items
                      | id, order_id, product_id, quantity, unit_price
                      |
customers              |
    | id, name,        |
    | email,           |
    | city, region,    |
    | signup_date      |
    |                  |
    +---> orders ------+
             id, customer_id, order_date,
             status, total_amount, payment_method
```

### What each relationship means:
- One **customer** can have many **orders**  (1-to-many)
- One **order** can have many **order_items** (1-to-many)
- One **product** can appear in many **order_items** (1-to-many)
- One **category** can have many **products** (1-to-many)

This structure is called a **Star Schema**.
`orders` and `order_items` are your **Fact Tables** (events that happened).
`customers`, `products`, `categories` are your **Dimension Tables** (who/what/where).
You will learn this deeply in Phase 4 (Data Warehousing).

---

## 📚 SQL Concepts Covered

### 1. JOINs
```
INNER JOIN  → Only rows matching in BOTH tables
LEFT JOIN   → All left rows + matching right (NULL if no match)
RIGHT JOIN  → All right rows + matching left
SELF JOIN   → Table joined to itself
ANTI JOIN   → Rows from left with NO match in right
```

### 2. Window Functions
```
ROW_NUMBER()   → 1,2,3,4,5 within a partition
RANK()         → 1,1,3 (gaps when tied)
DENSE_RANK()   → 1,1,2 (no gaps when tied)
LAG()          → Previous row's value
LEAD()         → Next row's value
SUM() OVER()   → Running total
AVG() OVER()   → Moving average
NTILE(n)       → Split rows into n equal buckets
```

### 3. CTEs
Break long complex queries into named readable steps.

### 4. Query Optimization
EXPLAIN ANALYZE, Indexes, avoiding N+1 problems.

---

## How to Run

```bash
# Windows - run from this folder:
set PGPASSWORD=postgres123
psql -U postgres -d ecommerce -f projects/ecommerce_analytics/01_schema.sql
psql -U postgres -d ecommerce -f projects/ecommerce_analytics/02_seed_data.sql
psql -U postgres -d ecommerce -f projects/ecommerce_analytics/03_joins.sql
psql -U postgres -d ecommerce -f projects/ecommerce_analytics/04_window_functions.sql
psql -U postgres -d ecommerce -f projects/ecommerce_analytics/05_ctes.sql
psql -U postgres -d ecommerce -f projects/ecommerce_analytics/06_optimization.sql
psql -U postgres -d ecommerce -f projects/ecommerce_analytics/07_views.sql
```
