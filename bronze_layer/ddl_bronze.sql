/*
===============================================================================
DDL Script: Create Bronze Tables
===============================================================================
Purpose:
    Create the 'bronze' schema and its tables — raw, untransformed
    staging data loaded directly from source CSV files.
    Existing tables are dropped and recreated on each run.

Fixes applied (review pass with proc_load_bronze.sql):

    Fix A — Removed duplicate schema creation.
             This script previously created 'silver' and 'gold' schemas
             too. Each layer's own DDL script (ddl_load_silver.sql,
             ddl_gold.sql) already creates its schema — duplicating it
             here served no purpose and blurred layer ownership.

    Fix B — Added dwh_load_date audit column to every Bronze table.
             Silver and Gold both stamp rows with a load timestamp;
             Bronze didn't, which made it impossible to trace when a
             raw row entered the warehouse. Matches the pattern used
             downstream.

    Fix C — Aligned prd_cost precision to NUMERIC(12,2), matching the
             same column in silver.crm_prd_info and gold.dim_products.
             Bronze was NUMERIC(10,2) — inconsistent across layers,
             even though sample data never approached that range.
===============================================================================
*/

-- only this layer's schema is created here
CREATE SCHEMA IF NOT EXISTS bronze;

-- ============================================================
-- CRM Tables
-- ============================================================

-- bronze.crm_cust_info
DROP TABLE IF EXISTS bronze.crm_cust_info;
CREATE TABLE bronze.crm_cust_info (
    cst_id              INTEGER,
    cst_key             TEXT,
    cst_firstname       TEXT,
    cst_lastname        TEXT,
    cst_marital_status  TEXT,
    cst_gndr            TEXT,
    cst_create_date     DATE,
    dwh_load_date       TIMESTAMP DEFAULT CURRENT_TIMESTAMP  
);

-- bronze.crm_prd_info
DROP TABLE IF EXISTS bronze.crm_prd_info;
CREATE TABLE bronze.crm_prd_info (
    prd_id          INTEGER,
    prd_key         TEXT,
    prd_nm          TEXT,
    prd_cost        NUMERIC(12, 2),                          
    prd_line        TEXT,
    prd_start_dt    DATE,
    prd_end_dt      DATE,
    dwh_load_date   TIMESTAMP DEFAULT CURRENT_TIMESTAMP     
);

-- bronze.crm_sales_details
-- Dates stay INTEGER by design: the source CSV stores them as raw
-- YYYYMMDD integers (e.g. 20101229). Conversion to DATE, including
-- handling of invalid/zero values, happens in the Silver layer.
DROP TABLE IF EXISTS bronze.crm_sales_details;
CREATE TABLE bronze.crm_sales_details (
    sls_ord_num     TEXT,
    sls_prd_key     TEXT,
    sls_cust_id     INTEGER,
    sls_order_dt    INTEGER,
    sls_ship_dt     INTEGER,
    sls_due_dt      INTEGER,
    sls_sales       NUMERIC(12, 2),
    sls_quantity    INTEGER,
    sls_price       NUMERIC(12, 2),
    dwh_load_date   TIMESTAMP DEFAULT CURRENT_TIMESTAMP       
);

-- ============================================================
-- ERP Tables
-- ============================================================

-- bronze.erp_cust_az12
DROP TABLE IF EXISTS bronze.erp_cust_az12;
CREATE TABLE bronze.erp_cust_az12 (
    cid             TEXT,
    bdate           DATE,
    gen             TEXT,
    dwh_load_date   TIMESTAMP DEFAULT CURRENT_TIMESTAMP      
);

-- bronze.erp_loc_a101
DROP TABLE IF EXISTS bronze.erp_loc_a101;
CREATE TABLE bronze.erp_loc_a101 (
    cid             TEXT,
    cntry           TEXT,
    dwh_load_date   TIMESTAMP DEFAULT CURRENT_TIMESTAMP       
);

-- bronze.erp_px_cat_g1v2
-- Stays TEXT here by design: this is the raw 'YES'/'NO' string as
-- it appears in the source CSV. The BOOLEAN conversion happens in
-- the Silver layer (see Fix 1 — ddl_load_silver.sql).
DROP TABLE IF EXISTS bronze.erp_px_cat_g1v2;
CREATE TABLE bronze.erp_px_cat_g1v2 (
    id              TEXT,
    cat             TEXT,
    subcat          TEXT,
    maintenance     TEXT,
    dwh_load_date   TIMESTAMP DEFAULT CURRENT_TIMESTAMP      
);
