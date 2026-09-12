-- ============================================================
-- Schema: Gold Layer (Star Schema)
-- ============================================================
CREATE SCHEMA IF NOT EXISTS gold;

-- ============================================================
-- 1. dim_customers 
-- ============================================================
DROP TABLE IF EXISTS gold.dim_customers CASCADE; 
CREATE TABLE gold.dim_customers (
    customer_sk       SERIAL PRIMARY KEY, 
    cst_id            INTEGER NOT NULL, 
    cst_key           TEXT, 
    full_name         TEXT, 
    gender            TEXT, 
    marital_status    TEXT, 
    birth_date        DATE, 
    country           TEXT, 
    registration_date DATE, 
    dwh_load_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
); 

-- ============================================================
-- 2. dim_products
-- ============================================================
DROP TABLE IF EXISTS gold.dim_products CASCADE; 
CREATE TABLE gold.dim_products (
    product_sk        SERIAL PRIMARY KEY, 
    prd_id            INTEGER NOT NULL, 
    prd_key           TEXT, 
    product_name      TEXT, 
    category          TEXT, 
    subcategory       TEXT, 
    maintenance       BOOLEAN, 
    product_line      TEXT, 
    cost              NUMERIC(12, 2), 
    start_date        DATE, 
    end_date          DATE, 
    is_current        BOOLEAN, 
    dwh_load_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP 
); 

-- ============================================================
-- 3. dim_date
-- ============================================================
DROP TABLE IF EXISTS gold.dim_date CASCADE; 
CREATE TABLE gold.dim_date (
    date_sk           INTEGER PRIMARY KEY,
    full_date         DATE NOT NULL UNIQUE,
    year              INTEGER,
    quarter           INTEGER,
    month_number      INTEGER,
    month_name        TEXT,
    day_of_month      INTEGER,
    day_of_week       INTEGER,
    day_name          TEXT,
    week_of_year      INTEGER,
    is_weekend        BOOLEAN,
    fiscal_year       INTEGER,
    fiscal_quarter    INTEGER,
    dwh_load_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
); 

-- ============================================================
-- 4. fact_sales
-- ============================================================
DROP TABLE IF EXISTS gold.fact_sales CASCADE; 
CREATE TABLE gold.fact_sales (
    sales_sk          SERIAL PRIMARY KEY,
    customer_sk       INTEGER REFERENCES gold.dim_customers(customer_sk),
    product_sk        INTEGER REFERENCES gold.dim_products(product_sk),
    order_date_sk     INTEGER REFERENCES gold.dim_date(date_sk),
    ship_date_sk      INTEGER REFERENCES gold.dim_date(date_sk),
    due_date_sk       INTEGER REFERENCES gold.dim_date(date_sk),
    order_number      TEXT,
    order_date        DATE, 
	ship_date         DATE,
    due_date          DATE,
    quantity          INTEGER,
    unit_price        NUMERIC(12,2),
    total_sales       NUMERIC(12,2),
    product_cost      NUMERIC(12,2), 
    profit            NUMERIC(12,2), 
    dwh_load_date     TIMESTAMP DEFAULT CURRENT_TIMESTAMP
); 

-- ============================================================
-- Performance Indexes
-- ============================================================
CREATE INDEX idx_fact_customer   ON gold.fact_sales(customer_sk);
CREATE INDEX idx_fact_product    ON gold.fact_sales(product_sk);
CREATE INDEX idx_fact_order_date ON gold.fact_sales(order_date_sk);
CREATE INDEX idx_fact_order_num  ON gold.fact_sales(order_number); 

-- check 
SELECT table_schema, table_name
FROM information_schema.tables
WHERE table_schema = 'gold'
ORDER BY table_name;


