-- =============================================================================
-- FILE: 04_window_functions.sql
-- WHAT THIS FILE DOES: Demonstrates all major window functions
-- =============================================================================
--
-- WHAT IS A WINDOW FUNCTION?
-- A window function performs a calculation ACROSS a set of rows
-- that are related to the current row — WITHOUT collapsing rows like GROUP BY does.
--
-- THE KEY DIFFERENCE: GROUP BY vs Window Functions
--
--   GROUP BY collapses rows:
--     SELECT region, SUM(total_amount) FROM orders GROUP BY region;
--     Result: 4 rows (one per region) — individual orders DISAPPEAR
--
--   Window function keeps all rows:
--     SELECT region, total_amount, SUM(total_amount) OVER (PARTITION BY region)
--     Result: 28 rows — each order STAYS, but has the regional total alongside it
--
-- SYNTAX:
--   function_name() OVER (
--       PARTITION BY column  ← Like GROUP BY (defines the "window" groups)
--       ORDER BY column      ← Defines order WITHIN the window
--       ROWS/RANGE BETWEEN   ← Optional: defines window frame
--   )
--
-- USE CASES IN DE:
--   → Rankings (top 5 products per category)
--   → Running totals (cumulative revenue month by month)
--   → Month-over-month change (compare this month vs last)
--   → Moving averages (smooth out noisy data)
--   → Row deduplication (keep only the latest record per customer)
-- =============================================================================


-- =============================================================================
-- WINDOW FUNCTION 1: ROW_NUMBER()
-- =============================================================================
-- Assigns a unique sequential number to each row within a partition.
-- Ties get DIFFERENT numbers (1,2,3 — never two rows get same number).
--
-- MOST IMPORTANT USE IN DE: Deduplication!
-- When you have duplicate records, ROW_NUMBER lets you keep only row #1.
-- =============================================================================

-- Q1: Rank customers by total spending (ROW_NUMBER — no ties)
SELECT
    c.first_name || ' ' || c.last_name  AS customer_name,
    c.region,
    COALESCE(SUM(o.total_amount), 0)    AS total_spent,
    ROW_NUMBER() OVER (
        ORDER BY SUM(o.total_amount) DESC NULLS LAST
    ) AS spending_rank
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id AND o.status != 'cancelled'
GROUP BY c.id, c.first_name, c.last_name, c.region
ORDER BY spending_rank;


