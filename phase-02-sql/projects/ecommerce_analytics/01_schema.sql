-- =============================================================================
-- FILE: 01_schema.sql
-- WHAT THIS FILE DOES: Creates all 5 tables for our e-commerce database
-- =============================================================================
--
-- WHAT IS A SCHEMA?
-- A schema is the BLUEPRINT of your database.
-- It defines: what tables exist, what columns each has, what data type
-- each column holds, and what rules (constraints) apply.
--
-- Think of it like designing the columns of an Excel spreadsheet BEFORE
-- you fill in any data. Get the design wrong, and everything breaks later.
--
-- WHY ORDER MATTERS HERE:
-- Tables reference each other using FOREIGN KEYS.
-- You must create the "parent" table BEFORE the "child" table.
-- Example: products references categories, so categories must exist first.
--
-- ORDER: categories → products → customers → orders → order_items
-- =============================================================================


-- DROP existing tables if re-running this script (clean slate)
-- CASCADE means: also drop anything that depends on these tables
DROP TABLE IF EXISTS order_items CASCADE;
DROP TABLE IF EXISTS orders CASCADE;
DROP TABLE IF EXISTS products CASCADE;
DROP TABLE IF EXISTS customers CASCADE;
DROP TABLE IF EXISTS categories CASCADE;


-- =============================================================================
-- TABLE 1: categories
-- =============================================================================
-- This is a DIMENSION table — it describes what kind of product something is.
-- It has NO foreign keys — it is the "root" of our schema tree.
--
-- DATA TYPES USED:
--   SERIAL       → Auto-incrementing integer (1, 2, 3...). PostgreSQL generates
--                  this automatically. You never insert a value for it.
--                  Same as INT AUTO_INCREMENT in MySQL.
--   VARCHAR(n)   → Variable-length string, max n characters.
--                  Use this for names, emails, short text.
--   TEXT         → Unlimited length string. Use for descriptions, notes.
--
-- CONSTRAINTS:
--   PRIMARY KEY  → Uniquely identifies each row. No two rows can have same id.
--                  Every table should have a primary key — it's the "address" of a row.
--   NOT NULL     → This column MUST have a value. Cannot be empty.
--   UNIQUE       → No two rows can have the same value in this column.
-- =============================================================================

CREATE TABLE categories (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(100) NOT NULL UNIQUE,
    description TEXT
);

-- WHY UNIQUE on name?
-- You don't want two categories both called "Electronics".
-- UNIQUE constraint prevents this at the DATABASE level — not just in your app code.
-- This is called "data integrity" — the database itself enforces rules.


-- =============================================================================
-- TABLE 2: products
-- =============================================================================
-- Products belong to a category. This is a DIMENSION table.
--
-- NEW CONCEPTS:
--   DECIMAL(10,2) → Number with up to 10 digits total, 2 after decimal.
--                   Used for MONEY. Never use FLOAT for money!
--                   Why? FLOAT has rounding errors: 0.1 + 0.2 = 0.30000000000000004
--                   DECIMAL is exact: 0.10 + 0.20 = 0.30 ✓
--
--   FOREIGN KEY  → Links this table to another table.
--                  category_id in products must exist as an id in categories.
--                  If you try to insert a product with category_id=999 but
--                  no category with id=999 exists → database rejects it.
--                  This is REFERENTIAL INTEGRITY — it prevents orphan records.
--
--   DEFAULT      → Value used if you don't specify one during INSERT.
--                  stock_qty DEFAULT 0 means new products start with 0 stock.
--
--   CHECK        → Custom rule the database enforces.
--                  price > 0 means you can never insert a negative price.
-- =============================================================================

CREATE TABLE products (
    id          SERIAL PRIMARY KEY,
    name        VARCHAR(200) NOT NULL,
    description TEXT,
    price       DECIMAL(10,2) NOT NULL CHECK (price > 0),
    category_id INT NOT NULL,
    stock_qty   INT DEFAULT 0 CHECK (stock_qty >= 0),
    created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,

    FOREIGN KEY (category_id) REFERENCES categories(id)
);


