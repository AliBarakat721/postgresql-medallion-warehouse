# SQL Data Warehouse Project

A end-to-end data warehouse built in **PostgreSQL**, following the **Medallion Architecture** (Bronze → Silver → Gold). Raw CRM and ERP CSV exports are ingested, cleaned, conformed, and modeled into a **star schema** ready for BI reporting and analytics.

This project was built and validated locally — every layer below was executed against a live PostgreSQL instance, with row counts and data-quality checks confirmed at each stage.

---

## Architecture

![Architecture Diagram](architecture/Architecture%20Diagram.png)

| Layer | Purpose | Process |
|---|---|---|
| **Bronze** | Raw, untransformed staging data loaded directly from source CSVs | `TRUNCATE` + `COPY`, stamped with `dwh_load_date` |
| **Silver** | Cleansed, standardized, and conformed data | Deduplication, type casting, standardized text, ERP/CRM gender fallback, SCD2 end-date calculation |
| **Gold** | Business-ready star schema | Dimensional model — 4 tables, dimensions loaded before the fact table |

### Sources
- **CRM**: `cust_info.csv`, `prd_info.csv`, `sales_details.csv`
- **ERP**: `CUST_AZ12.csv`, `LOC_A101.csv`, `PX_CAT_G1V2.csv`

---

## Star Schema (Gold Layer)

![Star Schema Diagram](architecture/Star%20Schema%20Diagram.png)

- **`gold.dim_customers`** — 360° customer view, merging CRM demographic data with ERP birthdate and country
- **`gold.dim_products`** — product catalog with SCD Type 2 support (`start_date`, `end_date`, `is_current`)
- **`gold.dim_date`** — generated date dimension (fiscal year, week, weekend flag, etc.)
- **`gold.fact_sales`** — sales transactions, joined to all three dimensions via surrogate keys, with `product_cost` and `profit` calculated at load time

---

## Project Structure

```
.
├── analytics
│   └── business_queries.sql        # 8 BI/reporting queries against the Gold layer
├── architecture
│   ├── Architecture Diagram.png
│   └── Star Schema Diagram.png
├── bronze_layer
│   ├── ddl_bronze.sql               # Schema + table definitions
│   └── proc_load_bronze.sql         # Stored procedure: TRUNCATE + COPY from CSV
├── datasets
│   ├── source_crm/                  # cust_info.csv, prd_info.csv, sales_details.csv
│   └── source_erp/                  # CUST_AZ12.csv, LOC_A101.csv, PX_CAT_G1V2.csv
├── gold_layer
│   ├── ddl_gold.sql                 # Star schema DDL with FK constraints + indexes
│   ├── gold_dim_customers.sql
│   ├── gold_dim_products.sql
│   ├── gold_dim_date.sql
│   └── gold_fact_sales.sql
└── silver_layer
    ├── ddl_load_silver.sql
    ├── loading_crm_cst_info.sql
    ├── loading_crm_prd_info.sql
    ├── loading_crm_sales_details.sql
    ├── loading_erp_cust_az12.sql
    ├── loading_erp_loc_a101.sql
    └── load_erp_px_cat_g1v2.sql
```

---

## How to Run

### Prerequisites
- PostgreSQL 15+ (tested on PostgreSQL 18)
- A database created, e.g. `Data_Warehouse`
- CSV source files placed under `datasets/`

### Execution order

Connect with `psql` and run each script in order:

```sql
-- 1. Bronze Layer — create tables, load raw CSVs
\i bronze_layer/ddl_bronze.sql
\i bronze_layer/proc_load_bronze.sql
CALL bronze.load_bronze();

-- 2. Silver Layer — cleanse & conform
\i silver_layer/ddl_load_silver.sql
\i silver_layer/loading_crm_cst_info.sql
\i silver_layer/loading_crm_prd_info.sql
\i silver_layer/loading_crm_sales_details.sql
\i silver_layer/loading_erp_cust_az12.sql
\i silver_layer/loading_erp_loc_a101.sql
\i silver_layer/load_erp_px_cat_g1v2.sql

-- 3. Gold Layer — build the star schema (dimensions before the fact table)
\i gold_layer/ddl_gold.sql
\i gold_layer/gold_dim_customers.sql
\i gold_layer/gold_dim_products.sql
\i gold_layer/gold_dim_date.sql
\i gold_layer/gold_fact_sales.sql

-- 4. Analytics — run BI queries
\i analytics/business_queries.sql
```

