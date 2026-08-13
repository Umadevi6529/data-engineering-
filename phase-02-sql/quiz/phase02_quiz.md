# Phase 2 Quiz: SQL Deep Dive 🧠

Test yourself — answer BEFORE looking at the answers.
Then open pgAdmin or psql and actually RUN the queries.

---

## Part A: Conceptual Questions

**Q1.** What is the difference between `WHERE` and `HAVING`?
When would you use each?

<details>
<summary>Answer</summary>

- `WHERE` filters rows **BEFORE** grouping. It cannot reference aggregate functions.
- `HAVING` filters **AFTER** grouping. It CAN reference aggregates (SUM, COUNT, etc.)

```sql
-- WHERE: filter individual rows before aggregation
SELECT region, SUM(total_amount)
FROM orders
WHERE status = 'delivered'       -- filter ROWS
GROUP BY region;

-- HAVING: filter groups after aggregation
SELECT region, SUM(total_amount) AS revenue
FROM orders
GROUP BY region
HAVING SUM(total_amount) > 50000;  -- filter GROUPS
```

SQL execution order: FROM → WHERE → GROUP BY → HAVING → SELECT → ORDER BY
</details>

---

**Q2.** What is the difference between `RANK()` and `DENSE_RANK()`?
Give an example with numbers.

<details>
<summary>Answer</summary>

Both handle ties differently:

| Score | RANK() | DENSE_RANK() |
|-------|--------|--------------|
| 100   | 1      | 1            |
| 100   | 1      | 1            |
| 90    | 3      | 2  ← no gap! |
| 80    | 4      | 3            |

- `RANK()` leaves a gap after ties (positions 1,1,3 — no position 2)
- `DENSE_RANK()` has no gaps (positions 1,1,2)

Use `DENSE_RANK()` for "top N per category" queries in DE.
</details>

---

**Q3.** Why should you NEVER use `FLOAT` to store money?
What should you use instead?

<details>
<summary>Answer</summary>

`FLOAT` uses binary floating-point arithmetic which cannot represent decimal
fractions exactly.

```python
# Python shows the same problem:
0.1 + 0.2  # → 0.30000000000000004 (NOT 0.3!)
```

In a financial system, this causes rounding errors that compound over millions
of transactions.

**Use `DECIMAL(10,2)` or `NUMERIC(10,2)`** — these are exact decimal types.
- 10 = total digits
- 2 = digits after decimal point
- Stores: 12345678.99 exactly

In DE, financial columns are always `DECIMAL`/`NUMERIC`. This is non-negotiable.
</details>

---

**Q4.** Explain `COALESCE()`. Why is it used so heavily in DE?

<details>
<summary>Answer</summary>

`COALESCE(value1, value2, value3, ...)` returns the **first non-NULL argument**.

```sql
COALESCE(NULL, NULL, 42, 100)  → 42
COALESCE(NULL, 'default')      → 'default'
COALESCE('hello', 'default')   → 'hello'
```

In DE, nulls appear everywhere:
- Customers with no orders → SUM of orders = NULL
- Missing data in source systems
- LEFT JOIN non-matching rows

Without COALESCE, NULLs propagate and break calculations:
- NULL + 100 = NULL (not 100!)
- AVG ignores NULLs (can skew results)
- NULL in a dashboard cell looks broken to stakeholders

```sql
-- Common DE pattern:
COALESCE(SUM(o.total_amount), 0)  -- "if no orders, show 0, not NULL"
```
</details>

---

**Q5.** What is the difference between a View and a Materialized View?
When would you use each?

<details>
<summary>Answer</summary>

| Feature | View | Materialized View |
|---------|------|-------------------|
| Data stored? | No — query runs each time | Yes — stored on disk |
| Always fresh? | Yes | No — must REFRESH |
| Query speed | Depends on underlying query | Always fast (pre-computed) |
| Use when | Data changes often, query runs rarely | Query runs very often (dashboards) |

```sql
-- View: runs the join EVERY time you query it
CREATE VIEW vw_sales AS SELECT ... FROM orders JOIN customers ...;

-- Materialized View: computes ONCE, stores result
CREATE MATERIALIZED VIEW mv_monthly_sales AS SELECT ... GROUP BY month;
REFRESH MATERIALIZED VIEW mv_monthly_sales;  -- run this when data updates
```

In production, Airflow schedules the REFRESH after each ETL pipeline completes.
</details>

