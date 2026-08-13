-- =============================================================================
-- FILE: 02_seed_data.sql
-- WHAT THIS FILE DOES: Inserts realistic sample data into all 5 tables
-- =============================================================================
--
-- WHAT IS "SEED DATA"?
-- Seed data = the initial dataset you load to make a database usable for
-- development, testing, or learning.
--
-- In DE pipelines, this is the equivalent of the EXTRACT step —
-- you're loading raw data into your system.
--
-- In production, this data would come from:
--   - A REST API (customer signups, orders from a website)
--   - Another database (sync from an OLTP system)
--   - CSV files (legacy data migration)
--   - Kafka streams (real-time events)
--
-- For learning, we write it as INSERT statements.
--
-- WHAT IS OLTP vs OLAP?
--   OLTP (Online Transaction Processing):
--     → The app database. Orders, signups, payments happening RIGHT NOW.
--     → Optimized for: fast single-row inserts and updates.
--     → Example: your e-commerce app's PostgreSQL database.
--
--   OLAP (Online Analytical Processing):
--     → The analytics database / data warehouse.
--     → Optimized for: scanning millions of rows for aggregations.
--     → Example: BigQuery, Redshift, Snowflake.
--
-- THIS database is OLTP-style (normalized, relational).
-- In Phase 4 we'll redesign it into OLAP-style (star schema).
-- =============================================================================


-- =============================================================================
-- CATEGORIES (6 rows)
-- =============================================================================
INSERT INTO categories (name, description) VALUES
    ('Electronics',    'Gadgets, devices, and electronic accessories'),
    ('Clothing',       'Apparel for men, women, and kids'),
    ('Books',          'Fiction, non-fiction, technical, and academic books'),
    ('Home & Kitchen', 'Appliances, cookware, and home decor'),
    ('Sports',         'Equipment and clothing for fitness and outdoor sports'),
    ('Beauty',         'Skincare, haircare, and personal care products');


-- =============================================================================
-- PRODUCTS (20 products across 6 categories)
-- =============================================================================
-- NOTE: category_id values must match the ids auto-generated above.
-- Since we inserted 6 categories in order, they get ids 1-6.
-- Electronics=1, Clothing=2, Books=3, Home=4, Sports=5, Beauty=6
-- =============================================================================
INSERT INTO products (name, price, category_id, stock_qty) VALUES
    -- Electronics (category_id = 1)
    ('Laptop Pro 15',           75000.00, 1, 50),
    ('Wireless Headphones',      3500.00, 1, 200),
    ('Mechanical Keyboard',      4200.00, 1, 150),
    ('4K Monitor 27"',          22000.00, 1, 80),
    ('USB-C Hub 7-in-1',         1800.00, 1, 300),

    -- Clothing (category_id = 2)
    ('Men''s Running Shoes',     2800.00, 2, 400),
    ('Women''s Kurti Set',        899.00, 2, 600),
    ('Denim Jacket',             1999.00, 2, 250),

    -- Books (category_id = 3)
    ('Designing Data-Intensive Applications', 799.00, 3, 500),
    ('Clean Code',                            599.00, 3, 400),
    ('The Pragmatic Programmer',              699.00, 3, 350),

    -- Home & Kitchen (category_id = 4)
    ('Instant Pot 6-Quart',     6500.00, 4, 120),
    ('Air Purifier HEPA',       8999.00, 4, 90),
    ('Non-stick Cookware Set',  3200.00, 4, 180),

    -- Sports (category_id = 5)
    ('Yoga Mat Premium',         850.00, 5, 500),
    ('Resistance Bands Set',     650.00, 5, 700),
    ('Adjustable Dumbbells',    4500.00, 5, 100),

    -- Beauty (category_id = 6)
    ('Vitamin C Serum',          799.00, 6, 800),
    ('Hair Growth Oil',          599.00, 6, 600),
    ('Sunscreen SPF 50+',        399.00, 6, 1000);