> **Note:** `proc_load_bronze.sql` uses server-side `COPY` with absolute file paths (`/var/lib/postgresql/...`). Update these paths to match your environment, or adapt the procedure to use client-side `\copy` if running PostgreSQL locally without server file access.

---

## Validation Results

Every layer was validated end-to-end against the live dataset:

| Table | Bronze | Silver | Gold |
|---|---:|---:|---:|
| Customers | 18,494 | 18,484 *(deduplicated)* | 18,484 |
| Products | 397 | 397 | 397 |
| Sales | 60,398 | 60,398 | 60,398 |
| ERP Customer Attributes | 18,484 | 18,484 | — |
| ERP Locations | 18,484 | 18,484 | — |
| Product Categories | 37 | 37 | — |
| Date Dimension | — | — | 6,577 days (2010–2028) |

**`gold.fact_sales` referential integrity:**

| Metric | Result |
|---|---:|
| Total records | 60,398 |
| Unmapped customers | 0 |
| Unmapped products | 0 |
| Total revenue | $29,356,250.00 |
| Total profit | $12,203,060.00 |
| Profit margin | 41.57% |

---

## Sample Business Insights

Generated from `analytics/business_queries.sql`:

**Sales by country**

| Country | Customers | Orders | Revenue |
|---|---:|---:|---:|
| United States | 7,482 | 9,230 | $9,162,327.00 |
| Australia | 3,591 | 6,718 | $9,060,172.00 |
| United Kingdom | 1,913 | 3,031 | $3,391,376.00 |
| Germany | 1,780 | 2,484 | $2,894,066.00 |
| France | 1,810 | 2,484 | $2,643,751.00 |
| Canada | 1,571 | 3,375 | $1,977,738.00 |

**Weekday vs. weekend performance**

| Day Type | Orders | Revenue | Avg. Order Value |
|---|---:|---:|---:|
| Weekday | 19,809 | $21,116,127.00 | $487.45 |
| Weekend | 7,850 | $8,240,123.00 | $482.50 |

Additional queries cover monthly sales/profit trends, top 10 products by revenue, top 10 customers by lifetime value, category/subcategory performance, and customer demographic breakdowns.

---

## Data Quality Notes

This project intentionally surfaces data-quality issues rather than silently masking them, consistent with real-world warehouse practice.

- **Silver layer deduplication**: `crm_cust_info` contained duplicate `cst_id` records (10 duplicate rows across 18,494 source rows); the Silver load keeps the most recent record per customer, resulting in 18,484 unique customers.
- **Invalid transaction dates**: 19 rows in `crm_sales_details` had malformed `sls_order_dt` values (zeros or out-of-range integers); these are nulled out during Silver-layer conversion rather than dropped, preserving the row for revenue/profit reporting.
- **Known limitation — unmapped product categories**: 7 of 397 products (all in the *Pedals* subcategory) do not resolve to a category during the Gold load. Root cause: the category-code derivation logic in `loading_crm_prd_info.sql` extracts `CO_PE` from the product name for these items, while the ERP reference table (`erp_px_cat_g1v2`) defines the code as `CO_PD`. This affects 1.8% of products and does not impact customer or revenue metrics — `fact_sales` still resolves 100% of transactions to a valid product record via the SCD Type 2 fallback join.
- **Unmapped countries**: 337 customers (1.8%) have no resolvable country in the ERP location source and are reported as `n/a`.

---

## Tech Stack

- **Database**: PostgreSQL
- **Language**: SQL (DDL, PL/pgSQL stored procedures, analytical queries)
- **Design pattern**: Medallion Architecture (Bronze / Silver / Gold), Kimball-style star schema, SCD Type 2

---

## Author

Built by Ali as a data engineering portfolio project demonstrating ETL pipeline design, data cleansing, dimensional modeling, and SQL analytics on PostgreSQL.
