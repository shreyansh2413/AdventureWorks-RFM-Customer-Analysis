--Dataset Understanding
--Q1. How many total orders are present in the dataset?

SELECT COUNT(*) AS total_orders
FROM sales.salesorderheader;

--Q2. How many unique customers have placed orders?

SELECT COUNT(DISTINCT customerid) AS unique_customers
FROM sales.salesorderheader;

--Q3. What is the earliest and latest order date?

SELECT
    MIN(orderdate)::date AS first_order_date,
    MAX(orderdate)::date AS last_order_date
FROM sales.salesorderheader;

--Q4. What is the total revenue generated from all orders?

SELECT
    ROUND(SUM(totaldue), 2) AS total_revenue
FROM sales.salesorderheader;

--Q5. What is the average order value?

SELECT
    ROUND(AVG(totaldue), 2) AS average_order_value
FROM sales.salesorderheader;

--Basic Business Analysis

--Q6. How many orders were placed in each year?

SELECT
    EXTRACT(YEAR FROM orderdate) AS order_year,
    COUNT(*) AS total_orders
FROM sales.salesorderheader
GROUP BY EXTRACT(YEAR FROM orderdate)
ORDER BY order_year;

--Q7. What was the total revenue generated in each year?

SELECT
    EXTRACT(YEAR FROM orderdate) AS order_year,
    ROUND(SUM(totaldue), 2) AS total_revenue
FROM sales.salesorderheader
GROUP BY EXTRACT(YEAR FROM orderdate)
ORDER BY order_year;

--Q8. Which year generated the highest revenue?

SELECT
    EXTRACT(YEAR FROM orderdate) AS order_year,
    ROUND(SUM(totaldue), 2) AS total_revenue
FROM sales.salesorderheader
GROUP BY EXTRACT(YEAR FROM orderdate)
ORDER BY total_revenue DESC
LIMIT 1;

--Q9. How many orders were placed in each month?

SELECT
    EXTRACT(YEAR FROM orderdate) AS order_year,
    EXTRACT(MONTH FROM orderdate) AS order_month,
    COUNT(*) AS total_orders
FROM sales.salesorderheader
GROUP BY
    EXTRACT(YEAR FROM orderdate),
    EXTRACT(MONTH FROM orderdate)
ORDER BY order_year, order_month;

--Q10. What is the monthly revenue trend over the available period?

SELECT
    DATE_TRUNC('month', orderdate)::date AS month,
    ROUND(SUM(totaldue), 2) AS monthly_revenue
FROM sales.salesorderheader
GROUP BY DATE_TRUNC('month', orderdate)
ORDER BY month;

--Customer Analysis

--Q11. How many orders has each customer placed?

SELECT
    customerid,
    COUNT(*) AS total_orders
FROM sales.salesorderheader
GROUP BY customerid
ORDER BY total_orders;

--Q12. Which are the top 10 customers by number of orders?

SELECT
    customerid,
    COUNT(*) AS total_orders
FROM sales.salesorderheader
GROUP BY customerid
ORDER BY total_orders DESC
LIMIT 10;

--Q13. How much revenue has each customer generated?

SELECT
    customerid,
    ROUND(SUM(totaldue), 2) AS total_spending
FROM sales.salesorderheader
GROUP BY customerid
ORDER BY total_spending DESC;

--Q14. What is the average amount spent per customer?

SELECT
    ROUND(AVG(customer_spending), 2) AS avg_customer_spending
FROM (
    SELECT
        customerid,
        SUM(totaldue) AS customer_spending
    FROM sales.salesorderheader
    GROUP BY customerid
) AS customer_summary;

--Slightly More Level

--Q15. How many customers placed only one order?

SELECT COUNT(*) AS one_order_customers
FROM (
    SELECT
        customerid,
        COUNT(*) AS total_orders
    FROM sales.salesorderheader
    GROUP BY customerid
    HAVING COUNT(*) = 1
) AS customer_orders;

--Q16. What percentage of customers have placed only one order?

SELECT
    ROUND(100.0 * COUNT(*) /
        (SELECT COUNT(DISTINCT customerid)
         FROM sales.salesorderheader),2) AS percentage_one_order_customers
FROM (
    SELECT customerid
    FROM sales.salesorderheader
    GROUP BY customerid
    HAVING COUNT(*) = 1
) AS one_order_customers;

