-- ══════════════════════════════════════════════════════════════════════════════
-- FILE: 02_cohort_analysis.sql
-- PURPOSE: Calculate monthly cohort retention to track customer loyalty over time
-- KEY METRICS: cohort_size, month_1..month_6 repeat counts, retention %
-- BUSINESS QUESTION: Are customers becoming more or less loyal over time?
-- USAGE: Run this script after 01_schema_setup.sql (which creates order_month)
-- NOTES: Excludes cancelled/unavailable orders. Uses customer_unique_id as the
--        primary customer identifier across multiple orders.
-- ══════════════════════════════════════════════════════════════════════════════

USE shopsense;

-- ──────────────────────────────────────────────────────────────────────────────
-- SECTION 1: SIMPLE COHORT CHECK (optional quick validation)
-- ──────────────────────────────────────────────────────────────────────────────
-- This query returns the cohort_month for each customer (first purchase month).
-- Useful for validating that cohort_month values exist before running the full
-- cohort retention pipeline.
SELECT
    c.customer_unique_id,
    MIN(DATE_FORMAT(o.order_purchase_timestamp, '%Y-%m')) AS cohort_month
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
WHERE o.order_status NOT IN('cancelled', 'unavailable')
GROUP BY c.customer_unique_id;


-- ──────────────────────────────────────────────────────────────────────────────
-- SECTION 2: FULL COHORT RETENTION PIPELINE (recommended)
-- ──────────────────────────────────────────────────────────────────────────────
-- Approach:
-- 1) customer_cohort: find each customer's acquisition month
-- 2) customer_orders: list all orders with their order_month
-- 3) cohort_data: compute month_number (months since acquisition)
-- 4) FINAL: aggregate distinct customers per month_number per cohort
WITH customer_cohort AS (
    SELECT
        c.customer_unique_id,
        MIN(DATE_FORMAT(o.order_purchase_timestamp, '%Y%m')) AS cohort_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status NOT IN('cancelled', 'unavailable')
    GROUP BY c.customer_unique_id
),
customer_orders AS (
    SELECT
        c.customer_unique_id,
        DATE_FORMAT(o.order_purchase_timestamp, '%Y%m') AS order_month
    FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
    WHERE o.order_status NOT IN('cancelled', 'unavailable')
),
cohort_data AS (
    SELECT
        co.customer_unique_id,
        cc.cohort_month,
        co.order_month,
        PERIOD_DIFF(co.order_month, cc.cohort_month) AS month_number
    FROM customer_orders co
    JOIN customer_cohort cc ON co.customer_unique_id = cc.customer_unique_id
)
SELECT
    cohort_month,
    COUNT(DISTINCT CASE WHEN month_number = 0 THEN customer_unique_id END) AS cohort_size,
    COUNT(DISTINCT CASE WHEN month_number = 1 THEN customer_unique_id END) AS month_1,
    COUNT(DISTINCT CASE WHEN month_number = 2 THEN customer_unique_id END) AS month_2,
    COUNT(DISTINCT CASE WHEN month_number = 3 THEN customer_unique_id END) AS month_3,
    COUNT(DISTINCT CASE WHEN month_number = 4 THEN customer_unique_id END) AS month_4,
    COUNT(DISTINCT CASE WHEN month_number = 5 THEN customer_unique_id END) AS month_5,
    COUNT(DISTINCT CASE WHEN month_number = 6 THEN customer_unique_id END) AS month_6
FROM cohort_data
GROUP BY cohort_month
ORDER BY cohort_month;

