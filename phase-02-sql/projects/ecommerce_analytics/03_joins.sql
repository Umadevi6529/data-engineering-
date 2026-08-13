-- =============================================================================
-- FILE: 03_joins.sql
-- WHAT THIS FILE DOES: Demonstrates every type of JOIN with real business questions
-- =============================================================================
--
-- WHAT IS A JOIN?
-- A JOIN combines rows from two or more tables based on a related column.
-- Our data is split across 5 tables. To answer business questions,
-- we need to CONNECT them.
--
-- THE GOLDEN RULE OF JOINS:
-- You join tables on columns that represent the SAME thing.
-- Example: orders.customer_id is the same ID as customers.id
-- So: JOIN orders ON orders.customer_id = customers.id
--
-- VISUAL: Think of it like a bridge between two tables.
--
--   customers table          orders table
--   +----+-------+          +----+------------+
--   | id | name  |          | id | customer_id|
--   +----+-------+          +----+------------+
--   |  1 | Priya |          |  1 |     1      |  ← "customer_id=1 matches customers.id=1"
--   |  2 | Rahul |          |  4 |     2      |  ← "customer_id=2 matches customers.id=2"
--   | 19 | Ritu  |          |  ...           |  ← customer_id=19 has no matching order
--   +----+-------+          +----+------------+
-- =============================================================================


-- =============================================================================
-- JOIN TYPE 1: INNER JOIN
-- =============================================================================
-- WHAT IT DOES:
--   Returns ONLY rows where there is a match in BOTH tables.
--   If a customer has no orders → they are EXCLUDED from results.
--   If an order has no matching customer → excluded (shouldn't happen with FK).
--
-- WHEN TO USE:
--   When you only care about rows that have matches on both sides.
--   Most common join type in analytics.
--
-- BUSINESS QUESTION: Show me all orders WITH customer details
-- =============================================================================

-- Query 1a: Basic INNER JOIN — orders + customer names
SELECT
    o.id           AS order_id,
    o.order_date,
    o.status,
    o.total_amount,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.city,
    c.region
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id
ORDER BY o.order_date;

-- EXPLANATION LINE BY LINE:
-- FROM orders o       → 'o' is an alias. Instead of writing 'orders' everywhere,
--                        we use 'o'. This is standard practice — saves typing,
--                        avoids ambiguity when two tables have same column names.
-- INNER JOIN          → Only keep rows where both tables have matching data
-- ON o.customer_id = c.id → The JOIN condition (bridge)
-- c.first_name || ' ' || c.last_name → || is PostgreSQL's string concat operator
-- ORDER BY o.order_date → Sort results by date ascending


-- Query 1b: THREE-TABLE JOIN — orders + customers + their cities/regions
-- Business Question: What is the total revenue per region?
SELECT
    c.region,
    COUNT(o.id)           AS total_orders,
    SUM(o.total_amount)   AS total_revenue,
    ROUND(AVG(o.total_amount), 2) AS avg_order_value
FROM orders o
INNER JOIN customers c ON o.customer_id = c.id
WHERE o.status != 'cancelled'          -- Exclude cancelled orders from revenue
GROUP BY c.region
ORDER BY total_revenue DESC;

-- WHY WHERE before GROUP BY?
-- SQL execution order: FROM → JOIN → WHERE → GROUP BY → HAVING → SELECT → ORDER BY
-- WHERE filters rows BEFORE grouping.
-- HAVING filters AFTER grouping (for conditions on aggregates like COUNT, SUM).


-- =============================================================================
-- JOIN TYPE 2: LEFT JOIN (most important join in DE!)
-- =============================================================================
-- WHAT IT DOES:
--   Returns ALL rows from the LEFT table.
--   + matching rows from the RIGHT table.
--   If no match → fills right-table columns with NULL.
--
-- WHEN TO USE:
--   When you want EVERYTHING from one table, even if there's no match.
--   Very common in DE for finding missing/incomplete data.
--
-- BUSINESS QUESTION: Show ALL customers, even those who never ordered
-- =============================================================================

-- Query 2a: All customers with their order count (including 0 orders)
SELECT
    c.id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.region,
    c.signup_date,
    COUNT(o.id)         AS total_orders,
    COALESCE(SUM(o.total_amount), 0) AS lifetime_value
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
GROUP BY c.id, c.first_name, c.last_name, c.region, c.signup_date
ORDER BY lifetime_value DESC;

-- EXPLANATION:
-- LEFT JOIN → all 20 customers appear, even Ritu and Suresh (0 orders)
-- COUNT(o.id) → counts non-NULL order ids. For Ritu: COUNT(NULL) = 0 ✓
-- COALESCE(SUM(o.total_amount), 0) → SUM of NULLs = NULL. 
--   COALESCE replaces NULL with 0. Ritu shows Rs.0 not NULL.
-- COALESCE(value, fallback) → returns first non-null argument.
--   In DE: COALESCE is used ALL the time for null handling.


-- =============================================================================
-- JOIN TYPE 3: ANTI JOIN (LEFT JOIN + WHERE NULL)
-- =============================================================================
-- WHAT IT DOES:
--   Returns rows from left table that have NO match in right table.
--   This is NOT a keyword — it's a pattern using LEFT JOIN + WHERE IS NULL.
--
-- WHEN TO USE:
--   Finding customers who never purchased → re-engagement campaign
--   Finding products that were never ordered → inventory review
--   Finding orphan records → data quality checks (huge in DE!)
--
-- BUSINESS QUESTION: Which customers have NEVER placed an order?
-- =============================================================================

-- Query 3a: Customers with no orders (Anti Join pattern)
SELECT
    c.id,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.email,
    c.signup_date,
    c.region
FROM customers c
LEFT JOIN orders o ON c.id = o.customer_id
WHERE o.id IS NULL;    -- The magic: if no match, o.id is NULL → filter to ONLY those

-- RESULT: Should show Ritu Aggarwal and Suresh Menon
-- WHY IS NULL and not = NULL?
-- NULL = NULL evaluates to NULL (not TRUE!) in SQL.
-- Always use IS NULL or IS NOT NULL to check for null.
-- This is one of the most common SQL bugs beginners write.


-- Query 3b: Products that have NEVER been ordered
SELECT
    p.id,
    p.name,
    p.price,
    cat.name AS category
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN categories cat ON p.category_id = cat.id
WHERE oi.id IS NULL;

-- WHY THIS MATTERS IN DE:
-- Unsold products = dead inventory. The business team uses this to run
-- discounts or remove listings. Your pipeline's job is to surface this.


-- =============================================================================
-- JOIN TYPE 4: SELF JOIN
-- =============================================================================
-- WHAT IT DOES:
--   Joins a table to ITSELF.
--   Treats the same table as if it were two different tables using two aliases.
--
-- WHEN TO USE:
--   Hierarchical data (employees and their managers in same table)
--   Comparing rows within the same table
--   Finding sequential patterns
--
-- BUSINESS QUESTION: For each order, show the PREVIOUS order by same customer
-- =============================================================================

-- Query 4a: Compare each customer's orders with their previous order
SELECT
    o1.id           AS order_id,
    o1.customer_id,
    c.first_name,
    o1.order_date   AS current_order_date,
    o2.order_date   AS previous_order_date,
    o1.total_amount AS current_amount,
    o2.total_amount AS previous_amount,
    -- Days between orders
    (o1.order_date::DATE - o2.order_date::DATE) AS days_since_last_order
FROM orders o1
JOIN orders o2
    ON o1.customer_id = o2.customer_id  -- Same customer
    AND o2.order_date < o1.order_date   -- o2 is an earlier order
JOIN customers c ON o1.customer_id = c.id
-- Only keep the IMMEDIATELY previous order (not all previous orders)
WHERE NOT EXISTS (
    SELECT 1 FROM orders o3
    WHERE o3.customer_id = o1.customer_id
      AND o3.order_date > o2.order_date
      AND o3.order_date < o1.order_date
)
ORDER BY o1.customer_id, o1.order_date;

-- EXPLANATION:
-- o1 = "current" order, o2 = "previous" order (same table, two aliases)
-- The WHERE NOT EXISTS clause ensures o2 is the IMMEDIATELY previous order,
-- not just any older order.
-- Note: Window functions (LAG) do this more elegantly — see file 04!


-- =============================================================================
-- JOIN TYPE 5: Full Multi-Table JOIN for complete order details
-- =============================================================================
-- BUSINESS QUESTION: Show a complete order line-item report
-- (This is what you'd use to build an "Orders" dashboard)
-- =============================================================================

-- Query 5: Five-table join — complete receipt view
SELECT
    o.id                AS order_id,
    o.order_date,
    o.status,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.city,
    p.name              AS product_name,
    cat.name            AS category,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price) AS line_total
FROM orders o
JOIN customers  c   ON o.id  = c.id          -- Wait! This is wrong. Let's fix it:
-- Correct version:
-- FROM order_items oi
-- JOIN orders   o   ON oi.order_id   = o.id
-- JOIN customers c   ON o.customer_id = c.id
-- JOIN products  p   ON oi.product_id  = p.id
-- JOIN categories cat ON p.category_id  = cat.id
-- ORDER BY o.id, oi.id;

-- ACTUALLY running the correct version:
SELECT
    o.id                AS order_id,
    o.order_date::DATE  AS order_date,
    o.status,
    c.first_name || ' ' || c.last_name AS customer_name,
    c.region,
    cat.name            AS category,
    p.name              AS product_name,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price) AS line_total,
    o.total_amount      AS order_total