---

## Part B: Coding Challenges

**C1.** Write a query to find the **top 3 customers by total spending per region**.
(Hint: use DENSE_RANK() with PARTITION BY region)

<details>
<summary>Answer</summary>

```sql
WITH ranked AS (
    SELECT
        c.region,
        c.first_name || ' ' || c.last_name AS customer,
        SUM(o.total_amount)                AS total_spent,
        DENSE_RANK() OVER (
            PARTITION BY c.region
            ORDER BY SUM(o.total_amount) DESC
        )                                  AS rank_in_region
    FROM customers c
    JOIN orders o ON c.id = o.customer_id
    WHERE o.status != 'cancelled'
    GROUP BY c.region, c.id, c.first_name, c.last_name
)
SELECT * FROM ranked WHERE rank_in_region <= 3
ORDER BY region, rank_in_region;
```
</details>

---

**C2.** Write a query to find customers who have placed **more than 1 order**
and whose **average order value is above Rs.10,000**.

<details>
<summary>Answer</summary>

```sql
SELECT
    c.first_name || ' ' || c.last_name   AS customer_name,
    COUNT(o.id)                          AS order_count,
    ROUND(AVG(o.total_amount), 2)        AS avg_order_value,
    SUM(o.total_amount)                  AS total_spent
FROM customers c
JOIN orders o ON c.id = o.customer_id
WHERE o.status != 'cancelled'
GROUP BY c.id, c.first_name, c.last_name
HAVING COUNT(o.id) > 1
   AND AVG(o.total_amount) > 10000
ORDER BY avg_order_value DESC;
```

Note: Both conditions are in `HAVING` because they reference aggregates.
</details>

---

**C3.** Using a CTE, find which **product category generates the most revenue
each month**. Show the month, category, revenue, and its rank that month.

<details>
<summary>Answer</summary>

```sql
WITH monthly_category_revenue AS (
    SELECT
        DATE_TRUNC('month', o.order_date)::DATE  AS month,
        cat.name                                  AS category,
        SUM(oi.quantity * oi.unit_price)          AS revenue
    FROM order_items oi
    JOIN orders     o   ON oi.order_id   = o.id
    JOIN products   p   ON oi.product_id = p.id
    JOIN categories cat ON p.category_id = cat.id
    WHERE o.status != 'cancelled'
    GROUP BY DATE_TRUNC('month', o.order_date), cat.name
),
ranked AS (
    SELECT
        *,
        RANK() OVER (PARTITION BY month ORDER BY revenue DESC) AS rank_this_month
    FROM monthly_category_revenue
)
SELECT * FROM ranked WHERE rank_this_month = 1
ORDER BY month;
```
</details>

---

## Part C: Hands-On Tasks

Run these in pgAdmin or psql and observe the output:

1. **Run `EXPLAIN ANALYZE`** on a query before and after creating an index.
   Compare the "actual time" values. Did it get faster?

2. **Query `vw_customer_summary`** and find all "Churned" customers.
   What would you recommend to the marketing team for these customers?

3. **Write a new query** (not in any file) that finds the **most popular payment method
   per region**. Commit it to GitHub with message: `feat(phase-02): add payment method analysis`

4. **Open pgAdmin 4** → navigate to your `ecommerce` database → expand Tables.
   Click on `orders` → right-click → "View/Edit Data" → see your data visually.

---

## Part D: Connect the Dots

Answer these to show you understand how everything connects:

1. Why do we store `unit_price` in `order_items` instead of joining to `products.price`?

2. A dashboard is slow because it queries a view that does a 5-table join.
   What two solutions would you apply and why?

3. You're ingesting customer records from an API. The same customer appears twice
   (duplicate). Write the SQL pattern to keep only the latest record.

<details>
<summary>Answers</summary>

**1.** Price history: products.price changes over time. Storing unit_price at the
time of order preserves historical accuracy. Your receipt shows what you paid, not
today's price.

**2.** Solution A: Create a **Materialized View** that pre-computes the join result.
Solution B: Add **indexes** on the JOIN columns (customer_id, order_id, product_id).

**3.** ROW_NUMBER deduplication pattern:
```sql
WITH deduped AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id
            ORDER BY updated_at DESC   -- Keep latest
        ) AS rn
    FROM raw_customers
)
SELECT * FROM deduped WHERE rn = 1;
```
</details>