-- Q2: ROW_NUMBER for DEDUPLICATION (the #1 use case in DE)
-- Scenario: What if we had duplicate orders? Keep only the first one per customer.
-- This pattern is used in ETL to deduplicate source data before loading to warehouse.

WITH orders_with_rn AS (
    SELECT
        *,
        ROW_NUMBER() OVER (
            PARTITION BY customer_id          -- For each customer...
            ORDER BY order_date ASC           -- ...number their orders oldest first
        ) AS rn
    FROM orders
)
SELECT * FROM orders_with_rn WHERE rn = 1;   -- Keep only 1st order per customer

-- REAL DE USAGE:
-- Imagine you're ingesting customer profile updates from an API.
-- The same customer might appear 3 times (3 updates).
-- ROW_NUMBER() OVER (PARTITION BY customer_id ORDER BY updated_at DESC) → rn=1
-- gives you the LATEST profile. This is called "SCD Type 1 handling".


-- =============================================================================
-- WINDOW FUNCTION 2: RANK() and DENSE_RANK()
-- =============================================================================
-- RANK():       If two rows tie for 1st, both get rank 1. Next rank = 3 (gap).
-- DENSE_RANK(): If two rows tie for 1st, both get rank 1. Next rank = 2 (no gap).
--
-- WHEN TO USE WHICH:
--   RANK()       → Sports leaderboards ("2nd place doesn't exist if two tied for 1st")
--   DENSE_RANK() → Most DE use cases ("top N per category" without gaps)
-- =============================================================================

-- Q3: Top 3 products by revenue in each category
WITH product_revenue AS (
    SELECT
        p.name              AS product_name,
        cat.name            AS category,
        SUM(oi.quantity * oi.unit_price) AS total_revenue,
        DENSE_RANK() OVER (
            PARTITION BY cat.name          -- Rank WITHIN each category
            ORDER BY SUM(oi.quantity * oi.unit_price) DESC
        ) AS rank_in_category
    FROM order_items oi
    JOIN products   p   ON oi.product_id = p.id
    JOIN categories cat ON p.category_id = cat.id
    GROUP BY p.name, cat.name
)
SELECT * FROM product_revenue
WHERE rank_in_category <= 3
ORDER BY category, rank_in_category;

-- NOTE: We use a CTE here because window functions can't be in WHERE directly.
-- You must wrap them in a subquery or CTE, then filter in the outer query.
-- This is a very common SQL pattern in DE.


-- =============================================================================
-- WINDOW FUNCTION 3: LAG() and LEAD()
-- =============================================================================
-- LAG(column, n)  → Get the value from n rows BEFORE current row
-- LEAD(column, n) → Get the value from n rows AFTER current row
-- Default n = 1 (immediately previous/next row)
--
-- USE CASE: Month-over-month comparisons, growth rates, sequential analysis
-- =============================================================================

-- Q4: Month-over-month revenue change
WITH monthly_revenue AS (
    SELECT
        DATE_TRUNC('month', order_date) AS month,      -- Truncate to month start
        SUM(total_amount)               AS revenue
    FROM orders
    WHERE status != 'cancelled'
    GROUP BY DATE_TRUNC('month', order_date)
)
SELECT
    TO_CHAR(month, 'YYYY-MM')          AS month,
    revenue                            AS current_revenue,
    LAG(revenue) OVER (ORDER BY month) AS previous_month_revenue,
    revenue - LAG(revenue) OVER (ORDER BY month) AS revenue_change,
    ROUND(
        (revenue - LAG(revenue) OVER (ORDER BY month))
        / NULLIF(LAG(revenue) OVER (ORDER BY month), 0) * 100
    , 2)                               AS pct_change
FROM monthly_revenue
ORDER BY month;

-- EXPLANATION:
-- DATE_TRUNC('month', order_date) → Rounds date down to 1st of the month.
--   '2024-01-15' → '2024-01-01', '2024-01-28' → '2024-01-01'
--   This groups all January orders together.
-- LAG(revenue) OVER (ORDER BY month) → For each month, get previous month's revenue
-- NULLIF(x, 0) → If x=0, return NULL instead (avoids division by zero error!)
--   Without NULLIF: 100/0 = ERROR. With NULLIF: 100/NULL = NULL (safe).


-- Q5: For each customer, show their previous order date and amount (self join alternative)
SELECT
    c.first_name                                      AS customer,
    o.order_date::DATE                                AS order_date,
    o.total_amount,
    LAG(o.order_date::DATE) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
    )                                                 AS prev_order_date,
    LAG(o.total_amount) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
    )                                                 AS prev_order_amount,
    -- Days since last order
    o.order_date::DATE - LAG(o.order_date::DATE) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
    )                                                 AS days_between_orders
FROM orders o
JOIN customers c ON o.customer_id = c.id
ORDER BY o.customer_id, o.order_date;

-- NOTICE: This replaces the messy SELF JOIN from file 03.
-- Window functions are almost always cleaner than self joins for sequential data.


-- =============================================================================
-- WINDOW FUNCTION 4: SUM() OVER() — Running Total
-- =============================================================================
-- A running total accumulates values as you move down rows.
-- Example: Daily sales: 100, 200, 150 → Running: 100, 300, 450
--
-- USE CASE: Cumulative revenue, cumulative shipments, balance tracking
-- =============================================================================

