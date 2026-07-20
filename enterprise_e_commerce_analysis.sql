--Q1. What is the total revenue?
select round(sum(payment_value)::numeric,2) as total_revenue from payments;

--Q2. Total orders,Total customers on platform?
select count(distinct order_id) as total_orders,count(distinct customer_id) as total_customers from orders;

--Q3. Total sellers on the platform?
select count(distinct seller_id) as total_sellers from sellers;

--Q4. How do monthly orders trend over time?
select date_trunc('month',o.order_purchase_timestamp) as months,count(distinct o.order_id) as orders 
from payments as p
join orders as o
on p.order_id=o.order_id
group by months
order by months;

--Q5. How do monthly revenue trend over time? 
select date_trunc('month',o.order_purchase_timestamp) as months, round(sum(p.payment_value)::numeric,2) as revenue 
from payments as p
join orders as o
on p.order_id=o.order_id
group by months
order by months;

--Q6. What is the Month-over-Month (MoM) revenue growth?
with temp1 as(
select date_trunc('month',o.order_purchase_timestamp) as months,
round(sum(p.payment_value)::numeric,2) as revenue
from payments as p 
join orders as o 
on o.order_id=p.order_id
group by months),
temp2 as (
select to_char(months,'Mon YYYY') as months_f,revenue,
lag(revenue,1) over (order by months)as last_month_revenue from temp1)

select months_f,revenue,round((100.0*((revenue-last_month_revenue)/NULLIF(last_month_revenue,0))),2) as "growth%" 
from temp2;

--Q7. Which product categories generate the highest revenue?
select p.product_category_name,round(sum(i.price)::numeric,2) as revenue 
from items as i
join products as p
on i.product_id=p.product_id
group by p.product_category_name
order by revenue desc;

--Q8. Which product categories sell the highest quantity?
select p.product_category_name,count(distinct i.order_id) as qty
from items as i
join products as p
on i.product_id=p.product_id
group by p.product_category_name
order by qty desc;

--Q9. Which cities generate the highest revenue?
select c.customer_city,round(sum(pa.payment_value)::numeric,2) as revenue 
from orders as o
join customers as c
on o.customer_id=c.customer_id
join payments as pa
on o.order_id=pa.order_id
group by c.customer_city
order by revenue desc;

--Q10. Which states generate the highest revenue?
select c.customer_state,round(sum(pa.payment_value)::numeric,2) as revenue 
from orders as o
join customers as c
on o.customer_id=c.customer_id
join payments as pa
on o.order_id=pa.order_id
group by c.customer_state
order by revenue desc;

--Q11. What is the Average Order Value (AOV)?
select round((sum(payment_value)/count(distinct order_id))::numeric,2) as avg_order_value
from payments;

--Q12. Who are the top 10 customers by spending?
select c.customer_unique_id,round(sum(pa.payment_value)::numeric,2) as revenue 
from orders as o
join customers as c
on o.customer_id=c.customer_id
join payments as pa
on o.order_id=pa.order_id
group by c.customer_unique_id
order by revenue desc
limit 10;

--Q13. How many repeat customers are there?
WITH repeat_customers AS (
SELECT c.customer_unique_id,COUNT(o.order_id) AS total_orders
FROM customers AS c
JOIN orders AS o
ON c.customer_id = o.customer_id
GROUP BY c.customer_unique_id
HAVING COUNT(o.order_id) > 1
)

SELECT COUNT(*) AS repeat_customer_count
FROM repeat_customers;

--Q14. Which sellers generate the highest revenue?
select s.seller_id,round(sum(pa.payment_value)::numeric,2) as revenue 
from items as i
join sellers as s
on i.seller_id=s.seller_id
join payments as pa
on i.order_id=pa.order_id
group by s.seller_id
order by revenue desc;

--Q15. What is the average delivery time?
select avg(order_delivered_customer_date-order_purchase_timestamp) as avg_delivery_time
from orders;

