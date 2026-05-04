-- Step 1: Base RFM metrics per customer
-- Reference date: use the latest order date in the dataset as 'today'

WITH
    reference_date AS (
        SELECT MAX(order_purchase_timestamp) AS max_date
        FROM orders
    ),
    rfm_base AS (
        SELECT
            c.customer_unique_id,
            c.customer_state,
            -- Recency: days since last purchase (lower = more recent = better)        
            DATEDIFF(
                rd.max_date,
                MAX(o.order_purchase_timestamp)
            ) AS recency_days,
            -- Frequency: total number of orders       
            COUNT(DISTINCT o.order_id) AS frequency,
            -- Monetary: total spent
            ROUND(SUM(oi.price), 2) AS monetary_value
        FROM
            orders o
            JOIN customers c ON c.customer_id = o.customer_id
            JOIN order_items oi ON oi.order_id = o.order_id
            CROSS JOIN reference_date rd
        GROUP BY
            c.customer_unique_id,
            c.customer_state,
            rd.max_date
    )
SELECT *
FROM rfm_base
ORDER BY monetary_value DESC
LIMIT 20;

-- Step 2: Score each dimension 1-5 using NTILE
WITH
    reference_date AS (
        SELECT MAX(order_purchase_timestamp) AS max_date
        FROM orders
    ),
    rfm_base AS (
        SELECT
            c.customer_unique_id,
            c.customer_state,
            -- Recency: days since last purchase (lower = more recent = better)        
            DATEDIFF(
                rd.max_date,
                MAX(o.order_purchase_timestamp)
            ) AS recency_days,
            -- Frequency: total number of orders       
            COUNT(DISTINCT o.order_id) AS frequency,
            -- Monetary: total spent
            ROUND(SUM(oi.price), 2) AS monetary_value
        FROM
            orders o
            JOIN customers c ON c.customer_id = o.customer_id
            JOIN order_items oi ON oi.order_id = o.order_id
            CROSS JOIN reference_date rd
        GROUP BY
            c.customer_unique_id,
            c.customer_state,
            rd.max_date
    ),
    rfm_scored AS (
        SELECT
            customer_unique_id,
            customer_state,
            recency_days,
            frequency,
            monetary_value,
            NTILE(5) OVER (
                ORDER BY recency_days DESC
            ) AS r_score,
            NTILE(5) OVER (
                ORDER BY frequency ASC
            ) AS f_score,
            NTILE(5) OVER (
                ORDER BY monetary_value ASC
            ) AS m_score
        FROM rfm_base
    )
SELECT
    customer_unique_id,
    customer_state,
    recency_days,
    frequency,
    monetary_value,
    r_score,
    f_score,
    m_score,
    CONCAT(
        r_score,
        '-',
        f_score,
        '-',
        m_score
    ) AS rfm_score
FROM rfm_scored
ORDER BY m_score DESC, f_score DESC, r_score DESC
LIMIT 50;

-- Step 3: Full RFM segmentation with labels and strategies
-- This is the final output — use this in your Power BI dashboard
WITH
    reference_date AS (
        SELECT MAX(order_purchase_timestamp) AS max_date
        FROM orders
    ),
    rfm_base AS (
        SELECT
            c.customer_unique_id,
            c.customer_state,
            DATEDIFF(
                rd.max_date,
                MAX(o.order_purchase_timestamp)
            ) AS recency_days,
            COUNT(DISTINCT o.order_id) AS frequency,
            ROUND(SUM(oi.price), 2) AS monetary_value
        FROM
            orders o
            JOIN customers c ON o.customer_id = c.customer_id
            JOIN order_items oi ON o.order_id = oi.order_id
            CROSS JOIN reference_date rd
        WHERE
            o.order_status NOT IN('canceled', 'unavailable')
        GROUP BY
            c.customer_unique_id,
            c.customer_state,
            rd.max_date
    ),
    rfm_scored AS (
        SELECT
            *,
            NTILE(5) OVER (
                ORDER BY recency_days DESC
            ) AS r_score,
            NTILE(5) OVER (
                ORDER BY frequency ASC
            ) AS f_score,
            NTILE(5) OVER (
                ORDER BY monetary_value ASC
            ) AS m_score
        FROM rfm_base
    )
