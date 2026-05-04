--Monthly Cohort Retention — Customer Loyalty Trends

--Cohort analysis tracks groups of customers who made their first purchase in the same month.
--You then follow each group over time to see how many return for a second, third, fourth purchase.
--This is the most important retention metric used at every e-commerce company.

USE shopsense;

-- Step 1: Find first purchase month for each unique customer
-- customer_unique_id is the real customer identifier across multiple orders

SELECT c.customer_unique_id, MIN(
        DATE_FORMAT(
            o.order_purchase_timestamp, '%y-%m'
        )
    ) as cohort_month
FROM orders o
    JOIN customers c ON o.customer_id = c.customer_id
WHERE
    o.order_status NOT IN('cancelled', 'unavailable')
GROUP BY
    c.customer_unique_id;

-- Full cohort retention analysis
WITH
    customer_cohort AS (
        -- Step 1: Each customer's cohort (first purchase month)
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
        -- Step 2: All orders with customer_unique_id attached
        SELECT c.customer_unique_id, DATE_FORMAT(
                o.order_purchase_timestamp, '%Y%m'
            ) AS order_month
        FROM orders o
            JOIN customers c ON o.customer_id = c.customer_id
        WHERE
            o.order_status NOT IN('cancelled', 'unavailable')
    ),
    cohort_data AS (
        -- Step 3: Join to get cohort_month + order_month for each customer
        SELECT co.customer_unique_id, cc.cohort_month, co.order_month,
            -- month_number = 0 means first purchase month, 1 = one month later, etc
            PERIOD_DIFF(
                co.order_month, cc.cohort_month
            ) AS month_number
        FROM
            customer_orders co
            JOIN customer_cohort cc ON co.customer_unique_id = cc.customer_unique_id
    )
    -- Final output: cohort size and retention per month
SELECT
    cohort_month,
    COUNT(
        DISTINCT CASE
            WHEN month_number = 0 THEN customer_unique_id
        END
    ) AS cohort_size,
    COUNT(
        DISTINCT CASE
            WHEN month_number = 1 THEN customer_unique_id
        END
    ) AS month_1,
    COUNT(
        DISTINCT CASE
            WHEN month_number = 2 THEN customer_unique_id
        END
    ) AS month_2,
    COUNT(
        DISTINCT CASE
            WHEN month_number = 3 THEN customer_unique_id
        END
    ) AS month_3,
    COUNT(
        DISTINCT CASE
            WHEN month_number = 4 THEN customer_unique_id
        END
    ) AS month_4,
    COUNT(
        DISTINCT CASE
            WHEN month_number = 5 THEN customer_unique_id
        END
    ) AS month_5,
    COUNT(
        DISTINCT CASE
            WHEN month_number = 6 THEN customer_unique_id
        END
    ) AS month_6
FROM cohort_data
GROUP BY
    cohort_month
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