--Q16. Create customer segments (High, Medium, Low Value) based on total spending.
WITH customer_revenue AS (
SELECT c.customer_unique_id,ROUND(SUM(p.payment_value)::numeric, 2) AS total_spent
FROM customers AS c
JOIN orders AS o
ON c.customer_id = o.customer_id
JOIN payments AS p
ON o.order_id = p.order_id
GROUP BY c.customer_unique_id
),

customer_segments AS (
SELECT customer_unique_id,total_spent,NTILE(4) OVER (ORDER BY total_spent DESC) AS quartile
FROM customer_revenue
)

SELECT customer_unique_id,total_spent,
CASE
WHEN quartile = 1 THEN 'High'
WHEN quartile IN (2,3) THEN 'Medium'
ELSE 'Low'
END AS customer_segment
FROM customer_segments
ORDER BY total_spent DESC;

--Q17.Which payment methods contribute the most revenue?
select payment_type,round(sum(payment_value)::numeric,2) as revenue
from payments 
group by payment_type
order by revenue desc;

--Q18. What is the average freight cost by product category?
select p.product_category_name,round(avg(i.freight_value)::numeric,2) as avg_freight_cost
from products as p
join items as i 
on p.product_id=i.product_id
group by p.product_category_name
order by avg_freight_cost desc;

--Q19. Which product categories have the highest and lowest customer ratings?
WITH category_rating AS (
SELECT p.product_category_name,ROUND(AVG(r.review_score),2) AS avg_rating
FROM products p
JOIN items i
ON p.product_id = i.product_id
JOIN reviews r
ON i.order_id = r.order_id
GROUP BY p.product_category_name
),

ranked AS (
SELECT *,RANK() OVER (ORDER BY avg_rating DESC) AS highest_rank,
RANK() OVER (ORDER BY avg_rating ASC) AS lowest_rank
FROM category_rating
)

SELECT product_category_name,avg_rating
FROM ranked
WHERE highest_rank = 1 OR lowest_rank = 1;

--Q20. Rank sellers based on revenue.
with temp1 as(
select s.seller_id,round(sum(pa.payment_value)::numeric,2) as revenue
from items as i
join sellers as s
on i.seller_id=s.seller_id
join payments as pa
on i.order_id=pa.order_id
group by s.seller_id)
select seller_id,revenue,
rank() over(order by revenue desc) from temp1;


--Q21. Rank sellers based on average review score.
with temp1 as(
select s.seller_id,round(avg(r.review_score),2) as customer_rating
from sellers as s
join items as i 
on s.seller_id=i.seller_id
join reviews as r
on i.order_id=r.order_id
group by s.seller_id)
select seller_id,customer_rating,
dense_rank() over(order by customer_rating desc) from temp1;


--Q22. What percentage of total revenue does each product category contribute?
WITH temp1 AS (
SELECT p.product_category_name,ROUND(SUM(i.price)::numeric, 2) AS revenue
FROM items AS i
JOIN products AS p
ON i.product_id = p.product_id
GROUP BY p.product_category_name
),
temp2 AS (
SELECT SUM(revenue) AS total_revenue
FROM temp1
)
SELECT t1.product_category_name,t1.revenue,
ROUND(100.0 * t1.revenue / t2.total_revenue, 2) AS percent_total
FROM temp1 t1
CROSS JOIN temp2 t2
ORDER BY percent_total DESC;

--Q23. How many orders were delivered late?
select count(distinct order_id) as orders_delivered_late from orders
where order_delivered_customer_date>order_estimated_delivery_date;


--Q24. Does delivery delay affect customer review scores?
select case when o.order_delivered_customer_date>o.order_estimated_delivery_date then 'Late'
else 'On Time'
end as delay, round(avg(r.review_score),2) as customer_rating
from orders as o
join reviews as r
on o.order_id=r.order_id
group by delay;