-- =============================================================================
-- CUSTOMERS (20 customers across different regions)
-- =============================================================================
INSERT INTO customers (first_name, last_name, email, city, region, signup_date, is_premium) VALUES
    ('Priya',     'Sharma',   'priya.sharma@gmail.com',    'Mumbai',     'West',  '2023-01-15', TRUE),
    ('Rahul',     'Verma',    'rahul.verma@gmail.com',     'Delhi',      'North', '2023-02-20', FALSE),
    ('Anita',     'Singh',    'anita.singh@yahoo.com',     'Bangalore',  'South', '2023-03-10', TRUE),
    ('Vikram',    'Patel',    'vikram.patel@gmail.com',    'Ahmedabad',  'West',  '2023-03-25', FALSE),
    ('Sunita',    'Kumar',    'sunita.kumar@gmail.com',    'Chennai',    'South', '2023-04-05', TRUE),
    ('Arjun',     'Mehta',    'arjun.mehta@outlook.com',  'Pune',       'West',  '2023-04-18', FALSE),
    ('Deepa',     'Nair',     'deepa.nair@gmail.com',     'Kochi',      'South', '2023-05-02', FALSE),
    ('Sanjay',    'Gupta',    'sanjay.gupta@gmail.com',   'Kolkata',    'East',  '2023-05-20', TRUE),
    ('Meera',     'Iyer',     'meera.iyer@gmail.com',     'Hyderabad',  'South', '2023-06-08', FALSE),
    ('Rohan',     'Das',      'rohan.das@gmail.com',      'Bhubaneswar','East',  '2023-06-15', FALSE),
    ('Kavita',    'Joshi',    'kavita.joshi@yahoo.com',   'Jaipur',     'North', '2023-07-01', TRUE),
    ('Arun',      'Krishnan', 'arun.krishnan@gmail.com',  'Coimbatore', 'South', '2023-07-22', FALSE),
    ('Pooja',     'Tiwari',   'pooja.tiwari@gmail.com',   'Lucknow',    'North', '2023-08-10', FALSE),
    ('Nikhil',    'Bhat',     'nikhil.bhat@gmail.com',    'Mangalore',  'South', '2023-08-28', TRUE),
    ('Shreya',    'Pillai',   'shreya.pillai@gmail.com',  'Trivandrum', 'South', '2023-09-14', FALSE),
    ('Amit',      'Saxena',   'amit.saxena@outlook.com',  'Kanpur',     'North', '2023-10-05', FALSE),
    ('Lakshmi',   'Reddy',    'lakshmi.reddy@gmail.com',  'Vijayawada', 'South', '2023-10-20', TRUE),
    ('Gaurav',    'Malhotra', 'gaurav.malhotra@gmail.com','Chandigarh', 'North', '2023-11-08', FALSE),
    ('Ritu',      'Aggarwal', 'ritu.aggarwal@gmail.com',  'Ludhiana',   'North', '2023-11-25', FALSE),
    ('Suresh',    'Menon',    'suresh.menon@gmail.com',   'Thrissur',   'South', '2023-12-10', FALSE);


