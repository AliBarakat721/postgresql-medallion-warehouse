--==================================================================
-- Browse the first 10 rows to see the data in general
--==================================================================
SELECT 
    id, 
    cat, 
    subcat, 
    maintenance
FROM bronze.erp_px_cat_g1v2
LIMIT 10;
--==================================================================
-- Check for NULLs or missing values in columns
--==================================================================
select 
	count(*) as total_rows , 
	count(id) as non_null_ids , 
	count(cat) as non_null_cat , 
	count(subcat) as non_null_subcat , 
	count(maintenance ) as non_null_maintenance 
FROM bronze.erp_px_cat_g1v2; 
--==================================================================
-- Ensure that there are no duplicate values in the id
--==================================================================
select 
	id , count(*) as duplicate_num 
from bronze.erp_px_cat_g1v2 
group by id 
having count(*) > 1 ; 
--==================================================================
-- Visibility of unique values for categories (cat and subcat)
--==================================================================
SELECT 
	DISTINCT cat, subcat 
FROM bronze.erp_px_cat_g1v2
ORDER BY cat, subcat;
--==================================================================
-- Checking trailing spaces (Leading / Trailing Spaces)
--==================================================================
SELECT *
FROM bronze.erp_px_cat_g1v2
WHERE id != TRIM(id)
   OR cat != TRIM(cat)
   OR subcat != TRIM(subcat)
   OR maintenance != TRIM(maintenance);
--==================================================================
-- Checking the maintenance column values
--==================================================================
SELECT DISTINCT maintenance, COUNT(*) 
FROM bronze.erp_px_cat_g1v2
GROUP BY maintenance;
-- =======================================================================================
-- Procedure / Script : Load Silver Layer - erp_px_cat_g1v2
-- Description        : Loads product category data from Bronze to Silver without
--                      transformations or cleansing.
-- =======================================================================================


TRUNCATE TABLE silver.erp_px_cat_g1v2;

INSERT INTO silver.erp_px_cat_g1v2 (
    id,
    cat,
    subcat,
    maintenance
)
SELECT
    id,
    cat,
    subcat,
    CASE
        WHEN UPPER(TRIM(maintenance)) = 'YES' THEN TRUE
        WHEN UPPER(TRIM(maintenance)) = 'NO' THEN FALSE
        ELSE NULL
    END AS maintenance
FROM bronze.erp_px_cat_g1v2;

select * from silver.erp_px_cat_g1v2  ; 