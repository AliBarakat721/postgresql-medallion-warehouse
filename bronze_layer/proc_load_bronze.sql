/*
===============================================================================
Stored Procedure: Load Bronze Layer (Source -> Bronze)
===============================================================================
Script Purpose:
    This stored procedure loads data into the 'bronze' schema from external CSV files. 
    It performs the following actions:
    - Truncates the bronze tables before loading data.
    - Uses the `COPY` command to load data from csv Files to bronze tables.

Parameters:
    None. 
      This stored procedure does not accept any parameters or return any values.

Usage Example:
    CALL bronze.load_bronze();
===============================================================================
*/

CREATE OR REPLACE PROCEDURE bronze.load_bronze()
LANGUAGE plpgsql
AS 
$$
DECLARE 
    start_time TIMESTAMP ;
    end_time TIMESTAMP ;
    batch_start_time TIMESTAMP ;
    batch_end_time TIMESTAMP ; 
BEGIN 
    batch_start_time := clock_timestamp() ;

    RAISE NOTICE '-----------------------------';
    RAISE NOTICE 'Loading Bronze Layer';
    RAISE NOTICE '-----------------------------';

    RAISE NOTICE 'Loading CRM Tables' ; 
    
---------------------------------------------------------
-- crm_cust_info
---------------------------------------------------------
    start_time := clock_timestamp();
    RAISE NOTICE 'Truncating Table: bronze.crm_cust_info';
    
    TRUNCATE TABLE bronze.crm_cust_info;
    COPY bronze.crm_cust_info (cst_id, cst_key, cst_firstname, cst_lastname, cst_marital_status, cst_gndr, cst_create_date)
    FROM '/var/lib/postgresql/datawarehouse/source_crm/cust_info.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );
    
    end_time := clock_timestamp() ;
    RAISE NOTICE 'Duration: % seconds',
        EXTRACT(EPOCH FROM (end_time - start_time));
        
---------------------------------------------------------
-- crm_prd_info
---------------------------------------------------------
    start_time := clock_timestamp();
    RAISE NOTICE 'Truncating Table: bronze.crm_prd_info';
    
    TRUNCATE TABLE bronze.crm_prd_info;
    COPY bronze.crm_prd_info (prd_id, prd_key, prd_nm, prd_cost, prd_line, prd_start_dt, prd_end_dt)
    FROM '/var/lib/postgresql/datawarehouse/source_crm/prd_info.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );

    end_time := clock_timestamp(); 
    RAISE NOTICE 'Duration : % seconds' ,
        EXTRACT (EPOCH FROM (end_time - start_time)) ; 
---------------------------------------------------------
-- crm_sales_details 
---------------------------------------------------------
    start_time := clock_timestamp() ; 
    RAISE NOTICE 'Truncating Table: bronze.crm_sales_details';
   
    TRUNCATE TABLE bronze.crm_sales_details; 
    COPY bronze.crm_sales_details (sls_ord_num, sls_prd_key, sls_cust_id, sls_order_dt, sls_ship_dt, sls_due_dt, sls_sales, sls_quantity, sls_price)
    FROM '/var/lib/postgresql/datawarehouse/source_crm/sales_details.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );

    end_time := clock_timestamp(); 
    RAISE NOTICE 'Duration : % seconds' ,
        EXTRACT (EPOCH FROM (end_time - start_time)) ; 
---------------------------------------------------------
-- erp_cust_az12
---------------------------------------------------------
    start_time := clock_timestamp();
    RAISE NOTICE 'truncate table: bronze.erp_cust_az12' ;
    
    TRUNCATE TABLE bronze.erp_cust_az12;
    COPY bronze.erp_cust_az12 (cid, bdate, gen)
    FROM '/var/lib/postgresql/datawarehouse/source_erp/CUST_AZ12.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );
    
    end_time := clock_timestamp(); 
    RAISE NOTICE 'Duration : % seconds' ,
        EXTRACT (EPOCH FROM (end_time - start_time)) ; 
---------------------------------------------------------
-- erp_loc_a101
---------------------------------------------------------
    start_time := clock_timestamp ();
    RAISE NOTICE 'truncate table: bronze.erp_loc_a101' ; 
    
    TRUNCATE TABLE bronze.erp_loc_a101;
    COPY bronze.erp_loc_a101 (cid, cntry)
    FROM '/var/lib/postgresql/datawarehouse/source_erp/LOC_A101.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );
    
    end_time := clock_timestamp(); 
    RAISE NOTICE 'Duration : % seconds' ,
        EXTRACT (EPOCH FROM (end_time - start_time)) ; 
---------------------------------------------------------
-- erp_px_cat_g1v2
---------------------------------------------------------
    start_time := clock_timestamp() ; 
    RAISE NOTICE 'truncate table: bronze.erp_px_cat_g1v2';
    
    TRUNCATE TABLE bronze.erp_px_cat_g1v2;
    COPY bronze.erp_px_cat_g1v2 (id, cat, subcat, maintenance)
    FROM '/var/lib/postgresql/datawarehouse/source_erp/PX_CAT_G1V2.csv'
    WITH (
        FORMAT csv,
        HEADER true,
        DELIMITER ','
    );

    end_time := clock_timestamp(); 
    RAISE NOTICE 'Duration : % seconds' ,
        EXTRACT (EPOCH FROM (end_time - start_time)) ; 
        
---------------------------------------------------------
-- FINISH
---------------------------------------------------------
    batch_end_time := clock_timestamp ( ) ;
    RAISE NOTICE '===========================================';
    RAISE NOTICE 'Bronze Layer Loaded Successfully';
    RAISE NOTICE 'Total Duration: % seconds',
        EXTRACT(EPOCH FROM (batch_end_time - batch_start_time));
    RAISE NOTICE '===========================================';

EXCEPTION
    WHEN OTHERS THEN

        RAISE NOTICE '===========================================';
        RAISE NOTICE 'ERROR OCCURRED DURING LOADING';
        RAISE NOTICE 'SQLSTATE : %', SQLSTATE;
        RAISE NOTICE 'MESSAGE  : %', SQLERRM;
        RAISE NOTICE '===========================================';

END;
$$;