-- Retention rate % version of the cohort table
WITH
    customer_cohort AS (
        SELECT c.customer_unique_id, MIN(
                DATE_FORMAT(
                    o.order_purchase_timestamp, '%Y%m'
                )
            ) as cohort_month
        FROM orders o
            JOIN customers c ON o.customer_id = c.customer_id
        WHERE
            o.order_status NOT IN('cancelled', 'unavailable')
        GROUP BY
            c.customer_unique_id
    ),
    customer_orders AS (
        SELECT c.customer_unique_id, DATE_FORMAT(
                o.order_purchase_timestamp, '%Y%m'
            ) AS order_month
        FROM orders o
            JOIN customers c ON o.customer_id = c.customer_id
        WHERE
            o.order_status NOT IN('cancelled', 'unavailable')
    ),
    cohort_data AS (
        SELECT co.customer_unique_id, cc.cohort_month, co.order_month, PERIOD_DIFF(
                co.order_month, cc.cohort_month
            ) AS month_number
        FROM
            customer_orders co
            JOIN customer_cohort cc ON co.customer_unique_id = cc.customer_unique_id
    )
SELECT
    cohort_month,
    COUNT(
        DISTINCT CASE
            WHEN month_number = 0 THEN customer_unique_id
        END
    ) AS cohort_size,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN month_number = 1 THEN customer_unique_id
            END
        ) / COUNT(
            DISTINCT CASE
                WHEN month_number = 0 THEN customer_unique_id
            END
        ),
        1
    ) AS pct_month_1,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN month_number = 2 THEN customer_unique_id
            END
        ) / COUNT(
            DISTINCT CASE
                WHEN month_number = 0 THEN customer_unique_id
            END
        ),
        1
    ) AS pct_month_2,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN month_number = 3 THEN customer_unique_id
            END
        ) / COUNT(
            DISTINCT CASE
                WHEN month_number = 0 THEN customer_unique_id
            END
        ),
        1
    ) AS pct_month_3,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN month_number = 4 THEN customer_unique_id
            END
        ) / COUNT(
            DISTINCT CASE
                WHEN month_number = 0 THEN customer_unique_id
            END
        ),
        1
    ) AS pct_month_4,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN month_number = 5 THEN customer_unique_id
            END
        ) / COUNT(
            DISTINCT CASE
                WHEN month_number = 0 THEN customer_unique_id
            END
        ),
        1
    ) AS pct_month_5,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN month_number = 6 THEN customer_unique_id
            END
        ) / COUNT(
            DISTINCT CASE
                WHEN month_number = 0 THEN customer_unique_id
            END
        ),
        1
    ) AS pct_month_6
FROM cohort_data
GROUP BY
    cohort_month
ORDER BY cohort_month;

-- Revenue contribution by cohort
WITH
    customer_cohorts AS (
        SELECT c.customer_unique_id, MIN(
                DATE_FORMAT(
                    o.order_purchase_timestamp, '%Y-%m'
                )
            ) AS cohort_month
        FROM orders o
            JOIN customers c ON o.customer_id = c.customer_id
        WHERE
            o.order_status NOT IN('canceled', 'unavailable')
        GROUP BY
            c.customer_unique_id
    )
SELECT
    cc.cohort_month,
    COUNT(DISTINCT c.customer_unique_id) AS cohort_size,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT c.customer_unique_id),
        2
    ) AS revenue_per_customer
FROM
    orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customer_cohorts cc ON c.customer_unique_id = cc.customer_unique_id
WHERE
    o.order_status NOT IN('canceled', 'unavailable')
GROUP BY
    cc.cohort_month
ORDER BY cc.cohort_month;

-- Revenue contribution by cohort
WITH
    customer_cohorts AS (
        SELECT c.customer_unique_id, MIN(
                DATE_FORMAT(
                    o.order_purchase_timestamp, '%Y-%m'
                )
            ) AS cohort_month
        FROM orders o
            JOIN customers c ON o.customer_id = c.customer_id
        WHERE
            o.order_status NOT IN('canceled', 'unavailable')
        GROUP BY
            c.customer_unique_id
    )
SELECT
    cc.cohort_month,
    COUNT(DISTINCT c.customer_unique_id) AS cohort_size,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(
        SUM(oi.price) / COUNT(DISTINCT c.customer_unique_id),
        2
    ) AS revenue_per_customer
FROM
    orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customer_cohorts cc ON c.customer_unique_id = cc.customer_unique_id
WHERE
    o.order_status NOT IN('canceled', 'unavailable')
GROUP BY
    cc.cohort_month
ORDER BY cc.cohort_month;