-- =============================================================================
-- TABLE 3: customers
-- =============================================================================
-- DIMENSION table — who is buying from us.
--
-- NEW CONCEPTS:
--   VARCHAR(255) → Standard size for email addresses.
--   DATE         → Stores only a date (no time). YYYY-MM-DD format.
--                  Use DATE when time doesn't matter (signup date, birth date).
--                  Use TIMESTAMP when time matters (order placed at 14:32:05).
-- =============================================================================

CREATE TABLE customers (
    id          SERIAL PRIMARY KEY,
    first_name  VARCHAR(100) NOT NULL,
    last_name   VARCHAR(100) NOT NULL,
    email       VARCHAR(255) NOT NULL UNIQUE,
    city        VARCHAR(100),
    region      VARCHAR(50),    -- North, South, East, West
    signup_date DATE NOT NULL DEFAULT CURRENT_DATE,
    is_premium  BOOLEAN DEFAULT FALSE
);

-- WHY UNIQUE on email?
-- An email is a natural identifier for a person.
-- Two customers cannot share an email — it's their login credential.
-- Without UNIQUE, duplicate accounts can be created → data quality nightmare.


-- =============================================================================
-- TABLE 4: orders
-- =============================================================================
-- FACT table — each row represents ONE order event.
-- Links a customer to a purchase.
--
-- NEW CONCEPTS:
--   TIMESTAMP    → Date + time. When exactly did the order happen?
--   DEFAULT NOW()→ Automatically set to current date+time when row is inserted.
--
--   CHECK with IN → Restrict a column to specific allowed values.
--                   status can only be one of these 5 strings.
--                   Any other value → database rejects the insert.
--                   In modern Postgres, you'd use an ENUM type instead.
-- =============================================================================

CREATE TABLE orders (
    id              SERIAL PRIMARY KEY,
    customer_id     INT NOT NULL,
    order_date      TIMESTAMP NOT NULL DEFAULT NOW(),
    status          VARCHAR(20) NOT NULL DEFAULT 'pending'
                        CHECK (status IN ('pending','processing','shipped','delivered','cancelled')),
    total_amount    DECIMAL(12,2) NOT NULL CHECK (total_amount >= 0),
    payment_method  VARCHAR(50) CHECK (payment_method IN ('credit_card','debit_card','upi','net_banking','cod')),

    FOREIGN KEY (customer_id) REFERENCES customers(id)
);

-- WHY is total_amount stored here AND in order_items?
-- total_amount in orders = pre-computed summary (fast to read).
-- order_items has individual line prices (source of truth).
-- This is called DENORMALIZATION — storing derived data for query speed.
-- A common DE pattern: you compute and store summaries for dashboard performance.


-- =============================================================================
-- TABLE 5: order_items
-- =============================================================================
-- FACT table — each row is ONE LINE ITEM within an order.
-- One order can have many items: this is where the detail lives.
--
-- WHY store unit_price here instead of just referencing products.price?
-- Because product prices CHANGE over time.
-- If a laptop was Rs.70,000 when you ordered it, your receipt should show
-- Rs.70,000 — not Rs.85,000 (today's price).
-- Storing unit_price at time of order = historical accuracy. Critical in DE.
-- =============================================================================

CREATE TABLE order_items (
    id          SERIAL PRIMARY KEY,
    order_id    INT NOT NULL,
    product_id  INT NOT NULL,
    quantity    INT NOT NULL CHECK (quantity > 0),
    unit_price  DECIMAL(10,2) NOT NULL CHECK (unit_price > 0),

    FOREIGN KEY (order_id)   REFERENCES orders(id),
    FOREIGN KEY (product_id) REFERENCES products(id)
);


-- =============================================================================
-- VERIFY: Check that all tables were created
-- =============================================================================
-- \dt is a psql meta-command that lists all tables in current database.
-- In a SQL file you can use a query instead:

SELECT
    table_name,
    table_type
FROM information_schema.tables
WHERE table_schema = 'public'
ORDER BY table_name;

-- You should see 5 rows:
--   categories, customers, order_items, orders, products
