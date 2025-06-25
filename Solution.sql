SELECT * FROM category;
SELECT * FROM products;
SELECT * FROM stores;
SELECT * FROM warranty;
SELECT * FROM sales;

SELECT DISTINCT repair_status FROM warranty;

---Improved query performance

CREATE INDEX sales_product_id on sales(product_id);

CREATE INDEX sales_store_id on sales(store_id);

CREATE INDEX sales_sale_date on sales(sale_date);

--Problems
-- 1.Find the number of stores in each country
SELECT country,Count(store_id) As number_of_store
FROM stores
GROUP BY country
ORDER BY number_of_store DESC;

-- 2.What is the total number of units sold by each store?
SELECT st.store_name,sum(quantity) as total_units_sold
FROM sales sa INNER JOIN stores st
ON sa.store_id=st.store_id
GROUP BY st.store_name
ORDER BY total_units_sold DESC;

--3.How many sales occurred in December 2023?
SELECT count(sale_id) as sale_occurred
FROM sales
WHERE TO_CHAR(sale_date,'MM-YYYY')='12-2023';


-- 4 How many stores have never had a warranty claim filed against any of their products?
SELECT COUNT(*) as total_stores
FROM stores
WHERE store_id NOT IN (
select 
distinct(store_id)
from warranty w left join sales s
on w.sale_id = s.sale_id);

-- 5. What percentage of warranty claims are marked as "Warranty Void"?
SELECT ROUND(COUNT(claim_id)/(SELECT COUNT(*) FROM warranty) ::"numeric"*100 , 2) 
       AS warranty_void_percentage
FROM warranty
WHERE repair_status='Warranty Void';
            
-- 6. Which store had the highest total units sold in the last year?                   
SELECT st.store_name,
	   SUM(sa.quantity) as total_unit_sold
FROM sales sa join stores st
ON sa.store_id=st.store_id
WHERE sa.sale_date >= (CURRENT_DATE - INTERVAL '1 year')
GROUP BY store_name
ORDER BY total_unit_sold DESC
LIMIT 1;

-- 7. Count the number of unique products sold in the last year.

SELECT COUNT(DISTINCT product_id) as unique_product
FROM sales
WHERE sale_date >= (CURRENT_DATE - INTERVAL '2 year')

--8. What is the average price of products in each category?
SELECT c.category_name, ROUND(avg(price)) as avg_price
FROM products p inner join category c
ON p.category_id=c.category_id
GROUP BY c.category_name
ORDER BY avg_price DESC;


--9.How many warranty claims were filed in 2020?
SELECT COUNT(*) as warranty_claim
FROM warranty
WHERE EXTRACT(YEAR FROM claim_date)='2020'


--10.For each store,identify best selling day based on highest quantity sold

SELECT * FROM
(SELECT sa.store_id, st.store_name,
		TO_CHAR(sale_date,'Day'),
		SUM(quantity) as total_units_sold,
		RANK() OVER(PARTITION BY sa.store_id order by SUM(quantity) DESC) AS RANK
FROM sales sa inner join stores st 
ON sa.store_id=st.store_id
GROUP BY 1,2,3) as t1
WHERE rank=1



--11.Identify the least selling product in each country for each year based on total units sold.
SELECT *
FROM(
    SELECT
        st.country,
        p.product_name,
        EXTRACT(YEAR FROM sl.sale_date) AS year,
        SUM(sl.quantity) AS total_quantity_sold,
        RANK() OVER(PARTITION BY st.country, EXTRACT(YEAR FROM sl.sale_date) ORDER BY SUM(sl.quantity) DESC) AS rank
    FROM
        stores st
    JOIN
        sales sl ON st.store_id = sl.store_id
    JOIN
        products p ON p.product_id = sl.product_id
    GROUP BY
        st.country, p.product_name, EXTRACT(YEAR FROM sl.sale_date)
) as t1
WHERE rank = 1;
	   
-- 12. How many warranty claims were filed within 180 days of a product sale?
SELECT 
	w.claim_id,w.claim_date,
	s.sale_date,
	w.claim_date-s.sale_date as claims_day
FROM warranty w
JOIN sales s
ON w.sale_id=s.sale_id
WHERE w.claim_date-s.sale_date <= 180
ORDER BY claims_day 


-- 13. How many warranty claims have been filed for products launched in the last two years?
SELECT p.product_id,
		p.product_name,
		p.launch_date,
       count(w.claim_id) as warranty_claims
FROM warranty w
JOIN sales s
ON w.sale_id=s.sale_id
JOIN products p
ON p.product_id = s.product_id
WHERE p.launch_date>=(CURRENT_DATE - INTERVAL '2 year')
GROUP BY 1,2,3

	   
-- 14 List the months in the last three years where sales exceeded 5,000 units in the USA.
SELECT 
	TO_CHAR(sale_date,'Month') as month,
	SUM(s.quantity) as Total_sales