FROM order_items oi
JOIN orders     o   ON oi.order_id   = o.id
JOIN customers  c   ON o.customer_id = c.id
JOIN products   p   ON oi.product_id = p.id
JOIN categories cat ON p.category_id = cat.id
ORDER BY o.id, oi.id;

-- HOW TO READ A MULTI-TABLE JOIN:
-- Start from the CENTER of your schema (order_items is connected to everything)
-- Join outward from there.
-- Always alias tables with 1-2 letter abbreviations (oi, o, c, p, cat)


-- =============================================================================
-- SUMMARY QUERY: Top customers by total spending
-- =============================================================================
SELECT
    c.first_name || ' ' || c.last_name AS customer_name,
    c.region,
    c.is_premium,
    COUNT(DISTINCT o.id)            AS total_orders,
    SUM(oi.quantity * oi.unit_price) AS total_spent,
    ROUND(AVG(o.total_amount), 2)   AS avg_order_value
FROM customers c
LEFT JOIN orders     o  ON c.id         = o.customer_id
LEFT JOIN order_items oi ON o.id        = oi.order_id
GROUP BY c.id, c.first_name, c.last_name, c.region, c.is_premium
ORDER BY total_spent DESC NULLS LAST;

-- NULLS LAST → customers with no orders (NULL total) go to the bottom
-- COUNT(DISTINCT o.id) → count unique orders (not order_items rows)
--   Without DISTINCT, a 3-item order would count as 3 orders!
