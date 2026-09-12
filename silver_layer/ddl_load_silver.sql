/*
===============================================================================
DDL Script: Create Silver Tables
===============================================================================
Purpose:
    Create all Silver Layer tables in PostgreSQL.
    Existing tables will be dropped if they already exist.

FIX APPLIED:
    silver.erp_px_cat_g1v2 → maintenance column changed TEXT → BOOLEAN
    Reason: the loading script converts 'YES'/'NO' to TRUE/FALSE,
            so the column type must match the actual stored values.
===============================================================================
*/

CREATE SCHEMA IF NOT EXISTS silver;

-- ============================================================
-- CRM Tables
-- ============================================================

-- silver.crm_cust_info
DROP TABLE IF EXISTS silver.crm_cust_info;
CREATE TABLE silver.crm_cust_info (
    cst_id             INTEGER,
    cst_key            TEXT,
    cst_firstname      TEXT,
    cst_lastname       TEXT,
    cst_marital_status TEXT,
    cst_gndr           TEXT,
    cst_create_date    DATE,
    dwh_create_date    TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- silver.crm_prd_info
DROP TABLE IF EXISTS silver.crm_prd_info;
CREATE TABLE silver.crm_prd_info (
    prd_id          INTEGER,
    cat_id          TEXT,
    prd_key         TEXT,
    prd_nm          TEXT,
    prd_cost        NUMERIC(12, 2),
    prd_line        TEXT,
    prd_start_dt    DATE,
    prd_end_dt      DATE,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- silver.crm_sales_details
DROP TABLE IF EXISTS silver.crm_sales_details;
CREATE TABLE silver.crm_sales_details (
    sls_ord_num     TEXT,
    sls_prd_key     TEXT,
    sls_cust_id     INTEGER,
    sls_order_dt    DATE,
    sls_ship_dt     DATE,
    sls_due_dt      DATE,
    sls_sales       NUMERIC(12, 2),
    sls_quantity    INTEGER,
    sls_price       NUMERIC(12, 2),
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- ============================================================
-- ERP Tables
-- ============================================================

-- silver.erp_cust_az12
DROP TABLE IF EXISTS silver.erp_cust_az12;
CREATE TABLE silver.erp_cust_az12 (
    cid             TEXT,
    bdate           DATE,
    gen             TEXT,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- silver.erp_loc_a101
DROP TABLE IF EXISTS silver.erp_loc_a101;
CREATE TABLE silver.erp_loc_a101 (
    cid             TEXT,
    cntry           TEXT,
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);

-- The loading script stores TRUE/FALSE values, so TEXT was wrong.
DROP TABLE IF EXISTS silver.erp_px_cat_g1v2;
CREATE TABLE silver.erp_px_cat_g1v2 (
    id              TEXT,
    cat             TEXT,
    subcat          TEXT,
    maintenance     BOOLEAN,         
    dwh_create_date TIMESTAMP DEFAULT CURRENT_TIMESTAMP
);
