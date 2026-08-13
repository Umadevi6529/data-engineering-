-- =============================================================================
-- FILE: 07_views.sql
-- WHAT THIS FILE DOES: Views and Materialized Views
-- =============================================================================
--
-- WHAT IS A VIEW?
-- A VIEW is a SAVED SQL QUERY that behaves like a table.
-- You give a query a name, and from then on you can query it like a table.
--
-- ANALOGY: Think of a VIEW like a saved Excel formula.
-- The formula (query) runs fresh every time you open the cell (query the view).
--
-- WHY VIEWS MATTER IN DE:
--   1. REUSABILITY: Write a complex join once → use it everywhere
--   2. ABSTRACTION: Business users query simple view names, not complex JOINs
--   3. SECURITY: Grant access to views, not raw tables (hide sensitive columns)
--   4. CONSISTENCY: Everyone uses the same definition of "active customer"
--
-- VIEW vs MATERIALIZED VIEW:
--   VIEW:               Query runs every time → always fresh, never stored
--   MATERIALIZED VIEW:  Query runs once → result STORED on disk → fast reads
--                       Must REFRESH manually when data changes
--
-- WHEN TO USE EACH:
--   VIEW:               Data that changes often, queries that run rarely
--   MATERIALIZED VIEW:  Data that changes infrequently, queries that run VERY often
--                       (like dashboard queries that run every second)
-- =============================================================================


-- =============================================================================
-- VIEW 1: vw_order_details — Complete order line-item view
-- =============================================================================
-- Business users can now just: SELECT * FROM vw_order_details WHERE region='South'
-- They don't need to know about the 5-table join underneath.
-- =============================================================================

CREATE OR REPLACE VIEW vw_order_details AS
SELECT
    o.id                                        AS order_id,
    o.order_date::DATE                          AS order_date,
    o.status,
    o.payment_method,
    c.id                                        AS customer_id,
    c.first_name || ' ' || c.last_name          AS customer_name,
    c.email,
    c.city,
    c.region,
    c.is_premium,
    cat.name                                    AS category,
    p.id                                        AS product_id,
    p.name                                      AS product_name,
    oi.quantity,
    oi.unit_price,
    (oi.quantity * oi.unit_price)               AS line_total,
    o.total_amount                              AS order_total
FROM order_items oi
JOIN orders     o   ON oi.order_id   = o.id
JOIN customers  c   ON o.customer_id = c.id
JOIN products   p   ON oi.product_id = p.id
JOIN categories cat ON p.category_id = cat.id;

-- Now anyone can query it simply:
SELECT * FROM vw_order_details WHERE region = 'South' ORDER BY order_date;
SELECT * FROM vw_order_details WHERE status = 'delivered' AND category = 'Electronics';


-- =============================================================================
-- VIEW 2: vw_customer_summary — Customer 360 view (common in CRM/analytics)
-- =============================================================================

CREATE OR REPLACE VIEW vw_customer_summary AS
WITH order_stats AS (
    SELECT
        customer_id,
        COUNT(id)                           AS total_orders,
        SUM(total_amount)                   AS lifetime_value,
        MIN(order_date::DATE)               AS first_order_date,
        MAX(order_date::DATE)               AS last_order_date,
        ROUND(AVG(total_amount), 2)         AS avg_order_value
    FROM orders
    WHERE status != 'cancelled'
    GROUP BY customer_id
)
SELECT
    c.id                                    AS customer_id,
    c.first_name || ' ' || c.last_name      AS full_name,
    c.email,
    c.city,
    c.region,
    c.is_premium,
    c.signup_date,
    COALESCE(os.total_orders, 0)            AS total_orders,
    COALESCE(os.lifetime_value, 0)          AS lifetime_value,
    os.first_order_date,
    os.last_order_date,
    os.avg_order_value,
    CURRENT_DATE - os.last_order_date       AS days_since_last_order,
    -- Customer status classification
    CASE
        WHEN os.total_orders IS NULL                    THEN 'Never Ordered'
        WHEN CURRENT_DATE - os.last_order_date <= 30   THEN 'Active'
        WHEN CURRENT_DATE - os.last_order_date <= 90   THEN 'At Risk'
        ELSE 'Churned'
    END                                     AS customer_status
FROM customers c
LEFT JOIN order_stats os ON c.id = os.customer_id;

-- Use it:
SELECT * FROM vw_customer_summary WHERE customer_status = 'Churned';
SELECT * FROM vw_customer_summary ORDER BY lifetime_value DESC LIMIT 5;


-- =============================================================================
-- VIEW 3: vw_product_performance — Product analytics view
-- =============================================================================

CREATE OR REPLACE VIEW vw_product_performance AS
SELECT
    p.id                                        AS product_id,
    p.name                                      AS product_name,
    p.price                                     AS current_price,
    p.stock_qty                                 AS current_stock,
    cat.name                                    AS category,
    COALESCE(SUM(oi.quantity), 0)               AS total_units_sold,
    COALESCE(SUM(oi.quantity * oi.unit_price),0) AS total_revenue,
    COUNT(DISTINCT oi.order_id)                 AS times_ordered,
    ROUND(AVG(oi.unit_price), 2)                AS avg_selling_price
FROM products p
LEFT JOIN order_items oi ON p.id = oi.product_id
LEFT JOIN categories cat ON p.category_id = cat.id
GROUP BY p.id, p.name, p.price, p.stock_qty, cat.name;

SELECT * FROM vw_product_performance ORDER BY total_revenue DESC;


-- =============================================================================
-- MATERIALIZED VIEW: mv_monthly_sales — Pre-computed for dashboard speed
-- =============================================================================
--
-- WHY MATERIALIZED?
-- A dashboard refreshes this every 5 minutes.
-- The underlying query scans all orders + order_items (could be millions of rows).
-- With a MATERIALIZED VIEW, the heavy query runs ONCE (or on refresh schedule).
-- Every dashboard request reads the pre-computed result → milliseconds.
--
-- This is exactly what Redshift, BigQuery "materialized views" do at scale.
-- =============================================================================

CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_sales AS
SELECT
    DATE_TRUNC('month', o.order_date)::DATE     AS month,
    c.region,
    cat.name                                    AS category,
    COUNT(DISTINCT o.id)                        AS order_count,
    COUNT(DISTINCT o.customer_id)               AS unique_customers,
    SUM(oi.quantity)                            AS units_sold,
    ROUND(SUM(oi.quantity * oi.unit_price), 2)  AS revenue
FROM orders o
JOIN customers  c   ON o.customer_id = c.id
JOIN order_items oi ON o.id          = oi.order_id
JOIN products   p   ON oi.product_id = p.id
JOIN categories cat ON p.category_id = cat.id
WHERE o.status != 'cancelled'
GROUP BY
    DATE_TRUNC('month', o.order_date),
    c.region,
    cat.name
WITH DATA;   -- Run immediately and store the result

-- Query the materialized view (fast!):
SELECT * FROM mv_monthly_sales ORDER BY month, revenue DESC;

-- Add an index to the materialized view for even faster querying:
CREATE INDEX IF NOT EXISTS idx_mv_monthly_sales_month
    ON mv_monthly_sales(month);

-- When new orders come in, refresh the materialized view:
-- (In production, Airflow would run this on a schedule)
REFRESH MATERIALIZED VIEW mv_monthly_sales;


-- =============================================================================
-- LIST ALL VIEWS: See what we created
-- =============================================================================
SELECT
    table_name  AS view_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
  AND table_type = 'VIEW'
ORDER BY table_name;
