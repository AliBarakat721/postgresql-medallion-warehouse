/*
===============================================================================
Load Script: gold.fact_sales
===============================================================================
Purpose:
    Load sales transactions with surrogate key lookups and profit calculation.
    SCD Type 2 aware with fallback to current active product version.
===============================================================================
*/

TRUNCATE TABLE gold.fact_sales RESTART IDENTITY;

INSERT INTO gold.fact_sales (
    customer_sk,
    product_sk,
    order_date_sk,
    ship_date_sk,
    due_date_sk,
    order_number,
    order_date,
    ship_date,
    due_date,
    quantity,
    unit_price,
    total_sales,
    product_cost,
    profit
)
SELECT 
    c.customer_sk,
    COALESCE(p_scd.product_sk, p_curr.product_sk) AS product_sk,
    
    -- Date SK Lookups
    CAST(TO_CHAR(s.sls_order_dt, 'YYYYMMDD') AS INTEGER) AS order_date_sk,
    CAST(TO_CHAR(s.sls_ship_dt, 'YYYYMMDD') AS INTEGER) AS ship_date_sk,
    CAST(TO_CHAR(s.sls_due_dt, 'YYYYMMDD') AS INTEGER) AS due_date_sk,
    
    -- Business Keys & Dates
    s.sls_ord_num AS order_number,
    s.sls_order_dt AS order_date,
    s.sls_ship_dt AS ship_date,
    s.sls_due_dt AS due_date,
    
    -- Metrics
    s.sls_quantity AS quantity,
    s.sls_price AS unit_price,
    s.sls_sales AS total_sales,
    
    -- Financial Calculations
    (COALESCE(p_scd.cost, p_curr.cost, 0) * s.sls_quantity) AS product_cost,
    (s.sls_sales - (COALESCE(p_scd.cost, p_curr.cost, 0) * s.sls_quantity)) AS profit

FROM silver.crm_sales_details s

-- Join Customer Dimension (INTEGER Join)
LEFT JOIN gold.dim_customers c 
    ON s.sls_cust_id = c.cst_id

-- 1. Exact Date-Match SCD Type 2 Join
LEFT JOIN gold.dim_products p_scd 
    ON TRIM(s.sls_prd_key) = TRIM(p_scd.prd_key)
   AND s.sls_order_dt >= p_scd.start_date
   AND (s.sls_order_dt <= p_scd.end_date OR p_scd.end_date IS NULL)

-- 2. Fallback Join: Current Version if date is out of range
LEFT JOIN gold.dim_products p_curr 
    ON TRIM(s.sls_prd_key) = TRIM(p_curr.prd_key)
   AND p_curr.is_current = TRUE;

-- ============================================================
-- Validation
-- ============================================================
SELECT 
    COUNT(*) AS total_sales_records,
    COUNT(customer_sk) AS valid_customer_sk_matches,
    COUNT(*) - COUNT(customer_sk) AS unmapped_customers,
    COUNT(product_sk) AS valid_product_sk_matches,
    COUNT(*) - COUNT(product_sk) AS unmapped_products,
    SUM(total_sales) AS total_revenue,
    SUM(profit) AS total_profit
FROM gold.fact_sales;