FROM sales as s
JOIN
stores as st
on s.store_id = st.store_id
WHERE
	st.country ='USA'
	AND
	s.sale_date >= CURRENT_DATE - INTERVAL '3 year'
GROUP BY month
HAVING SUM(s.quantity)> 5000

-- 15 Identify the product category with the most warranty claims filed in the last two years.
SELECT
	c.category_name,
	Count(w.claim_id) as total_claims
FROM warranty as w
LEFT JOIN Sales s
on w.sale_id = s.sale_id
JOIN products as p
on s.product_id = p.product_id
JOIN category as c
on p.category_id = c.category_id
WHERE 
	w.claim_date >= CURRENT_DATE - INTERVAL '2 year'
GROUP BY 1
ORDER BY total_claims DESC
LIMIT 1;

--16.Determine the percentage chance of receiving warranty claims after each purchase for each country!

SELECT
	country,
	total_sales,
	total_claims,
	ROUND(coalesce(total_claims::numeric/total_sales::numeric * 100,0),2) as percentage_warranty_claims
FROM
(SELECT 
	st.country,
	sum(s.quantity) as total_sales,
	count(w.claim_id) as total_claims
from sales as s
join
stores as st
on s.store_id = st.store_id
left join
warranty as w
on s.sale_id = w.sale_id
group by st.country) t1
order by 4 desc

-- 17.Analyze the year-by-year growth ratio for each store.
WITH yearly_sales
AS
(
select 
	st.store_id,
	st.store_name,
	extract(year from s.sale_date) as year,
	sum(p.price * s.quantity ) as total_sale
from sales as s
join
products as p
on s.product_id = p.product_id
join stores st
on s.store_id = st.store_id
group by 1,2,3
order by 1,2,3 
),
Growth_Ratio
AS
(
 Select
	store_name,
	year,
	LAG(total_sale,1) OVER(partition by store_name order by year) as last_year_sale,
	total_sale as current_year_sale
from yearly_sales
)

SELECT 
	store_name,
	year,
	last_year_sale,
	current_year_sale,
	ROUND((current_year_sale - last_year_sale)::numeric/last_year_sale::numeric * 100,3) as growth_ratio
FROM growth_ratio
where
	last_year_sale is NOT NULL
	AND
	year<>EXTRACT(YEAR FROM CURRENT_DATE);


-- 18.Calculate the correlation between product price and warranty claims for
-- products sold in the last five years, segmented by price range.

SELECT
	CASE
		when p.price < 500 then 'LESS EXPENSIVE PRODUCT'
		when p.price between 500 and 1000 then'MID RANGE PRODUCT'
		else 'EXPENSIVE PRODUCT'
	END as price_Segment,
	count(w.claim_id) as Total_claims
FROM warranty as w
left join sales as s
on w.sale_id = s.sale_id
join products as p
on p.product_id =s.product_id
where claim_date >= CURRENT_DATE - INTERVAL '5 year'
group by 1


--19. Identify the store with the highest percentage of "Paid Repaired" claims relative to total claims filed
WITH paid_repair
AS
(select 
	s.store_id,
	count(w.claim_id) as paid_repaired
from sales as s
Right join warranty as w
on s.sale_id = w.sale_id
where w.repair_status = 'Paid Repaired'
Group by 1
),

total_repaired
AS
(select 
	s.store_id,
	count(w.claim_id) as total_repaired
from sales as s
Right join warranty as w
on s.sale_id = w.sale_id
Group by 1
)

select
	tr.store_id,
	st.store_name,
	pr.paid_repaired,
	tr.total_repaired,
	ROUND(pr.paid_repaired::numeric /tr.total_repaired::numeric *100,2) as percentage_paid_repaired
from paid_repair as pr
JOIN
total_repaired as tr
on pr.store_id = tr.store_id
JOIN stores as st
on st.store_id = tr.store_id
ORDER BY percentage_paid_repaired DESC

--20. Write a query to calculate the monthly running total of sales for each store
--over the past four years and compare trends during this period.

WITH monthly_sales
AS
(
SELECT
s.store_id,
EXTRACT(YEAR from s.sale_date) as year,
EXTRACT(MONTH from s.sale_date) as month,
SUM(p.price * s.quantity) as total_revenue
from sales as s
join products as p
on p.product_id = s.product_id
GROUP BY s.store_id,year,month
ORDER BY s.store_id,year,month
)
SELECT 
	store_id,
	month,
	year,
	total_revenue,
	SUM(total_revenue) OVER(PARTITION BY store_id ORDER BY year, month) as running_total
FROM monthly_sales


