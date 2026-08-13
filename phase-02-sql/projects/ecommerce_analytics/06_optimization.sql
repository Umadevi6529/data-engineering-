-- =============================================================================
-- FILE: 06_optimization.sql
-- WHAT THIS FILE DOES: Query optimization — EXPLAIN ANALYZE and Indexes
-- =============================================================================
--
-- WHY DOES QUERY OPTIMIZATION MATTER IN DE?
-- At small scale (100 rows): every query runs in milliseconds. No problem.
-- At DE scale (100 million rows): a badly written query can take 4 HOURS.
--   → Dashboards time out
--   → Pipelines fail
--   → Stakeholders are angry
--
-- As a Data Engineer, you MUST understand:
--   1. How does PostgreSQL EXECUTE a query? (query plans)
--   2. What makes a query slow? (full table scans)
--   3. How do you make it fast? (indexes, rewrites)
--
-- THE TOOLS:
--   EXPLAIN       → Shows the query PLAN (how it WILL run) — no actual execution
--   EXPLAIN ANALYZE → Actually RUNS the query and shows HOW it ran + timing
-- =============================================================================


-- =============================================================================
-- STEP 1: EXPLAIN ANALYZE — Reading a Query Plan
-- =============================================================================
--
-- HOW TO READ EXPLAIN ANALYZE OUTPUT:
--
-- Seq Scan     → Sequential Scan: reads EVERY row in the table.
--                Like reading a book page by page looking for a word.
--                SLOW for large tables. FAST for small tables.
--
-- Index Scan   → Uses an index to jump directly to matching rows.
--                Like using a book's INDEX to find the word directly.
--                FAST for large tables when filtering specific rows.
--
-- Hash Join    → PostgreSQL builds a hash table from one table, then probes
--                it with rows from the other table. Used for large joins.
--
-- Nested Loop  → For each row in outer table, scan inner table.
--                O(n²) complexity — terrible at scale.
--
-- cost=X..Y    → X = startup cost, Y = total cost (arbitrary units, lower = better)
-- rows=N       → Estimated rows returned
-- actual time  → Actual milliseconds (in EXPLAIN ANALYZE)
-- =============================================================================

-- Query: Find all orders from the South region
-- BEFORE adding any index:
EXPLAIN ANALYZE
SELECT o.id, o.total_amount, o.order_date, c.region
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE c.region = 'South';

-- You'll see: Seq Scan on customers (reading ALL rows to find South ones)
-- The database has no shortcut — it reads every customer to check region.


-- =============================================================================
-- STEP 2: CREATE INDEXES — Making Queries Fast
-- =============================================================================
--
-- WHAT IS AN INDEX?
-- A separate data structure (B-tree by default) that stores column values
-- in SORTED ORDER with pointers to the actual rows.
--
-- Like the index at the back of a textbook:
-- Instead of reading every page looking for "PostgreSQL",
-- you look it up in the index → go directly to page 247.
--
-- TYPES OF INDEXES:
--   B-tree (default)  → Equality and range queries (=, >, <, BETWEEN)
--                        Best for most DE use cases
--   Hash              → Only equality (=). Faster than B-tree for exact matches.
--   GIN               → Full-text search, JSON queries, arrays
--   BRIN              → Very large tables with sequential data (logs, time-series)
--
-- WHEN TO ADD AN INDEX:
--   ✓ Columns used in WHERE clause frequently
--   ✓ Columns used in JOIN conditions
--   ✓ Columns used in ORDER BY when fetching small result sets
--   ✗ Don't index everything! Indexes slow down INSERT/UPDATE/DELETE.
--     In OLTP systems (high write volume), over-indexing is a real problem.
--     In OLAP/warehouses (mostly reads), more indexes are fine.
-- =============================================================================

-- Index 1: Speed up filtering by region (used in WHERE clauses often)
CREATE INDEX IF NOT EXISTS idx_customers_region
    ON customers(region);

-- Index 2: Speed up JOIN between orders and customers
-- (orders.customer_id is already a FK — Postgres may auto-index it, but being explicit)
CREATE INDEX IF NOT EXISTS idx_orders_customer_id
    ON orders(customer_id);

