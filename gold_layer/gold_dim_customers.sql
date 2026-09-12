/*
===============================================================================
Load Script: gold.dim_customers
===============================================================================
Purpose:
    Consolidate customer data from CRM + ERP into a single 360° dimension.
===============================================================================
*/

-- 1. Truncate target table
TRUNCATE TABLE gold.dim_customers RESTART IDENTITY CASCADE;

-- 2. Pre-Load Integrity Check
SELECT cid, COUNT(*) AS duplicate_count
FROM silver.erp_cust_az12
GROUP BY cid
HAVING COUNT(*) > 1;

SELECT cid, COUNT(*) AS duplicate_count
FROM silver.erp_loc_a101
GROUP BY cid
HAVING COUNT(*) > 1;

-- 3. Load Customer Dimension with TRIM alignment
INSERT INTO gold.dim_customers (
    cst_id,
    cst_key,
    full_name,
    gender,
    marital_status,
    birth_date,
    country,
    registration_date
)
SELECT
    c.cst_id,
    c.cst_key,

    TRIM(
        CONCAT(
            COALESCE(c.cst_firstname, ''),
            ' ',
            COALESCE(c.cst_lastname, '')
        )
    ) AS full_name,

    c.cst_gndr           AS gender,
    c.cst_marital_status AS marital_status,
    e.bdate              AS birth_date,
    COALESCE(l.cntry, 'n/a') AS country,
    c.cst_create_date    AS registration_date

FROM silver.crm_cust_info c


LEFT JOIN silver.erp_cust_az12 e
    ON TRIM(c.cst_key) = TRIM(e.cid)

LEFT JOIN silver.erp_loc_a101 l
    ON TRIM(c.cst_key) = TRIM(l.cid);

-- 4. Validation
SELECT
    COUNT(*)                             AS total_rows,
    COUNT(DISTINCT cst_id)               AS unique_customers,
    COUNT(*) - COUNT(DISTINCT cst_id)    AS duplicate_check,
    COUNT(*) FILTER (WHERE gender  = 'Unknown')  AS unknown_gender,
    COUNT(*) FILTER (WHERE country = 'n/a')      AS unknown_country
FROM gold.dim_customers;
