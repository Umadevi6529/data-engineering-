-- =============================================================================
-- FILE: 05_ctes.sql
-- WHAT THIS FILE DOES: CTEs (Common Table Expressions) — the most readable
--                      way to write complex SQL
-- =============================================================================
--
-- WHAT IS A CTE?
-- A CTE (WITH clause) is a NAMED TEMPORARY RESULT SET that you define at the
-- top of a query and reference in the main query below it.
--
-- Think of it like VARIABLES in programming.
-- In Python you write: result = calculate_something()
-- In SQL CTEs you write: WITH result AS (SELECT calculate_something)
--
-- WITHOUT CTEs (hard to read):
--   SELECT * FROM (
--       SELECT * FROM (
--           SELECT * FROM (
--               -- deeply nested hell
--           ) sub1
--       ) sub2
--   ) sub3;
--
-- WITH CTEs (readable, like steps):
--   WITH
--   step1 AS (SELECT...),       -- first, do this
--   step2 AS (SELECT FROM step1), -- then, use that result
--   step3 AS (SELECT FROM step2)  -- then, use that
--   SELECT * FROM step3;          -- final answer
--
-- CTEs in DE are used for:
--   → Breaking complex transforms into readable steps
--   → Re-using a subquery multiple times without repeating code
--   → Recursive queries (hierarchies, date sequences)
--   → dbt models are literally just CTEs in SQL files!
-- =============================================================================


-- =============================================================================
-- CTE EXAMPLE 1: Multi-step customer analysis
-- =============================================================================
-- BUSINESS QUESTION:
-- "Show me customers who signed up more than 6 months ago,
--  have spent over Rs.5000, and rank them by lifetime value."
--
-- WITHOUT CTE this is a mess. WITH CTEs it reads like English steps.
-- =============================================================================

WITH
-- Step 1: Calculate each customer's lifetime value
customer_ltv AS (
    SELECT
        c.id                                        AS customer_id,
        c.first_name || ' ' || c.last_name          AS customer_name,
        c.signup_date,
        c.region,
        c.is_premium,
        COALESCE(SUM(o.total_amount), 0)            AS lifetime_value,
        COUNT(o.id)                                 AS total_orders,
        MAX(o.order_date::DATE)                     AS last_order_date
    FROM customers c
    LEFT JOIN orders o
           ON c.id = o.customer_id
          AND o.status != 'cancelled'
    GROUP BY c.id, c.first_name, c.last_name, c.signup_date, c.region, c.is_premium
),

-- Step 2: Filter to customers who signed up 6+ months ago
established_customers AS (
    SELECT *
    FROM customer_ltv
    WHERE signup_date <= CURRENT_DATE - INTERVAL '6 months'
),

-- Step 3: Filter to high-value customers (spent > 5000)
high_value AS (
    SELECT *
    FROM established_customers
    WHERE lifetime_value > 5000
),

-- Step 4: Add ranking
ranked AS (
    SELECT
        *,
        DENSE_RANK() OVER (ORDER BY lifetime_value DESC) AS value_rank
    FROM high_value
)

-- Final: Select what we need
SELECT
    value_rank,
    customer_name,
    region,
    is_premium,
    lifetime_value,
    total_orders,
    last_order_date,
    -- How long since last order?
    CURRENT_DATE - last_order_date                  AS days_since_last_order
FROM ranked
ORDER BY value_rank;

-- INTERVAL '6 months' → PostgreSQL interval syntax.
-- CURRENT_DATE - INTERVAL '6 months' = 6 months ago from today.
-- This is much cleaner than date arithmetic in other languages.


-- =============================================================================
-- CTE EXAMPLE 2: Product Performance Analysis
-- =============================================================================
-- BUSINESS QUESTION:
-- "For each category, which products are above-average performers?
--  Show the product, its revenue, the category average, and how far above/below."
-- =============================================================================

WITH
-- Step 1: Calculate revenue per product
product_revenue AS (
    SELECT
        p.id                                            AS product_id,
        p.name                                          AS product_name,
        p.price                                         AS list_price,
        cat.name                                        AS category,
        SUM(oi.quantity)                                AS units_sold,
        SUM(oi.quantity * oi.unit_price)                AS total_revenue
    FROM products p
    LEFT JOIN order_items oi ON p.id = oi.product_id
    LEFT JOIN categories cat ON p.category_id = cat.id
    GROUP BY p.id, p.name, p.price, cat.name
),

-- Step 2: Calculate average revenue per category
category_averages AS (
    SELECT
        category,
        ROUND(AVG(total_revenue), 2) AS avg_revenue_in_category,
        SUM(total_revenue)           AS category_total_revenue
    FROM product_revenue
    GROUP BY category
),

-- Step 3: Join them together and compare
comparison AS (
    SELECT
        pr.product_name,
        pr.category,
        pr.total_revenue,
        ca.avg_revenue_in_category,
        ca.category_total_revenue,
        pr.total_revenue - ca.avg_revenue_in_category   AS vs_category_avg,
        ROUND(
            (pr.total_revenue - ca.avg_revenue_in_category)
            / NULLIF(ca.avg_revenue_in_category, 0) * 100
        , 1)                                            AS pct_vs_avg
    FROM product_revenue pr
    JOIN category_averages ca ON pr.category = ca.category
)

