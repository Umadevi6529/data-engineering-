-- =============================================================================
-- FILE: 01_dw_schema.sql
-- WHAT THIS FILE DOES: Creates a complete Star Schema Data Warehouse DDL
-- =============================================================================
--
-- DIMENSIONAL DESIGN:
--   Dimension Tables:
--     - dim_date             (Date spine with pre-computed date attributes)
--     - dim_customers_scd2   (SCD Type 2 Customer Dimension with Surrogate Keys)
--     - dim_products         (Product Dimension)
--   Fact Tables:
--     - fact_sales           (Transaction Fact Table for line-item sales)
-- =============================================================================

-- Drop tables if re-running (order: facts first, then dimensions)
DROP TABLE IF EXISTS fact_sales CASCADE;
DROP TABLE IF EXISTS dim_customers_scd2 CASCADE;
DROP TABLE IF EXISTS dim_products CASCADE;
DROP TABLE IF EXISTS dim_date CASCADE;

-- =============================================================================
-- DIMENSION 1: dim_date (Conformed Date Dimension)
-- =============================================================================
-- In Data Warehouses, date dimensions are pre-populated for 10+ years.
-- date_key = YYYYMMDD as an INTEGER (e.g. 20260813)
-- Allows ultra-fast integer joins without date functions at query time.
-- =============================================================================
CREATE TABLE dim_date (
    date_key        INT PRIMARY KEY,              -- e.g. 20260813
    full_date       DATE NOT NULL,
    year            INT NOT NULL,
    quarter         INT NOT NULL,
    month           INT NOT NULL,
    month_name      VARCHAR(20) NOT NULL,
    day_of_month    INT NOT NULL,
    day_of_week     INT NOT NULL,
    day_name        VARCHAR(20) NOT NULL,
    is_weekend      BOOLEAN NOT NULL,
    fiscal_quarter  VARCHAR(10) NOT NULL
);

-- =============================================================================
-- DIMENSION 2: dim_customers_scd2 (SCD Type 2 Dimension)
-- =============================================================================
-- Uses customer_sk (Surrogate Key) as PRIMARY KEY.
-- customer_id is the Natural Key from source system.
-- Stores full history when city, region, or tier changes.
-- =============================================================================
CREATE TABLE dim_customers_scd2 (
    customer_sk     SERIAL PRIMARY KEY,           -- Surrogate Key (integer)
    customer_id     VARCHAR(50) NOT NULL,         -- Natural / Business Key
    first_name      VARCHAR(100) NOT NULL,
    last_name       VARCHAR(100) NOT NULL,
    email           VARCHAR(255) NOT NULL,
    city            VARCHAR(100) NOT NULL,
    region          VARCHAR(50) NOT NULL,
    tier            VARCHAR(20) NOT NULL,         -- standard, premium, VIP
    effective_date  DATE NOT NULL,
    end_date        DATE NOT NULL DEFAULT '9999-12-31',
    is_current      BOOLEAN NOT NULL DEFAULT TRUE
);

CREATE INDEX idx_dim_cust_natural_key ON dim_customers_scd2(customer_id);
CREATE INDEX idx_dim_cust_current ON dim_customers_scd2(customer_id, is_current);

-- =============================================================================
-- DIMENSION 3: dim_products (Product Dimension)
-- =============================================================================
CREATE TABLE dim_products (
    product_sk      SERIAL PRIMARY KEY,           -- Surrogate Key
    product_id      VARCHAR(50) NOT NULL,         -- Natural Key
    product_name    VARCHAR(200) NOT NULL,
    category        VARCHAR(100) NOT NULL,
    current_price   DECIMAL(10,2) NOT NULL
);

-- =============================================================================
-- FACT TABLE: fact_sales (Transaction Line-Item Fact Table)
-- =============================================================================
-- Each row represents one line-item in a sales transaction (Grain = 1 line item).
-- References SURROGATE KEYS of dimension tables.
-- =============================================================================
CREATE TABLE fact_sales (
    sales_fact_id   SERIAL PRIMARY KEY,
    order_id        VARCHAR(50) NOT NULL,         -- Degenerate Dimension
    date_key        INT NOT NULL REFERENCES dim_date(date_key),
    customer_sk     INT NOT NULL REFERENCES dim_customers_scd2(customer_sk),
    product_sk      INT NOT NULL REFERENCES dim_products(product_sk),

    -- Measures / Facts (Numeric & Additive)
    quantity        INT NOT NULL,
    unit_price      DECIMAL(10,2) NOT NULL,
    gross_amount    DECIMAL(12,2) NOT NULL,
    discount_amount DECIMAL(10,2) DEFAULT 0.00,
    net_revenue     DECIMAL(12,2) NOT NULL
);

CREATE INDEX idx_fact_sales_date ON fact_sales(date_key);
CREATE INDEX idx_fact_sales_cust ON fact_sales(customer_sk);
CREATE INDEX idx_fact_sales_prod ON fact_sales(product_sk);
