USE shopsense;

DESCRIBE orders;

DESCRIBE customers;

DESCRIBE order_items;

DESCRIBE products;

DESCRIBE sellers;

DESCRIBE payments;

DESCRIBE reviews;

-- Row counts for all tables
SELECT 'orders' AS table_name, COUNT(*) AS row_count
FROM orders
UNION ALL
SELECT 'customers' AS table_name, COUNT(*) AS row_count
FROM customers
UNION ALL
SELECT 'order_items' AS table_name, COUNT(*) AS row_count
FROM order_items
UNION ALL
SELECT 'products' AS table_name, COUNT(*) AS row_count
FROM products
UNION ALL
SELECT 'sellers' AS table_name, COUNT(*) AS row_count
FROM sellers
UNION ALL
SELECT 'payments' AS table_name, COUNT(*) AS row_count
FROM payments
UNION ALL
SELECT 'reviews' AS table_name, COUNT(*) AS row_count
FROM reviews;

-- Checking for nulls in key orders columns
SELECT
    COUNT(*) AS total_orders,
    SUM(
        CASE
            WHEN order_status IS NULL THEN 1
            ELSE 0
        END
    ) AS null_status,
    SUM(
        CASE
            WHEN order_purchase_timestamp IS NULL THEN 1
            ELSE 0
        END
    ) AS null_purchase_date,
    SUM(
        CASE
            WHEN order_delivered_customer_date IS NULL THEN 1
            ELSE 0
        END
    ) AS null_delivery_date,
    SUM(
        CASE
            WHEN customer_id IS NULL THEN 1
            ELSE 0
        END
    ) AS null_customer_id
FROM orders;

ALTER TABLE orders MODIFY customer_id VARCHAR(50);

ALTER TABLE orders MODIFY order_status VARCHAR(50);

ALTER TABLE orders MODIFY order_purchase_timestamp DATETIME;
-- Index on orders table (most used in JOINs)
ALTER TABLE orders ADD INDEX idx_order_customer (customer_id);

ALTER TABLE orders ADD INDEX idx_order_status (order_status);

ALTER TABLE orders
ADD INDEX idx_order_purchase (order_purchase_timestamp);

ALTER TABLE order_items MODIFY order_id VARCHAR(50);

ALTER TABLE order_items MODIFY product_id VARCHAR(50);

ALTER TABLE order_items MODIFY seller_id VARCHAR(50);

ALTER TABLE order_items ADD INDEX idx_items_order (order_id);

ALTER TABLE order_items ADD INDEX idx_items_product (product_id);

ALTER TABLE order_items ADD INDEX idx_items_seller (seller_id);

ALTER TABLE customers MODIFY customer_unique_id VARCHAR(50);

ALTER TABLE customers MODIFY customer_state VARCHAR(50);

ALTER TABLE customers
ADD INDEX idx_customer_unique (customer_unique_id);

ALTER TABLE customers ADD INDEX idx_customer_state (customer_state);

-- Adding delivery_delay column (positive = late, negative = early)
ALTER TABLE orders ADD COLUMN delivery_delay_days INT;

UPDATE orders
SET
    delivery_delay_days = DATEDIFF(
        order_delivered_customer_date,
        order_estimated_delivery_date
    )
WHERE
    order_delivered_customer_date IS NOT NULL
    AND order_estimated_delivery_date IS NOT NULL;

-- Extract year and month for analysis
ALTER TABLE orders ADD COLUMN order_month VARCHAR(7);

UPDATE orders
SET
    order_month = DATE_FORMAT(
        order_purchase_timestamp,
        '%Y-%m'
    )
WHERE
    order_purchase_timestamp IS NOT NULL;

ALTER TABLE orders MODIFY order_delivered_customer_date DATETIME;

ALTER TABLE orders MODIFY order_estimated_delivery_date DATETIME;

SELECT
    order_id,
    order_purchase_timestamp,
    order_delivered_customer_date,
    order_estimated_delivery_date,
    delivery_delay_days,
    order_status order_month
FROM orders
LIMIT 10;