SELECT
    category,
    product_name,
    COALESCE(total_revenue, 0)              AS revenue,
    avg_revenue_in_category,
    vs_category_avg,
    pct_vs_avg,
    CASE
        WHEN vs_category_avg > 0 THEN 'Above Average'
        WHEN vs_category_avg = 0 THEN 'At Average'
        ELSE 'Below Average'
    END                                     AS performance
FROM comparison
ORDER BY category, total_revenue DESC NULLS LAST;


-- =============================================================================
-- CTE EXAMPLE 3: Cohort Analysis (advanced but critical in DE!)
-- =============================================================================
-- WHAT IS COHORT ANALYSIS?
-- Group customers by WHEN they signed up (their "cohort" = signup month).
-- Track how those groups behave over time.
-- Used by every product/growth team to measure retention.
--
-- QUESTION: "Of customers who signed up in Jan 2023, how many ordered
--            in their first month? 2nd month? 3rd month?"
-- =============================================================================

WITH
-- Step 1: Find each customer's signup month (their cohort)
customer_cohorts AS (
    SELECT
        id              AS customer_id,
        DATE_TRUNC('month', signup_date)    AS cohort_month
    FROM customers
),

-- Step 2: Find each customer's first order month
first_orders AS (
    SELECT
        customer_id,
        DATE_TRUNC('month', MIN(order_date)) AS first_order_month
    FROM orders
    GROUP BY customer_id
),

-- Step 3: Calculate how many months after signup did they first order
cohort_behavior AS (
    SELECT
        cc.cohort_month,
        cc.customer_id,
        fo.first_order_month,
        -- How many months between signup and first order?
        EXTRACT(YEAR FROM AGE(fo.first_order_month, cc.cohort_month)) * 12
        + EXTRACT(MONTH FROM AGE(fo.first_order_month, cc.cohort_month))
            AS months_to_first_order
    FROM customer_cohorts cc
    LEFT JOIN first_orders fo ON cc.customer_id = fo.customer_id
),

-- Step 4: Summarize — for each cohort, how many ordered within 0,1,2,3 months?
cohort_summary AS (
    SELECT
        TO_CHAR(cohort_month, 'YYYY-MM')    AS cohort,
        COUNT(customer_id)                  AS cohort_size,
        COUNT(first_order_month)            AS customers_who_ordered,
        COUNT(CASE WHEN months_to_first_order = 0  THEN 1 END) AS ordered_month_0,
        COUNT(CASE WHEN months_to_first_order <= 1 THEN 1 END) AS ordered_month_1,
        COUNT(CASE WHEN months_to_first_order <= 2 THEN 1 END) AS ordered_month_2,
        COUNT(CASE WHEN months_to_first_order <= 3 THEN 1 END) AS ordered_month_3
    FROM cohort_behavior
    GROUP BY cohort_month
)

SELECT
    cohort,
    cohort_size,
    customers_who_ordered,
    ordered_month_0,
    ordered_month_1,
    ordered_month_2,
    ordered_month_3,
    -- Conversion rates
    ROUND(customers_who_ordered::NUMERIC / NULLIF(cohort_size, 0) * 100, 1) AS overall_conversion_pct,
    ROUND(ordered_month_0::NUMERIC        / NULLIF(cohort_size, 0) * 100, 1) AS same_month_pct
FROM cohort_summary
ORDER BY cohort;

-- AGE(end_date, start_date) → PostgreSQL function that returns an interval.
-- EXTRACT(MONTH FROM AGE(...)) → Extracts just the month component.
-- This is how you calculate "months between two dates" in PostgreSQL.


-- =============================================================================
-- RECURSIVE CTE: Generating a Date Sequence
-- =============================================================================
-- WHAT IS A RECURSIVE CTE?
-- A CTE that REFERENCES ITSELF. It loops until a condition is met.
-- Like a while loop in Python, but in SQL.
--
-- CRITICAL DE USE CASE:
-- Generate a complete date spine (every day in a range).
-- WHY? If you JOIN sales data to a date table, days with NO sales still appear
-- (with 0 revenue). Without it, those days are missing from your chart!
-- =============================================================================

WITH RECURSIVE date_spine AS (
    -- Anchor: the starting date (base case, like while loop initialization)
    SELECT '2024-01-01'::DATE AS dt

    UNION ALL

    -- Recursive: add 1 day each iteration (like while dt <= end_date: dt += 1 day)
    SELECT dt + INTERVAL '1 day'
    FROM date_spine
    WHERE dt < '2024-06-30'
)
-- Now LEFT JOIN your sales data to this spine to get ALL days (including zero days)
SELECT
    ds.dt                                           AS date,
    TO_CHAR(ds.dt, 'Day')                           AS day_of_week,
    COALESCE(SUM(o.total_amount), 0)                AS daily_revenue,
    COUNT(o.id)                                     AS orders_count
FROM date_spine ds
LEFT JOIN orders o
       ON o.order_date::DATE = ds.dt
      AND o.status != 'cancelled'
GROUP BY ds.dt
ORDER BY ds.dt;

-- THIS IS A FOUNDATIONAL DE PATTERN:
-- In production, this date_spine is usually a permanent DIM_DATE table
-- with hundreds of pre-calculated columns: is_weekend, is_holiday,
-- quarter, fiscal_year, etc. Every warehouse has one.
-- You will build this properly in Phase 4 (Data Warehousing).