--Q17. What is the average number of orders per customer?

SELECT
    ROUND(AVG(order_count), 2) AS avg_orders_per_customer
FROM (
    SELECT
        customerid,
        COUNT(*) AS order_count
    FROM sales.salesorderheader
    GROUP BY customerid
) AS customer_orders;

--Q18. Which customers have both a high number of orders and high total spending?

WITH customer_summary AS (
    SELECT
        customerid,
        COUNT(*) AS total_orders,
        SUM(totaldue) AS total_spending
    FROM sales.salesorderheader
    GROUP BY customerid
)

SELECT
    customerid,
    total_orders,
    ROUND(total_spending, 2) AS total_spending
FROM customer_summary
WHERE total_orders > (
    SELECT AVG(total_orders)
    FROM customer_summary
)
AND total_spending > (
    SELECT AVG(total_spending)
    FROM customer_summary
)
ORDER BY total_spending DESC;

--RFM Foundation

--Q19. What was the most recent purchase date for each customer?

SELECT
    customerid,
    MAX(orderdate)::date AS last_purchase_date
FROM sales.salesorderheader
GROUP BY customerid
ORDER BY last_purchase_date DESC;

--Q20. How many days has it been since each customer's last purchase?
--Taking today's date as 2026-01-01

WITH customer_last_purchase AS (
    SELECT
        customerid,
        MAX(orderdate)::date AS last_purchase_date
    FROM sales.salesorderheader
    GROUP BY customerid
)
SELECT
    customerid,
    last_purchase_date,
    DATE '2026-01-01' - last_purchase_date AS recency_days
FROM customer_last_purchase
ORDER BY recency_days;

--Q21. How many orders has each customer placed?

SELECT
    customerid,
    COUNT(DISTINCT salesorderid) AS frequency
FROM sales.salesorderheader
GROUP BY customerid
ORDER BY frequency DESC;

--Q22. How much has each customer spent in total?

SELECT
    customerid,
    ROUND(SUM(totaldue), 2) AS monetary_value
FROM sales.salesorderheader
GROUP BY customerid
ORDER BY monetary_value DESC;

--Q23. RFM base cases.

SELECT
    customerid,
    MAX(orderdate)::date AS last_purchase_date,
    DATE '2025-06-29' - MAX(orderdate)::date AS recency_days,
    COUNT(DISTINCT salesorderid) AS frequency,
    ROUND(SUM(totaldue), 2) AS monetary_value
FROM sales.salesorderheader
GROUP BY customerid
ORDER BY customerid;

--Final

WITH rfm_base AS (
    SELECT
        customerid,
        MAX(orderdate)::date AS last_purchase_date,
        DATE '2025-12-31' - MAX(orderdate)::date AS recency_days,
        COUNT(DISTINCT salesorderid) AS frequency,
        ROUND(SUM(totaldue), 2) AS monetary_value
    FROM sales.salesorderheader
    GROUP BY customerid
),

rfm_scores AS (
    SELECT
        customerid,
        last_purchase_date,
        recency_days,
        frequency,
        monetary_value,

        NTILE(5) OVER (
            ORDER BY recency_days DESC
        ) AS recency_score,

        NTILE(5) OVER (
            ORDER BY frequency
        ) AS frequency_score,

        NTILE(5) OVER (
            ORDER BY monetary_value
        ) AS monetary_score

    FROM rfm_base
),

rfm_final AS (
    SELECT
        *,
        recency_score + frequency_score + monetary_score AS rfm_score,

        CASE
            WHEN recency_score >= 4
                 AND frequency_score >= 4
                 AND monetary_score >= 4
                THEN 'Champions'

            WHEN recency_score >= 3
                 AND frequency_score >= 3
                THEN 'Loyal Customers'

            WHEN recency_score >= 3
                 AND frequency_score <= 2
                THEN 'Potential Loyalists'

            WHEN recency_score <= 2
                 AND frequency_score >= 3
                THEN 'At Risk'

            WHEN recency_score <= 2
                 AND frequency_score <= 2
                THEN 'Lost Customers'

            ELSE 'Other'
        END AS customer_segment

    FROM rfm_scores
)

SELECT *
FROM rfm_final
ORDER BY customerid;