-- Index 3: Speed up date range queries on orders (very common in DE!)
CREATE INDEX IF NOT EXISTS idx_orders_order_date
    ON orders(order_date);

-- Index 4: Composite index — for queries that filter on BOTH status AND date
-- A composite index works for: WHERE status='delivered' AND order_date > ...
-- Or just: WHERE status = 'delivered'
-- But NOT efficiently for: WHERE order_date > ... (status must be first)
-- RULE: Put the most selective column first in composite indexes
CREATE INDEX IF NOT EXISTS idx_orders_status_date
    ON orders(status, order_date);

-- Index 5: Speed up order_items joins (used in almost every analytical query)
CREATE INDEX IF NOT EXISTS idx_order_items_order_id
    ON order_items(order_id);

CREATE INDEX IF NOT EXISTS idx_order_items_product_id
    ON order_items(product_id);


-- =============================================================================
-- STEP 3: EXPLAIN ANALYZE AFTER indexes — see the difference
-- =============================================================================

-- Same query as before — now with the region index in place:
EXPLAIN ANALYZE
SELECT o.id, o.total_amount, o.order_date, c.region
FROM orders o
JOIN customers c ON o.customer_id = c.id
WHERE c.region = 'South';

-- Look for: "Index Scan using idx_customers_region" instead of "Seq Scan"
-- The cost numbers should be lower now.

-- Date range query — now uses the date index:
EXPLAIN ANALYZE
SELECT id, customer_id, total_amount
FROM orders
WHERE order_date BETWEEN '2024-01-01' AND '2024-03-31';


-- =============================================================================
-- STEP 4: Query Anti-Patterns — Common Mistakes That Kill Performance
-- =============================================================================

-- BAD PATTERN 1: Function on indexed column in WHERE clause
-- This DESTROYS the index! PostgreSQL can't use idx_orders_order_date here.
EXPLAIN
SELECT * FROM orders
WHERE EXTRACT(YEAR FROM order_date) = 2024;   -- Function prevents index use!

-- GOOD PATTERN: Use range instead
EXPLAIN
SELECT * FROM orders
WHERE order_date >= '2024-01-01' AND order_date < '2025-01-01';
-- Now the index on order_date CAN be used.


-- BAD PATTERN 2: SELECT * — fetching columns you don't need
-- At 100M rows with 50 columns, SELECT * sends massive amounts of data.
-- Always select ONLY the columns you actually need.
-- BAD:  SELECT * FROM orders JOIN customers...
-- GOOD: SELECT o.id, o.total_amount, c.first_name FROM orders o JOIN customers c...


-- BAD PATTERN 3: NOT IN with NULLs
-- This is a subtle bug — NOT IN with a subquery that can return NULL
-- will silently return 0 rows!
-- BAD:
SELECT * FROM customers
WHERE id NOT IN (SELECT customer_id FROM orders);
-- If ANY order has NULL customer_id → this returns NOTHING! (SQL NULL logic bug)

-- GOOD: Use NOT EXISTS or LEFT JOIN + IS NULL (Anti Join pattern from file 03)
SELECT c.* FROM customers c
WHERE NOT EXISTS (
    SELECT 1 FROM orders o WHERE o.customer_id = c.id
);


-- BAD PATTERN 4: Implicit type conversion
-- If you compare a VARCHAR column to an integer, PostgreSQL must cast every row.
-- This prevents index use.
-- BAD:  WHERE customer_id = '5'    (string vs integer column)
-- GOOD: WHERE customer_id = 5


-- =============================================================================
-- STEP 5: View index statistics
-- =============================================================================

-- Check what indexes exist on our tables:
SELECT
    schemaname,
    tablename,
    indexname,
    indexdef
FROM pg_indexes
WHERE schemaname = 'public'
ORDER BY tablename, indexname;

-- Check table sizes (important for understanding when optimization matters):
SELECT
    relname        AS table_name,
    pg_size_pretty(pg_total_relation_size(relid))  AS total_size,
    pg_size_pretty(pg_relation_size(relid))        AS table_size,
    pg_size_pretty(pg_total_relation_size(relid) - pg_relation_size(relid)) AS index_size
FROM pg_catalog.pg_statio_user_tables
ORDER BY pg_total_relation_size(relid) DESC;
