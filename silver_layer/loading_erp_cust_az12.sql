--==================================================================
-- Checking the cid, trailing spaces, and Prefix values (NAS/NAS_)
--================================================================== 
select  
	cid  , 
	case 
		when cid like 'NAS%' then substring (cid from 4 )
		else cid
	end as cleaned_cid 
FROM bronze.erp_cust_az12 limit 10 ; 
--==================================================================
-- Checking the cid, trailing spaces, and Prefix values (NAS/NAS_)
--================================================================== 
SELECT 
	 COUNT(*) FILTER (WHERE bdate > CURRENT_DATE ) AS future_birthdates , 
	 COUNT(*)  FILTER (WHERE bdate < '1920-01-01') AS too_old_birthdates , 
	 COUNT(*) FILTER (WHERE bdate IS NULL ) AS  null_birthdates ,
	 MIN (bdate) AS min_bdate , 
	 MAX(bdate ) AS max_bdate 
from bronze.erp_cust_az12 ; 
-- ============================================================
-- Examine gen values, various symbols, and NULLs
-- ============================================================
SELECT 
	gen ,
	COUNT (*) AS total_count 
FROM bronze.erp_cust_az12 
GROUP  BY gen ; 

-- =======================================================================================
-- Procedure / Script : Load Silver Layer - erp_cust_az12
-- Description        : Cleanses ERP customer demographic data, trims ID prefixes (NAS),
--                      standardizes gender values, and sets invalid birthdates to NULL.
-- =======================================================================================
TRUNCATE TABLE silver.erp_cust_az12;

INSERT INTO silver.erp_cust_az12 (
    cid,
    bdate,
    gen
)
SELECT 
    -- Clean customer ID (remove 'NAS' prefix if exists and trim spaces)
    CASE 
        WHEN TRIM(cid) LIKE 'NAS%' THEN SUBSTRING(TRIM(cid) FROM 4)
        ELSE TRIM(cid)
    END AS cid,

    -- Clean birth date (set future or illogical old dates to NULL)
    CASE 
        WHEN bdate > CURRENT_DATE OR bdate < '1920-01-01' THEN NULL 
        ELSE bdate 
    END AS bdate,

    -- Normalize gender values
    CASE 
        WHEN UPPER(TRIM(gen)) IN ('F', 'FEMALE') THEN 'Female'
        WHEN UPPER(TRIM(gen)) IN ('M', 'MALE') THEN 'Male'
        ELSE 'n/a'
    END AS gen

FROM bronze.erp_cust_az12;
 		
