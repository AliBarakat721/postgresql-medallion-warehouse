-- ============================================================
-- Duplicates & Trim Checks 
-- ============================================================
SELECT 
	prd_id , Count (*) as duplicate_count 
from bronze.crm_prd_info 
group by prd_id 
Having Count(*) > 1 or prd_id is null ; 
-- ============================================================
-- Check for extra spaces in prd_nm and prd_key
-- ============================================================
select 
	prd_id , 
	prd_key , 
	prd_nm 
from bronze.crm_prd_info 
where prd_nm like ' %'  OR  prd_nm like '% ' 
	or prd_key like ' %'  OR  prd_key like '% ' ; 
-- ============================================================
-- Pattern Analysis prd_key 
-- ============================================================
select 
	length (prd_key) as ley_length ,  
	Count (*) as count_records , 
	Min (prd_key) as sample_min , 
	max (prd_key) as sample_max 
from bronze.crm_prd_info 
group by length (prd_key) ; 
--  Show a sample of the prd_key to understand the commas (-)
select Distinct 
	substring (prd_key , 1 , 6 ) as extracted_prefix , 
	prd_key 
from bronze.crm_prd_info  limit 10 ; 
-- ============================================================
-- Categorical Check prd_line  
-- ============================================================
-- Knowing all the unique values written in prd_line (in order to determine the CASE WHEN)
select distinct 
	prd_line , 
	count(*) as total_count 
from bronze.crm_prd_info 
group by prd_line ; 

-- Negative or NULL price list
select 
	count (*) filter (where prd_cost is null) as null_costs , 
	count (*) filter (where prd_cost < 0 ) as negative_costs  , 
	min(prd_cost ) as min_cost , 
	max(prd_cost ) as max_cost 
from bronze.crm_prd_info ; 
-- ============================================================
-- Overlapping (Date Logic Check) 
-- ============================================================
-- Checking for illogical dates (the end date is earlier than the start date)
select * from bronze.crm_prd_info 
where prd_end_dt < prd_start_dt ; 
-- Check for missing dates or zero values
select 
	count (*) filter (where prd_start_dt is null ) as null_start_dates , 
	count (*) filter (where prd_end_dt is null )  as null_end_dates 
from bronze.crm_prd_info ; 
-- =======================================================================================
-- Procedure / Script : Load Silver Layer - crm_prd_info
-- Description        : Cleanses and transforms product data from Bronze CRM table.
--                      Handles null values, standardizes text format, extracts category
--                      keys, and recalculates invalid end-dates using SCD Type 2 logic.
-- =======================================================================================
-- 1. truncate target table in silver schema 
truncate table silver.crm_prd_info  ; 
-- 2. insert cleaned and transformed data 
insert  into silver.crm_prd_info (
	prd_id , 
	cat_id , 
	prd_key , 
	prd_nm , 
	prd_cost , 
	prd_line , 
	prd_start_dt , 
	prd_end_dt 
) select 
		prd_id , 
		-- extract category ID 
		REPLACE (substring (prd_key from 1 for 5) , '-' , '_') as cat_id , 
		-- extract product key 
		substring (prd_key from 7 ) as prd_key , 
		-- clean prd_nm 
		trim (prd_nm) as prd_nm  , 
		-- replace null cost with 0 
		coalesce (prd_cost , 0 ) as prd_cost , 
		-- normize product line 
		CASE 
			when upper(trim (prd_line)) = 'M' then 'Mountain'
			when upper(trim(prd_line)) = 'R' then 'Road'
			when upper(trim(prd_line)) = 'S' then 'Other Sales' 
			when upper (trim(prd_line)) = 'T' then 'Touring'
			else 'n/a' 
		End as prd_line , 
		-- convert start date 
		cast (prd_start_dt as Date ) as prd_start_dt , 
		-- end date = one day before next start date 
		(
			lead(prd_start_dt) over 
				(partition by substring(prd_key from 7) order by prd_start_dt ) - interval '1 day'
		):: date as prd_end_dt 
	from bronze.crm_prd_info ; 

select * from silver.crm_prd_info limit 10 ; 
-- In the world of data warehousing, 
-- some schools prefer to leave the most recent record with NULL as an indication that 
-- this product is current and active (Active Record), 
-- and other schools prefer to leave a very distant imaginary date such as '9999-12-31'.