SELECT
    customer_unique_id,
    customer_state,
    recency_days,
    frequency,
    monetary_value,
    r_score,
    f_score,
    m_score,
    -- Segment label based on score combination
    CASE
        WHEN r_score >= 4
        AND f_score >= 4
        AND m_score >= 4 THEN 'Champions'
        WHEN r_score >= 3
        AND f_score >= 3 THEN 'Loyal Customers'
        WHEN r_score >= 4
        AND f_score <= 2 THEN 'New Customers'
        WHEN r_score <= 2
        AND f_score >= 4 THEN 'At Risk'
        WHEN r_score <= 2
        AND f_score >= 3 THEN 'Cant Lose Them'
        WHEN r_score <= 1
        AND f_score <= 2 THEN 'Lost'
        WHEN r_score >= 3
        AND f_score <= 2 THEN 'Potential Loyalists'
        ELSE 'Needs Attention'
    END AS segment,
    -- Business strategy for each segment
    CASE
        WHEN r_score >= 4
        AND f_score >= 4
        AND m_score >= 4 THEN 'VIP loyalty program + early access to new products'
        WHEN r_score >= 3
        AND f_score >= 3 THEN 'Points & cashback rewards, upsell premium categories'
        WHEN r_score >= 4
        AND f_score <= 2 THEN 'Onboarding email series + free shipping on 2nd order'
        WHEN r_score <= 2
        AND f_score >= 4 THEN 'Win-back campaign: 15% discount + personalised recommendation'
        WHEN r_score <= 2
        AND f_score >= 3 THEN 'Urgent re-engagement: big discount + remind of past purchases'
        WHEN r_score <= 1
        AND f_score <= 2 THEN 'Survey + 30% off voucher, otherwise write off'
        WHEN r_score >= 3
        AND f_score <= 2 THEN 'Nurture with curated content + 2nd purchase incentive'
        ELSE 'Flash sale offer + review request email'
    END AS recommended_strategy
FROM rfm_scored
ORDER BY m_score DESC, f_score DESC;

-- Segment summary table for dashboard
WITH
    reference_date AS (
        SELECT MAX(order_purchase_timestamp) AS max_date
        FROM orders
    ),
    rfm_base AS (
        SELECT
            c.customer_unique_id,
            DATEDIFF(
                rd.max_date,
                MAX(o.order_purchase_timestamp)
            ) AS recency_days,
            COUNT(DISTINCT o.order_id) AS frequency,
            ROUND(SUM(oi.price), 2) AS monetary_value
        FROM
            orders o
            JOIN customers c ON o.customer_id = c.customer_id
            JOIN order_items oi ON o.order_id = oi.order_id
            CROSS JOIN reference_date rd
        WHERE
            o.order_status NOT IN('canceled', 'unavailable')
        GROUP BY
            c.customer_unique_id,
            rd.max_date
    ),
    rfm_scored AS (
        SELECT
            *,
            NTILE(5) OVER (
                ORDER BY recency_days DESC
            ) AS r_score,
            NTILE(5) OVER (
                ORDER BY frequency ASC
            ) AS f_score,
            NTILE(5) OVER (
                ORDER BY monetary_value ASC
            ) AS m_score
        FROM rfm_base
    ),
    rfm_segmented AS (
        SELECT
            *,
            CASE
                WHEN r_score >= 4
                AND f_score >= 4
                AND m_score >= 4 THEN 'Champions'
                WHEN r_score >= 3
                AND f_score >= 3 THEN 'Loyal Customers'
                WHEN r_score >= 4
                AND f_score <= 2 THEN 'New Customers'
                WHEN r_score <= 2
                AND f_score >= 4 THEN 'At Risk'
                WHEN r_score <= 2
                AND f_score >= 3 THEN 'Cant Lose Them'
                WHEN r_score <= 1
                AND f_score <= 2 THEN 'Lost'
                WHEN r_score >= 3
                AND f_score <= 2 THEN 'Potential Loyalists'
                ELSE 'Needs Attention'
            END AS segment
        FROM rfm_scored
    )
SELECT
    segment,
    COUNT(*) AS customer_count,
    ROUND(
        100.0 * COUNT(*) / SUM(COUNT(*)) OVER (),
        1
    ) AS pct_of_customers,
    ROUND(AVG(recency_days), 0) AS avg_recency_days,
    ROUND(AVG(frequency), 1) AS avg_frequency,
    ROUND(AVG(monetary_value), 2) AS avg_monetary,
    ROUND(SUM(monetary_value), 2) AS total_revenue
FROM rfm_segmented
GROUP BY
    segment
ORDER BY total_revenue DESC;