-- Q6: Daily cumulative revenue (running total)
WITH daily_sales AS (
    SELECT
        order_date::DATE AS sale_date,
        SUM(total_amount) AS daily_revenue
    FROM orders
    WHERE status != 'cancelled'
    GROUP BY order_date::DATE
)
SELECT
    sale_date,
    daily_revenue,
    SUM(daily_revenue) OVER (
        ORDER BY sale_date
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM daily_sales
ORDER BY sale_date;

-- ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW:
-- This defines the "window frame" — which rows to include in the calculation.
-- UNBOUNDED PRECEDING = from the very first row
-- CURRENT ROW        = up to and including this row
-- So: sum everything from the beginning up to this row = running total.

-- SHORTHAND: SUM(daily_revenue) OVER (ORDER BY sale_date) does the same thing
-- by default. The ROWS BETWEEN makes it explicit.


-- =============================================================================
-- WINDOW FUNCTION 5: AVG() OVER() — Moving Average
-- =============================================================================
-- Instead of running total, calculate average over a sliding window of rows.
-- Used to SMOOTH OUT noisy data (daily sales can spike/dip — 7-day avg is cleaner).
-- =============================================================================

-- Q7: 3-order moving average of order values per customer
SELECT
    c.first_name                        AS customer,
    o.order_date::DATE                  AS order_date,
    o.total_amount,
    ROUND(AVG(o.total_amount) OVER (
        PARTITION BY o.customer_id
        ORDER BY o.order_date
        ROWS BETWEEN 2 PRECEDING AND CURRENT ROW  -- this row + 2 before it = 3 rows
    ), 2)                               AS moving_avg_3_orders
FROM orders o
JOIN customers c ON o.customer_id = c.id
ORDER BY o.customer_id, o.order_date;

-- ROWS BETWEEN 2 PRECEDING AND CURRENT ROW:
-- Include the current row and the 2 rows before it.
-- For the 1st order: only 1 row → avg of just that row.
-- For the 2nd order: 2 rows → avg of those 2.
-- For the 3rd+ order: 3 rows → avg of last 3.


-- =============================================================================
-- WINDOW FUNCTION 6: NTILE() — Bucketing / Percentiles
-- =============================================================================
-- Divides rows into N equal buckets (as equal as possible).
-- NTILE(4) → Quartiles (Q1, Q2, Q3, Q4)
-- NTILE(10) → Deciles (top 10%, next 10%, etc.)
-- NTILE(100) → Percentiles
--
-- USE CASE: Customer segmentation, product performance tiers, A/B test buckets
-- =============================================================================

-- Q8: Segment customers into 4 tiers by total spending
WITH customer_spending AS (
    SELECT
        c.id,
        c.first_name || ' ' || c.last_name  AS customer_name,
        c.region,
        COALESCE(SUM(o.total_amount), 0)    AS total_spent
    FROM customers c
    LEFT JOIN orders o ON c.id = o.customer_id AND o.status != 'cancelled'
    GROUP BY c.id, c.first_name, c.last_name, c.region
)
SELECT
    customer_name,
    region,
    total_spent,
    NTILE(4) OVER (ORDER BY total_spent DESC) AS spending_quartile,
    CASE
        WHEN NTILE(4) OVER (ORDER BY total_spent DESC) = 1 THEN 'Platinum'
        WHEN NTILE(4) OVER (ORDER BY total_spent DESC) = 2 THEN 'Gold'
        WHEN NTILE(4) OVER (ORDER BY total_spent DESC) = 3 THEN 'Silver'
        ELSE 'Bronze'
    END                                       AS customer_tier
FROM customer_spending
ORDER BY total_spent DESC;

-- THIS IS REAL MARKETING DATA ENGINEERING:
-- Platinum customers → High-touch account management
-- Bronze customers → Re-engagement email campaigns
-- Your pipeline produces this table → marketing uses it for campaigns.


-- =============================================================================
-- COMBINED: All window functions together — The Executive Dashboard Query
-- =============================================================================

-- Q9: Complete order analytics — ranks, running totals, MoM change
WITH monthly_stats AS (
    SELECT
        DATE_TRUNC('month', o.order_date)          AS month,
        c.region,
        COUNT(o.id)                                AS orders_count,
        SUM(o.total_amount)                        AS revenue
    FROM orders o
    JOIN customers c ON o.customer_id = c.id
    WHERE o.status != 'cancelled'
    GROUP BY DATE_TRUNC('month', o.order_date), c.region
)
SELECT
    TO_CHAR(month, 'YYYY-MM')                     AS month,
    region,
    orders_count,
    revenue,
    -- Running total per region
    SUM(revenue) OVER (
        PARTITION BY region
        ORDER BY month
    )                                             AS cumulative_revenue,
    -- Previous month revenue
    LAG(revenue) OVER (
        PARTITION BY region
        ORDER BY month
    )                                             AS prev_month_revenue,
    -- Month-over-month growth %
    ROUND(
        (revenue - LAG(revenue) OVER (PARTITION BY region ORDER BY month))
        / NULLIF(LAG(revenue) OVER (PARTITION BY region ORDER BY month), 0)
        * 100
    , 1)                                          AS mom_growth_pct,
    -- Rank this month among all months for this region
    RANK() OVER (
        PARTITION BY region
        ORDER BY revenue DESC
    )                                             AS best_month_rank
FROM monthly_stats
ORDER BY region, month;
