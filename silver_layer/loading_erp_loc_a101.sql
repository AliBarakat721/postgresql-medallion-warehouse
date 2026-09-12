--==================================================================
-- Check the CID and extra spaces or symbols (such as the dash '-')
--==================================================================
SELECT 
	REPLACE (cid , '-' , '') AS cleaned_cid 
FROM bronze.erp_loc_a101  LIMIT 10 ; 

--==================================================================
-- Check the names of countries that are repeated in different forms or abbreviations and NULLs
--==================================================================
SELECT
	cntry , 
	COUNT(*) as total_count 
FROM bronze.erp_loc_a101 
group by cntry 
order by total_count  desc ; 

--==================================================================
-- Check for extra spaces in the country name
--==================================================================
select * 
FROM bronze.erp_loc_a101  
WHERE cntry LIKE ' %' OR cntry LIKE '% '; 
-- =======================================================================================
-- Procedure / Script : Load Silver Layer - erp_loc_a101
-- Description        : Cleanses customer location data, removes dashes from CID, 
--                      and standardizes country names to full country names.
-- ======================================================================================= 
TRUNCATE TABLE silver.erp_loc_a101 ; 

INSERT INTO silver.erp_loc_a101  (
	cid , 
	cntry 
) select 
-- clean CID : remove and trim spaces 
	TRIM (REPLACE (cid , '-' , '')) AS cid , 
-- Standardize Country Names & handle NULLs / Empty strings
	CASE 
		WHEN UPPER (TRIM (cntry)) IN ('US', 'USA', 'UNITED STATES') THEN 'United States' 
		WHEN UPPER (TRIM (cntry )) IN ('DE', 'GERMANY') THEN 'Germany' 
		WHEN UPPER(TRIM (cntry )) IN ('UK', 'UNITED KINGDOM') THEN 'United Kingdom' 
		WHEN TRIM (cntry) IS NULL OR TRIM(cntry) = '' THEN 'n/a'
		ELSE TRIM(cntry) 
	END AS cntry 
FROM bronze.erp_loc_a101; 


SELECT DISTINCT cntry, COUNT(*) 
FROM silver.erp_loc_a101 
GROUP BY cntry;

		





	