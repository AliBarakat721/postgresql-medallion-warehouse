--====================================================================
-- null checks 
--====================================================================
select count(*) filter (where sls_ord_num is null ) as null_ord_num , 
	   count(*) filter (where sls_prd_key is null ) as null_prd_key , 
	   count(*) filter (where sls_cust_id is null) as null_cust_id , 
	   count(*) filter (where sls_sales is null ) as null_sales , 
	   count(*) filter (where sls_quantity is null ) as null_quantity , 
	   count(*) filter (where sls_price is null ) as sls_price 
from bronze.crm_sales_details ; 

--====================================================================
-- dates checks  (validity )
--====================================================================
-- Checks dates with zero or wrong length (less than or greater than 8 digits)
select 
	count(*) filter (where length (sls_order_dt :: text) != 8 or sls_order_dt = 0 ) as invalid_order_dates , 
	count(*) filter (where length (sls_ship_dt :: text) != 8  or sls_ship_dt = 0 ) as invalid_ship_dates , 
	count(*) filter (where length (sls_due_dt :: text ) != 8 or sls_due_dt = 0 ) as invalid_due_dates 
FROM bronze.crm_sales_details; 
-- Checking for unreasonable dates (for example, the shipping date is before the order date!)
select * 
from bronze.crm_sales_details 
where sls_ship_dt < sls_order_dt or sls_due_dt < sls_order_dt ; 	

--====================================================================
-- Sales & Price Logic Check
--====================================================================
select 
	count(*) filter (where sls_sales <= 0  ) as invalid_sales , 
	count(*) filter (where sls_quantity <= 0 ) as invalid_quantity , 
	count(*) filter (where sls_price <= 0 ) invalid_price ,

	count (*) filter (where sls_sales != (sls_price * sls_quantity )) AS mismatch_calc 
from bronze.crm_sales_details ; 
--====================================================================
-- Check the sls_prd_key and spaces (Trimming Check)
--====================================================================
select distinct 
	sls_prd_key 
from bronze.crm_sales_details 
where sls_prd_key like '% ' or sls_prd_key like ' %' limit 10 ; 

/* 
In order to know the nature of the 19 incorrect dates and the 20 records of conflicting accounts, run this simple query and show me a screen of the results:
*/ 
select 
	sls_order_dt , 
	sls_ship_dt , 
	sls_due_dt 
from bronze.crm_sales_details 
where length (sls_order_dt :: text) != 8 OR sls_order_dt is null ; 
/* 
Explore mismatched calculations and NULLs in sales and prices
*/ 
select 
	sls_order_dt , 
	sls_ship_dt , 
	sls_due_dt 
from bronze.crm_sales_details
where sls_sales != (sls_quantity * sls_price ) OR 
	  sls_sales is null or 
	  sls_price is null or 
	  sls_sales <= 0 or 
	  sls_price <= 0 ; 
	  
-- =======================================================================================
-- Procedure / Script : Load Silver Layer - crm_sales_details
-- Description        : Cleanses sales transactions, handles invalid/missing dates by 
--                      deriving order_dt from ship_dt (-7 days), converts integer dates 
--                      to DATE type, and fixes financial metrics (sales, price, quantity).
-- =======================================================================================
TRUNCATE TABLE silver.crm_sales_details;

INSERT INTO silver.crm_sales_details (
    sls_ord_num, 
    sls_prd_key, 
    sls_cust_id, 
    sls_order_dt, 
    sls_ship_dt, 
    sls_due_dt, 
    sls_sales, 
    sls_quantity, 
    sls_price 
) 
WITH cleaned_sales AS (
    SELECT 
        -- Clean string spaces 
        TRIM(sls_ord_num) AS sls_ord_num, 
        TRIM(sls_prd_key) AS sls_prd_key, 
        sls_cust_id, 
        
        -- Date handling & conversion (YMD int to date)
        -- Ship date conversion 
        CASE 
            WHEN LENGTH(sls_ship_dt::TEXT) = 8 
                THEN TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD')
            ELSE NULL 
        END AS sls_ship_dt, 
        
        -- Due date conversion (تم تصحيح اسم العمود هنا)
        CASE 
            WHEN LENGTH(sls_due_dt::TEXT) = 8 
                THEN TO_DATE(sls_due_dt::TEXT, 'YYYYMMDD')
            ELSE NULL 
        END AS sls_due_dt, 
        
        -- Derive order date if invalid (0, short length, or null) by subtracting 7 days from ship date 
        CASE 
            -- تم تصحيح sls_order_dt هنا
            WHEN LENGTH(sls_order_dt::TEXT) = 8 AND sls_order_dt != 0 
                THEN TO_DATE(sls_order_dt::TEXT, 'YYYYMMDD')
            WHEN LENGTH(sls_ship_dt::TEXT) = 8 
                THEN TO_DATE(sls_ship_dt::TEXT, 'YYYYMMDD') - INTERVAL '7 days'
            ELSE NULL 
        END::DATE AS sls_order_dt, 
        
        -- Raw financial columns for processing 
        sls_sales, 
        sls_quantity, 
        sls_price
    FROM bronze.crm_sales_details 
)
SELECT 
    sls_ord_num, 
    sls_prd_key, 
    sls_cust_id, 
    sls_order_dt, 
    sls_ship_dt, 
    sls_due_dt, 
    
    -- Correct sales 
    CASE 
        WHEN sls_sales IS NULL OR sls_sales <= 0 OR sls_sales != (sls_quantity * COALESCE(sls_price, 0))
            THEN sls_quantity * ABS(COALESCE(sls_price, sls_sales / NULLIF(sls_quantity, 0)))
        ELSE sls_sales 
    END AS sls_sales, 
    
    sls_quantity,

    -- Correct price
    CASE 
        WHEN sls_price IS NULL OR sls_price <= 0 
            THEN sls_sales / NULLIF(sls_quantity, 0)
        ELSE sls_price 
    END AS sls_price

FROM cleaned_sales;

