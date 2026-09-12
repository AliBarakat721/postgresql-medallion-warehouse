/*
===============================================================================
Load Script: gold.dim_products
===============================================================================
Purpose:
    Consolidate product data from CRM + ERP into a single dimension table.
    Supports SCD Type 2 logic (start_date, end_date, is_current).

Fix Applied:
    Bug — Category join used the wrong column.
          The join compared p.prd_key (e.g. 'BK-M18B-40') directly
          against c.id (e.g. 'BI_MB'), which can never match — prd_key
          is the full product code, not a category code.

          silver.crm_prd_info already derives the correct category
          code in its own cat_id column (e.g. 'BK-M18B-40' -> 'BI_MB'),
          computed during the Silver layer load. The join now uses
          p.cat_id instead of p.prd_key.

    Impact: previously 397/397 products had NULL category/subcategory
            (unmapped_categories = 397). After the fix, products join
            correctly to silver.erp_px_cat_g1v2.
===============================================================================
*/

TRUNCATE TABLE gold.dim_products RESTART IDENTITY CASCADE;

INSERT INTO gold.dim_products (
    prd_id,
    prd_key,
    product_name,
    category,
    subcategory,
    maintenance,
    product_line,
    cost,
    start_date,
    end_date,
    is_current
)
SELECT
    p.prd_id,
    p.prd_key,
    p.prd_nm          AS product_name,
    c.cat             AS category,
    c.subcat          AS subcategory,
    c.maintenance     AS maintenance,
    p.prd_line        AS product_line,
    p.prd_cost        AS cost,
    p.prd_start_dt    AS start_date,
    p.prd_end_dt      AS end_date,
    CASE 
        WHEN p.prd_end_dt IS NULL THEN TRUE 
        ELSE FALSE 
    END               AS is_current
FROM silver.crm_prd_info p
-- join on p.cat_id (pre-derived category code), not p.prd_key
LEFT JOIN silver.erp_px_cat_g1v2 c
    ON TRIM(p.cat_id) = TRIM(c.id);

-- Check results
SELECT 
    COUNT(*)                             AS total_products,
    COUNT(DISTINCT prd_id)               AS unique_prd_ids,
    COUNT(*) FILTER (WHERE is_current)   AS active_products,
    COUNT(*) FILTER (WHERE category IS NULL) AS unmapped_categories
FROM gold.dim_products;
