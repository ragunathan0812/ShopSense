-- Base profit calculation for every order
-- Assumptions documented inline
SELECT
    o.order_id,
    c.customer_state,
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    oi.price AS revenue,
    oi.freight_value AS actual_freight,
    -- Cost 1: Shipping (12% of price + actual freight)    
    ROUND(
        oi.price * 0.12 + oi.freight_value,
        2
    ) AS shipping_cost,
    -- Cost 2: Discount (8% of price if review < 3, else 0)
    ROUND(
        CASE
            WHEN r.review_score < 3 THEN oi.price * 0.08
            ELSE 0
        END,
        2
    ) AS discount_cost,
    -- Cost 3: Flat operational cost per order item
    5.00 AS operational_cost,
    -- PROFIT = Revenue - all costs
    ROUND(
        oi.price - (
            oi.price * 0.12 + oi.freight_value
        ) - (
            CASE
                WHEN r.review_score < 3 THEN oi.price * 0.08
                ELSE 0
            END
        ) - 5.00,
        2
    ) AS profit,
    -- Profit margin %  
    ROUND(
        100.0 * (
            oi.price - (
                oi.price * 0.12 + oi.freight_value
            ) - (
                CASE
                    WHEN r.review_score < 3 THEN oi.price * 0.08
                    ELSE 0
                END
            ) - 5.00
        ) / NULLIF(oi.price, 0),
        1
    ) AS profit_margin_pct
FROM
    orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE
    o.order_status NOT IN('canceled', 'unavailable')
ORDER BY profit DESC
LIMIT 100;

-- Profit by category: revenue vs profitability comparison
SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(
        SUM(
            oi.price * 0.12 + oi.freight_value
        ),
        2
    ) AS total_shipping_cost,
    ROUND(
        SUM(
            CASE
                WHEN r.review_score < 3 THEN oi.price * 0.08
                ELSE 0
            END
        ),
        2
    ) AS total_discount_cost,
    ROUND(
        COUNT(DISTINCT o.order_id) * 5.00,
        2
    ) AS total_operational_cost,
    ROUND(
        SUM(oi.price) - (
            SUM(
                oi.price * 0.12 + oi.freight_value
            )
        ) - (
            SUM(
                CASE
                    WHEN r.review_score < 3 THEN oi.price * 0.08
                    ELSE 0
                END
            )
        ) - (
            COUNT(DISTINCT o.order_id) * 5.00
        ),
        2
    ) AS total_profit,
    ROUND(
        100.0 * (
            SUM(oi.price) - SUM(
                oi.price * 0.12 + oi.freight_value
            ) - SUM(
                CASE
                    WHEN r.review_score < 3 THEN oi.price * 0.08
                    ELSE 0
                END
            ) - COUNT(DISTINCT o.order_id) * 5.00
        ) / NULLIF(SUM(oi.price), 0),
        1
    ) AS profit_margin_pct,
    ROUND(AVG(r.review_score), 2) AS avg_review_score
FROM
    orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN products p ON oi.product_id = p.product_id
    LEFT JOIN product_category_name_translation t ON p.product_category_name = t.product_category_name
    LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE
    o.order_status NOT IN('canceled', 'unavailable')
GROUP BY
    category
HAVING
    total_orders > 100
ORDER BY total_profit DESC;

-- Profit by customer state
SELECT
    c.customer_state,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(
        SUM(oi.price) - SUM(
            oi.price * 0.12 + oi.freight_value
        ) - SUM(
            CASE
                WHEN r.review_score < 3 THEN oi.price * 0.08
                ELSE 0
            END
        ) - COUNT(DISTINCT o.order_id) * 5.00,
        2
    ) AS total_profit,
    ROUND(
        100.0 * (
            SUM(oi.price) - SUM(
                oi.price * 0.12 + oi.freight_value
            ) - SUM(
                CASE
                    WHEN r.review_score < 3 THEN oi.price * 0.08
                    ELSE 0
                END
            ) - COUNT(DISTINCT o.order_id) * 5.00
        ) / NULLIF(SUM(oi.price), 0),
        1
    ) AS profit_margin_pct,
    ROUND(AVG(o.delivery_delay_days), 2) AS avg_delay_days
FROM
    orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN customers c ON o.customer_id = c.customer_id
    LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE
    o.order_status NOT IN('canceled', 'unavailable')
GROUP BY
    c.customer_state
ORDER BY profit_margin_pct DESC;

-- Profit analysis by payment type and installments
SELECT
    py.payment_type,
    py.payment_installments,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(
        SUM(oi.price) - SUM(
            oi.price * 0.12 + oi.freight_value
        ) - SUM(
            CASE
                WHEN r.review_score < 3 THEN oi.price * 0.08
                ELSE 0
            END
        ) - COUNT(DISTINCT o.order_id) * 5.00,
        2
    ) AS total_profit,
    ROUND(
        100.0 * (
            SUM(oi.price) - SUM(
                oi.price * 0.12 + oi.freight_value
            ) - SUM(
                CASE
                    WHEN r.review_score < 3 THEN oi.price * 0.08
                    ELSE 0
                END
            ) - COUNT(DISTINCT o.order_id) * 5.00
        ) / NULLIF(SUM(oi.price), 0),
        1
    ) AS profit_margin_pct
FROM
    orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    JOIN payments py ON o.order_id = py.order_id
    LEFT JOIN reviews r ON o.order_id = r.order_id
WHERE
    o.order_status NOT IN('canceled', 'unavailable')
    AND py.payment_sequential = 1
GROUP BY
    py.payment_type,
    py.payment_installments
HAVING
    total_orders > 50
ORDER BY profit_margin_pct DESC;

-- Month over month profit trend
SELECT
    DATE_FORMAT(
        o.order_purchase_timestamp,
        '%Y-%m'
    ) AS month,
    COUNT(DISTINCT o.order_id) AS total_orders,
    ROUND(SUM(oi.price), 2) AS total_revenue,
    ROUND(
        SUM(oi.price) - SUM(
            oi.price * 0.12 + oi.freight_value
        ) - SUM(
            CASE
                WHEN r.review_score < 3 THEN oi.price * 0.08
                ELSE 0
            END
        ) - COUNT(DISTINCT o.order_id) * 5.00,
        2
    ) AS total_profit,
    ROUND(
        100.0 * (
            SUM(oi.price) - SUM(
                oi.price * 0.12 + oi.freight_value
            ) - SUM(
                CASE
                    WHEN r.review_score < 3 THEN oi.price * 0.08
                    ELSE 0
                END
            ) - COUNT(DISTINCT o.order_id) * 5.00
        ) / NULLIF(SUM(oi.price), 0),
        1
    ) AS profit_margin_pct
FROM
    orders o
    JOIN order_items oi ON o.order_id = oi.order_id
    LEFT JOIN reviews r ON o.order_id = r.order_id
GROUP BY
    month
ORDER BY total_profit DESC;