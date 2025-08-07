SELECT *
FROM walmart
order by invoice_id ;

SELECT COUNT(distinct invoice_id)
FROM walmart;
 
 SET SQL_SAFE_UPDATES = 0;
-- ----------------------------------------------------  FINDING Duplicates --------------------------------------------------------------------------------------
-- -------------------------------  ( Cant use CTE AND ROW NUMBER FOR DELETION IN MYSQL )-------------------------------------------------------------------------------------------------------------------------
SELECT COUNT(invoice_id) - COUNT(DISTINCT invoice_id) AS duplicate_count
FROM walmart; -- 9969

SELECT invoice_id, COUNT(*) AS total_count
FROM walmart
GROUP BY invoice_id
HAVING COUNT(*) > 1;

WITH CTE AS (
           SELECT invoice_id,
               row_number() OVER(PARTITION BY invoice_id order by invoice_id)as ranks
               FROM walmart
) 
select * from CTE;
-- ----------------------------------------------------  Deleting Duplicates --------------------------------------------------------------------------------------
-- ------------------------------------------------------------------------------------------------------------------------------------------------------
ALTER TABLE walmart ADD COLUMN id INT AUTO_INCREMENT PRIMARY KEY;

DELETE w1 
FROM walmart w1
JOIN walmart w2 
ON w1.invoice_id = w2.invoice_id 
AND w1.id > w2.id;

alter table walmart
drop column id;

-- ------------------------------------------------DATA EXPLORATION -------------------------------------------------------------------------------------------------
SELECT *
FROM walmart;

-- Q1) Find different payment method and number of transactions,number of quantity sold

SELECT payment_method,Count(invoice_id) as number_of_transactions,SUM(quantity) as number_of_quantity_sold
FROM walmart
GROUP by payment_method
order by number_of_transactions desc;

-- Q2) Identify the highest rated category in each branch,displaying the branch, category and AVG rating

WITH ranked_data AS (
    SELECT Branch, 
           category, 
           Round(AVG(rating),2) AS avg_rating,
           MAX(rating) as highest_rating,
           RANK() OVER (PARTITION BY Branch ORDER BY avg(rating) DESC) AS ranks
    FROM walmart 
    GROUP BY Branch, category
)
SELECT Branch, category, avg_rating, highest_rating
FROM ranked_data
WHERE ranks = 1;

-- Q3) Identify the busiest day for each branch based on the number of transactions 
SELECT *
FROM(
SELECT Branch, Count(invoice_id),dayname(str_to_date(date,'%d/%m/%y')),
RANK() OVER(partition by Branch order by Count(invoice_id) DESC) as ranks
FROM walmart
group by Branch,dayname(str_to_date(date,'%d/%m/%y')) 
) as busiest_days
where ranks =1;

-- Q4) Determine the average, minimum and maximum rating of category for each city,
-- List the city, average_rating, min_rating and max_rating,	

SELECT category,city,round(avg(rating),2) as avg_rating,Min(rating),max(rating),	
rank() over(partition by category order by city ) as ranks
FROM walmart
GROUP BY category,city
order by category;

-- Q5) Calculate the total profit for each category by considering total profit as 
-- (unit_price + quantity + profit_margin). List category and total_profit, ordered from highest to lowest profit 

SELECT category,round(Sum(total),2)as revenue,round(sum(total*profit_margin),2) as total_profit
FROM walmart
group by category
order by sum(total*profit_margin) DESC;

-- Q6) Determine the most common payment method for each branch.
-- Display Branch and the preffered payment method 

SELECT Branch,
	   payment_method,
       Count(*) as total_transactions
from walmart
group by Branch,payment_method
order by Branch;

select s.Branch,s.payment_method,s.total_transactions
from (
      SELECT Branch,
             payment_method,
             Count(*) as total_transactions,
             Rank() over(partition by Branch order by Count(*) desc) as ranks
             FROM walmart
             group by Branch,payment_method
) as s
where ranks =1;

-- Q7) Categorize sales into 3 groups morning, afternoon and evening 
-- find out which of the shift and no. of invoices

-- SELECT CAST(time AS TIME) AS converted_time FROM walmart;
-- SELECT CONVERT(time_column, TIME) AS converted_time FROM your_table;
-- UPDATE your_table 
-- SET time_column = CAST(time_column AS TIME);
-- ALTER TABLE your_table 
-- MODIFY COLUMN time_column TIME;
---------------------------------------------------------------------------------------------------------------------
-- SELECT  STR_TO_DATE(time, '%H:%i:%s') AS converted_time FROM walmart; -- for 24 hour format
-- SELECT STR_TO_DATE(time, '%h:%i %p') AS converted_time FROM walmart; -- for 12 hour format
UPDATE walmart 
SET time = STR_TO_DATE(time, '%H:%i:%s');

ALTER TABLE walmart MODIFY COLUMN time TIME;

SELECT Branch,
      case 
          when hour(time)<12 THEN 'morning'
          when hour(time) between 12 and 17 then 'afternoon'
          else 'evening'
	end day_time,
    Count(*)
FROM walmart
group by Branch,day_time
Order by Branch,count(*) desc;
--------------------------------------------------------------------------------------------------------------------------------------------------
-- Q8)Identify 5 branch with highest decrese ratio in revenue compare to last year * (current year 2023 and the last year 2022
select distinct(date)
from walmart;
WITH revenue_2022
as (
    select 
          Branch,
          SUM(total) as revenue
	FROM walmart
    Where year(str_to_date(date,'%d/%m/%y')) = 2022
    GROUP BY Branch
),
revenue_2023
as (
     select 
          Branch,
          SUM(total) as revenue
	FROM walmart
    Where year(str_to_date(date,'%d/%m/%y')) = 2023
    GROUP BY Branch
)
select 
      ls.Branch,
	  ls.revenue as last_year_revenue,
      cs.revenue as current_year_revenue,
      round(( ls.revenue -cs.revenue) / ls.revenue *100,2) as 'percentage_decrese(%)'
FROM revenue_2022 as ls
JOIN revenue_2023 as cs
on ls.Branch = cs.Branch
where ls.revenue > cs.revenue
order by  round(( ls.revenue -cs.revenue) / ls.revenue *100,2) DESC
LIMIT 5;
