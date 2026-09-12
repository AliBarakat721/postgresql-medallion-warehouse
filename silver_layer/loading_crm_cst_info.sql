--=============================================
-- Nulls & Empty Strings 
--=============================================
SELECT
    COUNT(*) AS total_rows,

    SUM(CASE WHEN cst_id IS NULL THEN 1 ELSE 0 END) AS null_cst_id,

    SUM(CASE
            WHEN cst_key IS NULL OR TRIM(cst_key) = ''
            THEN 1 ELSE 0
        END) AS null_or_empty_cst_key,

    SUM(CASE
            WHEN cst_firstname IS NULL OR TRIM(cst_firstname) = ''
            THEN 1 ELSE 0
        END) AS null_or_empty_cst_firstname,

    SUM(CASE
            WHEN cst_lastname IS NULL OR TRIM(cst_lastname) = ''
            THEN 1 ELSE 0
        END) AS null_or_empty_cst_lastname,

    SUM(CASE
            WHEN cst_marital_status IS NULL OR TRIM(cst_marital_status) = ''
            THEN 1 ELSE 0
        END) AS null_or_empty_cst_marital_status,

    SUM(CASE
            WHEN cst_gndr IS NULL OR TRIM(cst_gndr) = ''
            THEN 1 ELSE 0
        END) AS null_or_empty_cst_gndr,

    SUM(CASE
            WHEN cst_create_date IS NULL
            THEN 1 ELSE 0
        END) AS null_cst_create_date

FROM bronze.crm_cust_info;

--=============================================
-- Duplicates 
--=============================================
SELECT 
    cst_id, COUNT(*) AS duplicate_count
FROM bronze.crm_cust_info
GROUP BY cst_id 
HAVING COUNT(*) > 1;

--=============================================
-- Reason of Duplicates 
--=============================================
SELECT * 
FROM bronze.crm_cust_info 
WHERE cst_id IN (29473, 29449, 29433, 29466, 29483)
ORDER BY cst_id, cst_create_date DESC;

--=============================================
-- Exact Duplicate Rows 
--=============================================
SELECT 
    cst_id, cst_key, cst_firstname, cst_lastname, 
    cst_marital_status, cst_gndr, cst_create_date,
    COUNT(*) AS exact_row_duplicates
FROM bronze.crm_cust_info 
GROUP BY 
    cst_id, cst_key, cst_firstname, cst_lastname, 
    cst_marital_status, cst_gndr, cst_create_date 
HAVING COUNT(*) > 1; 

--=============================================
-- Distinct Values 
--=============================================
SELECT DISTINCT cst_gndr FROM bronze.crm_cust_info;
SELECT DISTINCT cst_marital_status FROM bronze.crm_cust_info;

--=============================================
-- Negative / Invalid Values 
--=============================================
SELECT * 
FROM bronze.crm_cust_info
WHERE cst_id < 0 
   OR TRIM(cst_key) = ''
   OR TRIM(cst_firstname) = ''
   OR TRIM(cst_lastname) = ''
   OR TRIM(cst_marital_status) = ''
   OR TRIM(cst_gndr) = ''
   OR cst_create_date > CURRENT_DATE;

--=============================================
-- Checking: customers whose CRM gender is null but ERP has a value
--=============================================

SELECT
    c.cst_id,
    c.cst_key,
    c.cst_gndr          AS crm_gender,
    e.gen               AS erp_gender
FROM bronze.crm_cust_info c
LEFT JOIN silver.erp_cust_az12 e         
    ON UPPER(TRIM(c.cst_key)) = e.cid    
WHERE c.cst_gndr IS NULL 
  AND e.gen IS NOT NULL;

--=============================================
-- Cleaning and Loading into Silver Layer
--=============================================
TRUNCATE TABLE silver.crm_cust_info;

