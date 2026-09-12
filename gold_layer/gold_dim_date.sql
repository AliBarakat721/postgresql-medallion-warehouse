/*
===============================================================================
Load Script: gold.dim_date
===============================================================================
Purpose:
    Generate a date dimension spanning from the earliest sale date in
    silver.crm_sales_details through 3 years into the future.

Fixes Applied:
    Bug 1 | INTERVAL syntax     -- INTERVAL '3 years - 1 day' is invalid in
           |                       PostgreSQL. Arithmetic must be applied
           |                       outside the string literal.
           |
    Bug 2 | Trailing spaces     -- TO_CHAR(.., 'Month') pads to 9 characters.
           |                       Use 'FMMonth' / 'FMDay' (Fill Mode) to
           |                       strip padding from month_name & day_name.
           |
    Bug 3 | Missing TRUNCATE    -- Without it, any re-run raises a UNIQUE
           |                       violation on full_date and date_sk.
===============================================================================
*/

-- ============================================================
-- Step 1 | Truncate target table
-- RESTART IDENTITY resets the serial counter on each reload.
-- ============================================================
TRUNCATE TABLE gold.dim_date RESTART IDENTITY CASCADE;


-- ============================================================
-- Step 2 | Generate and insert date records
-- ============================================================
WITH date_range AS (
    SELECT
        COALESCE(MIN(sls_order_dt), '2020-01-01'::DATE) AS min_date,

        -- ✅ FIX Bug 1: separate INTERVAL expressions joined by minus (-)
        --    was: INTERVAL '3 years - 1 day'   → PostgreSQL rejects this
        --    now: INTERVAL '3 years' - INTERVAL '1 day'  → valid
        (
            DATE_TRUNC('year', CURRENT_DATE)
            + INTERVAL '3 years'
            - INTERVAL '1 day'
        )::DATE AS max_date

    FROM silver.crm_sales_details
),

generated_dates AS (
    SELECT
        GENERATE_SERIES(
            date_range.min_date,
            date_range.max_date,
            INTERVAL '1 day'
        )::DATE AS full_date
    FROM date_range
)

INSERT INTO gold.dim_date (
    date_sk,
    full_date,
    year,
    quarter,
    month_number,
    month_name,
    day_of_month,
    day_of_week,
    day_name,
    week_of_year,
    is_weekend,
    fiscal_year,
    fiscal_quarter
)
SELECT
    TO_CHAR(full_date, 'YYYYMMDD')::INTEGER         AS date_sk,
    full_date,
    EXTRACT(YEAR    FROM full_date)::INTEGER         AS year,
    EXTRACT(QUARTER FROM full_date)::INTEGER         AS quarter,
    EXTRACT(MONTH   FROM full_date)::INTEGER         AS month_number,

    -- ✅ FIX Bug 2: 'Month' pads output to 9 chars  →  'January  '
    --               'FMMonth' strips padding          →  'January'
    TO_CHAR(full_date, 'FMMonth')                   AS month_name,

    EXTRACT(DAY     FROM full_date)::INTEGER         AS day_of_month,
    EXTRACT(ISODOW  FROM full_date)::INTEGER         AS day_of_week,   -- 1=Monday, 7=Sunday

    -- ✅ FIX Bug 2: same padding issue applies to 'Day'
    TO_CHAR(full_date, 'FMDay')                     AS day_name,

    EXTRACT(WEEK    FROM full_date)::INTEGER         AS week_of_year,

    CASE
        WHEN EXTRACT(ISODOW FROM full_date) IN (6, 7) THEN TRUE
        ELSE FALSE
    END                                              AS is_weekend,

    -- ============================================================
    -- Fiscal Year Configuration
    -- Current setting: fiscal year mirrors the calendar year.
    -- If your fiscal year starts in July, comment out the line
    -- below and uncomment the CASE block instead.
    --
    -- CASE
    --     WHEN EXTRACT(MONTH FROM full_date) >= 7
    --     THEN EXTRACT(YEAR FROM full_date)::INTEGER + 1
    --     ELSE EXTRACT(YEAR FROM full_date)::INTEGER
    -- END                                           AS fiscal_year,
    -- ============================================================
    EXTRACT(YEAR    FROM full_date)::INTEGER         AS fiscal_year,
    EXTRACT(QUARTER FROM full_date)::INTEGER         AS fiscal_quarter

FROM generated_dates;


-- ============================================================
-- Step 3 | Validation Queries
-- ============================================================

-- 3a. Range & volume check
SELECT
    COUNT(*)             AS total_days,
    MIN(full_date)       AS start_date,
    MAX(full_date)       AS end_date,
    COUNT(DISTINCT year) AS total_years
FROM gold.dim_date;

-- 3b. Trailing-space check  →  must return 0 rows after the fix
SELECT COUNT(*) AS rows_with_trailing_spaces
FROM gold.dim_date
WHERE month_name <> TRIM(month_name)
   OR day_name   <> TRIM(day_name);

-- 3c. Weekend distribution check  →  roughly 28 % of rows should be weekends
SELECT
    is_weekend,
    COUNT(*)                                            AS total_days,
    ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 1) AS pct
FROM gold.dim_date
GROUP BY is_weekend;

-- 3d. Sample output
SELECT
    date_sk,
    full_date,
    year,
    quarter,
    month_name,
    day_name,
    week_of_year,
    is_weekend,
    fiscal_year
FROM gold.dim_date
ORDER BY full_date
LIMIT 10;
