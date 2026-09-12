-- ===============================================================================
-- File: business_queries.sql
-- Purpose: Analytical queries for BI and reporting on the Gold Layer.
-- ===============================================================================

-- ===============================================================================
-- Query 1: Executive KPI Summary (Overall Business Performance)
-- ===============================================================================
SELECT 
    COUNT(DISTINCT order_number) AS total_orders,
    SUM(quantity) AS total_units_sold,
    ROUND(SUM(total_sales), 2) AS total_revenue,
    ROUND(SUM(profit), 2) AS total_profit,
    ROUND((SUM(profit) / NULLIF(SUM(total_sales), 0)) * 100, 2) AS profit_margin_percentage
FROM gold.fact_sales;

-- ===============================================================================
-- Query 2: Monthly Sales & Profit Trend (Time Intelligence)
-- ===============================================================================
SELECT 
    d.year,
    d.month_number,
    d.month_name,
    COUNT(DISTINCT f.order_number) AS total_orders,
    ROUND(SUM(f.total_sales), 2) AS monthly_revenue,
    ROUND(SUM(f.profit), 2) AS monthly_profit
FROM gold.fact_sales f
JOIN gold.dim_date d ON f.order_date_sk = d.date_sk
GROUP BY d.year, d.month_number, d.month_name
ORDER BY d.year, d.month_number;

-- ===============================================================================
-- Query 3: Top 10 Best-Selling Products by Revenue
-- ===============================================================================
SELECT 
    p.product_name,
    p.category,
    p.subcategory,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.total_sales), 2) AS total_revenue,
    ROUND(SUM(f.profit), 2) AS total_profit
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_sk = p.product_sk
GROUP BY p.product_name, p.category, p.subcategory
ORDER BY total_revenue DESC
LIMIT 10;

-- ===============================================================================
-- Query 4: Top 10 Most Valuable Customers (CLV Overview)
-- ===============================================================================
SELECT 
    c.full_name,
    c.country,
    c.gender,
    COUNT(DISTINCT f.order_number) AS total_orders,
    ROUND(SUM(f.total_sales), 2) AS lifetime_value,
    ROUND(AVG(f.total_sales), 2) AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_sk = c.customer_sk
GROUP BY c.full_name, c.country, c.gender
ORDER BY lifetime_value DESC
LIMIT 10;

-- ===============================================================================
-- Query 5: Sales Performance by Country
-- ===============================================================================
SELECT 
    c.country,
    COUNT(DISTINCT c.customer_sk) AS total_customers,
    COUNT(DISTINCT f.order_number) AS total_orders,
    ROUND(SUM(f.total_sales), 2) AS total_revenue,
    ROUND(SUM(f.profit), 2) AS total_profit
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_sk = c.customer_sk
GROUP BY c.country
ORDER BY total_revenue DESC;

-- ===============================================================================
-- Query 6: Product Category & Subcategory Performance
-- ===============================================================================
SELECT 
    p.category,
    p.subcategory,
    COUNT(DISTINCT f.order_number) AS total_orders,
    SUM(f.quantity) AS units_sold,
    ROUND(SUM(f.total_sales), 2) AS total_revenue,
    ROUND(AVG(f.unit_price), 2) AS avg_unit_price
FROM gold.fact_sales f
JOIN gold.dim_products p ON f.product_sk = p.product_sk
GROUP BY p.category, p.subcategory
ORDER BY total_revenue DESC;

-- ===============================================================================
-- Query 7: Weekend vs. Weekday Sales Analysis
-- ===============================================================================
SELECT 
    CASE WHEN d.is_weekend THEN 'Weekend' ELSE 'Weekday' END AS day_type,
    COUNT(DISTINCT f.order_number) AS total_orders,
    ROUND(SUM(f.total_sales), 2) AS total_revenue,
    ROUND(AVG(f.total_sales), 2) AS avg_order_value
FROM gold.fact_sales f
JOIN gold.dim_date d ON f.order_date_sk = d.date_sk
GROUP BY d.is_weekend;

-- ===============================================================================
-- Query 8: Customer Demographics Breakdown (Gender & Marital Status)
-- ===============================================================================
SELECT 
    c.gender,
    c.marital_status,
    COUNT(DISTINCT c.customer_sk) AS total_customers,
    COUNT(DISTINCT f.order_number) AS total_orders,
    ROUND(SUM(f.total_sales), 2) AS total_revenue,
    ROUND(AVG(f.total_sales), 2) AS avg_spend_per_order
FROM gold.fact_sales f
JOIN gold.dim_customers c ON f.customer_sk = c.customer_sk
GROUP BY c.gender, c.marital_status
ORDER BY total_revenue DESC;