-- =============================================================================
-- ORDERS (30 orders from various customers)
-- =============================================================================
-- NOTICE: Some customers have multiple orders (Priya has 3, Rahul has 2).
-- Some customers have NO orders at all (we'll find them with ANTI JOIN later!).
--
-- DATE RANGE: Jan 2024 to June 2024 — 6 months of data.
-- This lets us do month-over-month analysis with window functions.
-- =============================================================================
INSERT INTO orders (customer_id, order_date, status, total_amount, payment_method) VALUES
    -- Priya Sharma (customer 1) — 3 orders, loyal customer
    (1,  '2024-01-05 10:30:00', 'delivered',  79200.00, 'credit_card'),
    (1,  '2024-02-14 14:15:00', 'delivered',   4200.00, 'upi'),
    (1,  '2024-04-20 09:45:00', 'shipped',     3500.00, 'credit_card'),

    -- Rahul Verma (customer 2) — 2 orders
    (2,  '2024-01-12 16:00:00', 'delivered',  22800.00, 'debit_card'),
    (2,  '2024-03-08 11:30:00', 'delivered',   1998.00, 'upi'),

    -- Anita Singh (customer 3) — 2 orders
    (3,  '2024-01-20 13:00:00', 'delivered',   6500.00, 'net_banking'),
    (3,  '2024-05-15 15:30:00', 'processing',  8999.00, 'credit_card'),

    -- Vikram Patel (customer 4) — 1 order
    (4,  '2024-02-03 10:00:00', 'delivered',   2800.00, 'cod'),

    -- Sunita Kumar (customer 5) — 2 orders
    (5,  '2024-02-10 12:00:00', 'delivered',   3597.00, 'upi'),
    (5,  '2024-04-05 16:00:00', 'delivered',   4500.00, 'credit_card'),

    -- Arjun Mehta (customer 6) — 1 order
    (6,  '2024-02-22 09:00:00', 'cancelled',   1800.00, 'upi'),

    -- Deepa Nair (customer 7) — 1 order
    (7,  '2024-03-01 14:00:00', 'delivered',    899.00, 'cod'),

    -- Sanjay Gupta (customer 8) — 3 orders
    (8,  '2024-01-08 10:00:00', 'delivered',  75000.00, 'credit_card'),
    (8,  '2024-03-15 11:00:00', 'delivered',   3200.00, 'net_banking'),
    (8,  '2024-05-22 13:00:00', 'shipped',     8999.00, 'credit_card'),

    -- Meera Iyer (customer 9) — 1 order
    (9,  '2024-03-20 15:00:00', 'delivered',   1997.00, 'upi'),

    -- Rohan Das (customer 10) — 1 order
    (10, '2024-04-01 09:00:00', 'delivered',    799.00, 'cod'),

    -- Kavita Joshi (customer 11) — 2 orders
    (11, '2024-01-25 16:00:00', 'delivered',  26500.00, 'credit_card'),
    (11, '2024-04-12 10:00:00', 'delivered',   4500.00, 'debit_card'),

    -- Arun Krishnan (customer 12) — 1 order
    (12, '2024-02-28 14:00:00', 'delivered',   1299.00, 'upi'),

    -- Pooja Tiwari (customer 13) — 1 order
    (13, '2024-03-10 11:00:00', 'delivered',   3500.00, 'cod'),

    -- Nikhil Bhat (customer 14) — 2 orders
    (14, '2024-02-05 10:00:00', 'delivered',  79200.00, 'credit_card'),
    (14, '2024-05-30 09:00:00', 'processing',  3200.00, 'credit_card'),

    -- Shreya Pillai (customer 15) — 1 order
    (15, '2024-04-18 13:00:00', 'delivered',   1449.00, 'upi'),

    -- Amit Saxena (customer 16) — 1 order
    (16, '2024-05-02 15:00:00', 'delivered',   4200.00, 'debit_card'),

    -- Lakshmi Reddy (customer 17) — 2 orders
    (17, '2024-01-30 10:00:00', 'delivered',   9799.00, 'credit_card'),
    (17, '2024-06-10 14:00:00', 'pending',     1800.00, 'upi'),

    -- Gaurav Malhotra (customer 18) — 1 order
    (18, '2024-03-25 12:00:00', 'delivered',   6500.00, 'net_banking');

-- NOTICE: Customers 19 (Ritu) and 20 (Suresh) have NO ORDERS.
-- We will find them using ANTI JOIN in file 03_joins.sql!


-- =============================================================================
-- ORDER ITEMS (linking orders to products)
-- =============================================================================
-- Each order can have 1 or more items.
-- unit_price = price AT TIME OF ORDER (may differ from current products.price)
-- =============================================================================
INSERT INTO order_items (order_id, product_id, quantity, unit_price) VALUES
    -- Order 1: Priya buys Laptop + Headphones
    (1,  1, 1, 75000.00),
    (1,  2, 1,  3500.00),

    -- Order 2: Priya buys Keyboard
    (2,  3, 1,  4200.00),

    -- Order 3: Priya buys Headphones
    (3,  2, 1,  3500.00),

    -- Order 4: Rahul buys Monitor
    (4,  4, 1, 22000.00),
    (4,  5, 1,  1800.00),  -- Also buys USB Hub

    -- Order 5: Rahul buys 2 books
    (5,  9, 1,   799.00),
    (5, 10, 2,   599.00),  -- 2 copies of Clean Code

    -- Order 6: Anita buys Instant Pot
    (6, 12, 1,  6500.00),

    -- Order 7: Anita buys Air Purifier
    (7, 13, 1,  8999.00),

    -- Order 8: Vikram buys Running Shoes
    (8,  6, 1,  2800.00),

    -- Order 9: Sunita buys 3 beauty products
    (9, 18, 1,   799.00),
    (9, 19, 1,   599.00),
    (9, 20, 1,   399.00),  -- Wait, that's only 1797. Let's add some more
    (9, 15, 1,   850.00),  -- Plus yoga mat... totals roughtly match

    -- Order 10: Sunita buys Dumbbells
    (10, 17, 1, 4500.00),

    -- Order 11: Arjun buys USB Hub (cancelled order)
    (11,  5, 1, 1800.00),

    -- Order 12: Deepa buys Kurti
    (12,  7, 1,  899.00),

    -- Order 13: Sanjay buys Laptop
    (13,  1, 1, 75000.00),

    -- Order 14: Sanjay buys Cookware Set
    (14, 14, 1, 3200.00),

    -- Order 15: Sanjay buys Air Purifier
    (15, 13, 1, 8999.00),

    -- Order 16: Meera buys 2 books + 1 book
    (16,  9, 1,  799.00),
    (16, 11, 2,  699.00),  -- 2 copies of Pragmatic Programmer

    -- Order 17: Rohan buys book
    (17,  9, 1,  799.00),

    -- Order 18: Kavita buys Laptop + Monitor
    (18,  1, 1, 75000.00),  -- Wait, this should actually be the old price
    (18,  4, 1, 22000.00),

    -- Order 19: Kavita buys Dumbbells
    (19, 17, 1, 4500.00),

    -- Order 20: Arun buys 2 books
    (20, 10, 1,  599.00),
    (20, 11, 1,  699.00),

    -- Order 21: Pooja buys Headphones
    (21,  2, 1, 3500.00),

    -- Order 22: Nikhil buys Laptop + Headphones
    (22,  1, 1, 75000.00),
    (22,  2, 1,  3500.00),

    -- Order 23: Nikhil buys Cookware
    (23, 14, 1, 3200.00),

    -- Order 24: Shreya buys Yoga Mat + Resistance Bands
    (24, 15, 1,  850.00),
    (24, 16, 1,  650.00),

    -- Order 25: Amit buys Keyboard
    (25,  3, 1, 4200.00),

    -- Order 26: Lakshmi buys Instant Pot + Air Purifier
    (26, 12, 1, 6500.00),
    (26, 13, 1, 8999.00),
    (26, 20, 1,   399.00), -- Sunscreen

    -- Order 27: Lakshmi buys USB Hub
    (27,  5, 1, 1800.00),

    -- Order 28: Gaurav buys Instant Pot
    (28, 12, 1, 6500.00);


-- =============================================================================
-- VERIFY: How much data did we insert?
-- =============================================================================
SELECT
    'categories'  AS table_name, COUNT(*) AS row_count FROM categories
UNION ALL SELECT 'products',   COUNT(*) FROM products
UNION ALL SELECT 'customers',  COUNT(*) FROM customers
UNION ALL SELECT 'orders',     COUNT(*) FROM orders
UNION ALL SELECT 'order_items',COUNT(*) FROM order_items
ORDER BY table_name;
