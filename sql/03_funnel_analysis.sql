-- ══════════════════════════════════════════════════════════════════════════════
-- FILE: 03_funnel_analysis.sql
-- PURPOSE: Compute funnel metrics and delivery performance by region and category
-- KEY METRICS: funnel conversion stages, delivered_on_time %, late_rate_pct,
--             avg_review_score
-- BUSINESS QUESTION: Where in the order funnel do we lose customers and which
--                   categories/states have delivery or quality issues?
-- USAGE: Run after 01_schema_setup.sql to ensure delivery_delay_days and
--        order_month columns exist for analysis
-- ══════════════════════════════════════════════════════════════════════════════

USE shopsense;

-- ──────────────────────────────────────────────────────────────────────────────
-- SECTION 1: OVERALL FUNNEL SUMMARY
-- ──────────────────────────────────────────────────────────────────────────────
-- This aggregate shows counts at each major stage from order to delivery and
-- the percentage of orders reaching each stage (useful for drop-off analysis).
SELECT
    COUNT(*) AS total_orders,
    SUM(CASE WHEN order_status NOT IN('cancelled','unavailable') THEN 1 ELSE 0 END) AS valid_orders,
    SUM(CASE WHEN order_approved_at IS NOT NULL THEN 1 ELSE 0 END) AS payment_confirmed,
    SUM(CASE WHEN order_delivered_carrier_date IS NOT NULL THEN 1 ELSE 0 END) AS shipped,
    SUM(CASE WHEN order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END) AS delivered,
    SUM(CASE WHEN order_delivered_customer_date IS NOT NULL AND delivery_delay_days <= 0 THEN 1 ELSE 0 END) AS delivered_on_time,
    -- Drop-off rates at each stage
    ROUND(100.0 * SUM(CASE WHEN order_approved_at IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_payment_confirmed,
    ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_delivered,
    ROUND(100.0 * SUM(CASE WHEN order_delivered_customer_date IS NOT NULL AND delivery_delay_days <= 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS pct_on_time
FROM orders;


-- ──────────────────────────────────────────────────────────────────────────────
-- SECTION 2: FUNNEL BREAKDOWN BY CUSTOMER STATE
-- ──────────────────────────────────────────────────────────────────────────────
-- Useful for identifying states with chronic delivery or quality problems
SELECT
    c.customer_state AS state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(o.delivery_delay_days), 1) AS avg_delay_days,
    SUM(CASE WHEN o.delivery_delay_days > 0 THEN 1 ELSE 0 END) AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN o.delivery_delay_days > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS late_rate_pct,
    ROUND(AVG(r.review_score), 1) AS avg_review_score
FROM orders o
JOIN customers c ON o.customer_id = c.customer_id
LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_delivered_customer_date IS NOT NULL
GROUP BY c.customer_state
ORDER BY late_rate_pct DESC;


-- ──────────────────────────────────────────────────────────────────────────────
-- SECTION 3: CATEGORY-LEVEL FUNNEL & QUALITY ANALYSIS
-- ──────────────────────────────────────────────────────────────────────────────
SELECT
    COALESCE(t.product_category_name_english, p.product_category_name) AS category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_price,
    ROUND(AVG(o.delivery_delay_days), 1) AS avg_delay_days,
    SUM(CASE WHEN o.delivery_delay_days > 0 THEN 1 ELSE 0 END) AS late_orders,
    ROUND(100.0 * SUM(CASE WHEN o.delivery_delay_days > 0 THEN 1 ELSE 0 END) / COUNT(*), 1) AS late_rate_pct,
    ROUND(AVG(r.review_score), 1) AS avg_review_score
FROM orders o
JOIN order_items oi ON o.order_id = oi.order_id
JOIN products p ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE o.order_status NOT IN('cancelled', 'unavailable')
GROUP BY category
HAVING total_orders > 100
ORDER BY late_rate_pct DESC
LIMIT 20;

-- Note: Consider joining seller performance if seller-level issues are suspected
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_price,
    ROUND(AVG(o.delivery_delay_days), 1) AS avg_delay_days,
    -- Use COUNT(DISTINCT) to avoid counting the same late order multiple times
    COUNT(
        DISTINCT CASE
            WHEN o.delivery_delay_days > 0 THEN o.order_id
        END
    ) AS late_orders,
    ROUND(
        100.0 * COUNT(
            DISTINCT CASE
                WHEN o.delivery_delay_days > 0 THEN o.order_id
            END
        ) / COUNT(DISTINCT o.order_id),
        1
    ) AS late_rate_pct,
    ROUND(AVG(r.avg_score), 2) AS avg_review_score
FROM
    orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    LEFT JOIN order_reviews r ON o.order_id = r.order_id
WHERE
    o.order_status NOT IN('canceled', 'unavailable')
GROUP BY
    category
HAVING
    total_orders > 100
ORDER BY late_rate_pct DESC
LIMIT 20;

-- Root cause: state + category combination driving delays
SELECT
    c.customer_state,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(AVG(o.delivery_delay_days), 1) AS avg_delay_days,
    ROUND(
        100.0 * SUM(
            CASE
                WHEN o.delivery_delay_days > 0 THEN 1
                ELSE 0
            END
        ) / COUNT(DISTINCT o.order_id),
        1
    ) AS late_rate_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM
    orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE
    o.order_delivered_customer_date IS NOT NULL
GROUP BY
    c.customer_state,
    category
HAVING
    total_orders > 30
ORDER BY late_rate_pct DESC
LIMIT 25;

-- Monthly business performance trend
SELECT
    DATE_FORMAT(
        o.order_purchase_timestamp,
        '%Y-%m'
    ) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    COUNT(DISTINCT c.customer_unique_id) AS unique_customers,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(AVG(oi.price), 2) AS avg_order_value,
    ROUND(AVG(r.review_score), 2) AS avg_review_score,
    SUM(
        CASE
            WHEN o.delivery_delay_days > 0 THEN 1
            ELSE 0
        END
    ) AS late_orders
FROM
    orders o
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE
    o.order_status NOT IN('canceled', 'unavailable')
GROUP BY
    month
ORDER BY month