WITH deduplicated_data AS (
    SELECT *,
           ROW_NUMBER() OVER (
               PARTITION BY cst_id
               ORDER BY 
                   (CASE WHEN cst_firstname IS NOT NULL THEN 1 ELSE 0 END +
                    CASE WHEN cst_lastname  IS NOT NULL THEN 1 ELSE 0 END +
                    CASE WHEN cst_gndr      IS NOT NULL THEN 1 ELSE 0 END) DESC,
                   cst_create_date DESC NULLS LAST,
                   cst_key
           ) AS rn
    FROM bronze.crm_cust_info
    WHERE cst_id IS NOT NULL
)
INSERT INTO silver.crm_cust_info (
    cst_id,
    cst_key,
    cst_firstname,
    cst_lastname,
    cst_marital_status,
    cst_gndr,
    cst_create_date
)
SELECT
    c.cst_id,
    UPPER(TRIM(c.cst_key))       AS cst_key,
    INITCAP(TRIM(c.cst_firstname)) AS cst_firstname,
    INITCAP(TRIM(c.cst_lastname))  AS cst_lastname,

    CASE
        WHEN UPPER(TRIM(c.cst_marital_status)) = 'S' THEN 'Single'
        WHEN UPPER(TRIM(c.cst_marital_status)) = 'M' THEN 'Married'
        ELSE 'Unknown'
    END AS cst_marital_status,



    CASE
        WHEN UPPER(TRIM(c.cst_gndr)) = 'M'                    THEN 'Male'
        WHEN UPPER(TRIM(c.cst_gndr)) = 'F'                    THEN 'Female'
        WHEN UPPER(TRIM(e.gen)) IN ('MALE',   'M')            THEN 'Male'
        WHEN UPPER(TRIM(e.gen)) IN ('FEMALE', 'F')            THEN 'Female'
        ELSE 'Unknown'
    END AS cst_gndr,

    c.cst_create_date

FROM deduplicated_data c


LEFT JOIN silver.erp_cust_az12 e
    ON UPPER(TRIM(c.cst_key)) = e.cid

WHERE c.rn = 1;

--=============================================
-- Validation 1: No null cst_id
--=============================================
SELECT 
    COUNT(*) AS null_id_count
FROM silver.crm_cust_info 
WHERE cst_id IS NULL;

--=============================================
-- Validation 2: Gender & marital_status standardization
--=============================================
SELECT DISTINCT cst_gndr, cst_marital_status 
FROM silver.crm_cust_info;

--=============================================
-- Validation 3: No leading/trailing spaces in names
--=============================================
SELECT 
    cst_key,
    cst_firstname,
    cst_lastname
FROM silver.crm_cust_info
WHERE cst_firstname LIKE ' %' OR cst_firstname LIKE '% '
   OR cst_lastname  LIKE ' %' OR cst_lastname  LIKE '% ';

--=============================================
-- Validation 4: Record count comparison
--=============================================
SELECT 
    (SELECT COUNT(*) FROM bronze.crm_cust_info WHERE cst_id IS NOT NULL) AS bronze_raw,
    (SELECT COUNT(DISTINCT cst_id) FROM bronze.crm_cust_info WHERE cst_id IS NOT NULL) AS expected_after_dedup,
    (SELECT COUNT(*) FROM silver.crm_cust_info) AS silver_actual;

--=============================================
-- Validation 5: ✅ Gender fallback worked?
--=============================================
SELECT 
    COUNT(*) FILTER (WHERE cst_gndr = 'Unknown') AS unknown_gender_count,
    COUNT(*) FILTER (WHERE cst_gndr = 'Male')    AS male_count,
    COUNT(*) FILTER (WHERE cst_gndr = 'Female')  AS female_count
FROM silver.crm_cust_info;

--=============================================
-- Validation 6: Key consistency
--=============================================
SELECT 
    cst_id, 
    cst_key 
FROM silver.crm_cust_info
WHERE cst_key IS NULL 
   OR cst_key = ''
   OR LENGTH(cst_key) < 5;

--=============================================
-- Validation 7: No customers with both names null
--=============================================
SELECT 
    cst_id, 
    cst_firstname, 
    cst_lastname 
FROM silver.crm_cust_info
WHERE cst_firstname IS NULL AND cst_lastname IS NULL;
