use chinook;

-- OBJECTIVE QUESTIONS

-- Q1:Does any table have missing values or duplicates? If yes how would you handle it ?
-- for dupplicates (used primary key)
Select customer_id, count(*)
from customer
group by customer_id
having count(*) > 1;
-- similarly for other tables

-- for finding nulls in tables
select  * 
from track 
where track_id is null or name is null 
or album_id is null or media_type_id is null 
or genre_id is null or composer is null
or  milliseconds is null or  bytes is null 
or unit_price is null;



-- Ques 2: Find the top-selling tracks and top artist in the USA and identify their most famous genres.
select il.track_id, t.name as track, sum(il.unit_price*quantity) as total_rev,
sum(il.quantity) as number_of_tracks,
a.name as artist, g.name as genrename
from invoice_line il
join invoice i on il.invoice_id=i.invoice_id
join track t on il.track_id=t.track_id
join album al on t.album_id=al.album_id
join artist a on al.artist_id=a.artist_id
join genre g on t.genre_id=g.genre_id
where i.billing_country='USA'
group by il.track_id, t.name, a.name, g.name
order by total_rev desc, number_of_tracks desc;  -- because rev same for multiple

-- Ques 3: What is the customer demographic breakdown (age, gender, location) of Chinook's customer base?
select country, coalesce(state,'Not Available') as state, city, count(distinct customer_id) as customer_count
from customer
group by country, state, city
order by country;

-- Ques 4: Calculate the total revenue and number of invoices for each country, state, and city
select billing_country,billing_state, billing_city, sum(total) as total_revenue,
count(distinct invoice_id) as invoices_count
from invoice
group by billing_country,billing_state, billing_city
order by total_revenue desc;

-- Ques 5: Find the top 5 customers by total revenue in each country
with total as(
select c.country, i.customer_id, concat(c.first_name,' ',c.last_name) as full_name,
sum(i.total) as total_rev
from invoice i
join customer c on i.customer_id=c.customer_id
group by c.country, i.customer_id, concat(c.first_name,' ',c.last_name)
),
ranked as(
select *,
rank() over(partition by country order by total_rev desc) as rnk
from total
)
select *
from ranked
where rnk<=5;

-- Q6: Identify the top-selling track for each customer (Quantity-wise)
with total as(
select c.customer_id, concat(c.first_name,' ',c.last_name) as full_name, il.track_id, t.name,
sum(il.quantity) as total_units
from customer c
join invoice i on c.customer_id=i.customer_id
join invoice_line il on i.invoice_id=il.invoice_id
join track t on il.track_id=t.track_id
group by c.customer_id, il.track_id, t.name
),
ranked as(
select *,
row_number() over(partition by customer_id order by total_units desc, track_id) as rnk
from total     
)
select *
from ranked 
where rnk=1
order by total_units desc;

-- Q7: Are there any patterns or trends in customer purchasing behavior (e.g., frequency of purchases, preferred payment methods, average order value)?
with customer_spending as(
select customer_id, 
sum(total) as total_spent,
round(sum(total)/count(distinct invoice_id),2) as avg_order_value,
max(invoice_date) as last_purchase_date,
count(distinct invoice_id) as n_transactions

from invoice 
group by customer_id
),
basket_size as(
select i.customer_id, i.invoice_id, count(distinct il.invoice_line_id) as basket_s
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
group by i.customer_id, i.invoice_id
),
avg_basket_size as(
select customer_id, round(avg(basket_s),2) as average_basket_size
from basket_size
group by customer_id
)

select cs.customer_id, cs.total_spent, cs.avg_order_value,
cs.last_purchase_date, datediff('2020-12-30',cs.last_purchase_date) as days_since_last_purchase, 
cs.n_transactions as total_purchases, bs.average_basket_size

from customer_spending cs
join avg_basket_size bs on cs.customer_id=bs.customer_id;




-- Q8:What is the customer churn rate?
with purchased_earlier as(
select customer_id, count(*) as n_purchases
from invoice
where invoice_date < date_sub('2020-12-30', interval 6 month)
group by customer_id
),

purchased_in_last6_months as(
select customer_id, count(*) as purchases
from invoice
where invoice_date between date_sub('2020-12-30', interval 6 month) and '2020-12-30'
group by customer_id
),

retained_cust as(
select l.customer_id
from purchased_earlier e
join purchased_in_last6_months l on e.customer_id=l.customer_id
)

select
round(((select count(*) from purchased_earlier) - (select count(*) from retained_cust))*100.0/(select count(*) from purchased_earlier),2) as churn_rate_percent;


-- Q9: Calculate the percentage of total sales contributed by each genre in the USA and identify the best-selling genres and artists.
-- part 1(USA)
with genre_sales as(
select g.genre_id, g.name, sum(il.unit_price*il.quantity) as total_sales
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
join track t on il.track_id=t.track_id
join genre g on t.genre_id=g.genre_id
join album al on t.album_id=al.album_id
join artist ar on al.artist_id=ar.artist_id
where i.billing_country='USA'
group by g.genre_id
)

select *, round((total_sales*100.0/(select sum(total) from invoice where billing_country='USA')),2) as percentage
from genre_sales
order by total_sales desc;

-- part 2 of Q9: (not USA specific)
with artist_sales as(
select ar.artist_id, ar.name as artist_name, g.genre_id, g.name as genre_name, sum(il.unit_price*il.quantity) as total_rev,
row_number() over( order by sum(il.unit_price*il.quantity) desc) as rnk
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
join track t on il.track_id=t.track_id
join genre g on t.genre_id=g.genre_id
join album al on t.album_id=al.album_id
join artist ar on al.artist_id=ar.artist_id
group by ar.artist_id, ar.name, g.genre_id, g.name
)

select *, round((total_rev*100.0/(select sum(total) from invoice where billing_country='USA')),2) as percentage
from artist_sales
order by total_rev desc;


-- Q10: Find customers who have purchased tracks from at least 3 different genres
select c.customer_id, concat(c.first_name,' ', c.last_name) as name, count(distinct t.genre_id) as number_of_genres
from customer c
join invoice i on c.customer_id=i.customer_id
join invoice_line il on i.invoice_id=il.invoice_id
join track t on il.track_id=t.track_id
group by c.customer_id, concat(c.first_name,' ', c.last_name)
having count(distinct t.genre_id)>=3 
order by number_of_genres desc;

-- Q11: Rank genres based on their sales performance in the USA
select t.genre_id, g.name, sum(il.unit_price*il.quantity) as genre_sales,
dense_rank() over(order by sum(il.unit_price*il.quantity) desc) as rnk
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
join track t on il.track_id=t.track_id
join genre g on t.genre_id=g.genre_id
where i.billing_country='USA'
group by t.genre_id, g.name;


-- Q12: Identify customers who have not made a purchase in the last 3 months
with req_customers as(
select c.customer_id, concat(c.first_name,' ', c.last_name) as Customer_name
from customer c
left join invoice i on c.customer_id=i.customer_id and i.invoice_date between date_sub('2020-12-30', interval 3 month) and '2020-12-30'
where i.invoice_id is null
)
select r.customer_id, r.Customer_name, max(i1.invoice_date) as last_purchase_date
from req_customers r
join invoice i1 on r.customer_id=i1.customer_id
where i1.invoice_date< date_sub('2020-12-30', interval 3 month)
group by r.customer_id,  r.Customer_name
order by last_purchase_date desc;



-- SUBJECTIVE QUESTIONS

-- Sub Q1: Recommend the three albums from the new record label that should be prioritised for advertising and promotion in the USA based on genre sales analysis.

with genre_data as(
select t.genre_id, g.name, sum(il.unit_price*il.quantity) as genre_sales, 
sum(il.quantity) as tracks_sold, 
(sum(il.unit_price*il.quantity))/sum(il.quantity) as price_per_track
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
join track t on il.track_id=t.track_id
join genre g on t.genre_id=g.genre_id
where i.billing_country='USA'
group by t.genre_id, g.name
order by genre_sales desc
),

new_records as(
select t.track_id, t.name, t.album_id, t.media_type_id, t.genre_id, t.unit_price
from track t
left join invoice_line il on t.track_id=il.track_id
where il.invoice_line_id is null
),

albums_data as(
select album_id, genre_id, count(distinct track_id) as count_tracks, sum(unit_price) as price
from new_records
group by album_id , genre_id
),

indexing as(
select a.album_id, sum(a.price*g.genre_sales) as new_index
from albums_data a
join genre_data g on a.genre_id=g.genre_id
group by a.album_id)

select i.album_id , al.title as album_title
from indexing i
join album al on i.album_id=al.album_id
order by new_index desc
limit 3;

-- Q2: Determine the top-selling genres in countries other than the USA and identify any commonalities or differences.

-- overall analysis
select t.genre_id, g.name, sum(il.unit_price*il.quantity) as genre_sales
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
join track t on il.track_id=t.track_id
join genre g on t.genre_id=g.genre_id
where i.billing_country<>'USA'
group by t.genre_id, g.name
order by genre_sales desc;

-- country-wise analysis

-- USA
select t.genre_id, g.name, sum(il.unit_price*il.quantity) as genre_sales
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
join track t on il.track_id=t.track_id
join genre g on t.genre_id=g.genre_id
where i.billing_country='USA'
group by t.genre_id, g.name
order by genre_sales desc;

-- other countries(except USA)
with sales_data as(
select i.billing_country, g.name as genre_name, sum(il.unit_price*il.quantity) as genre_sales_country
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
join track t on il.track_id=t.track_id
join genre g on t.genre_id=g.genre_id
where i.billing_country<>'USA'
group by i.billing_country, g.name
),
ranked_data as(
select billing_country, genre_name, genre_sales_country,
dense_rank() over(partition by billing_country order by genre_sales_country desc) as rnk
from sales_data
),
final_output as(
select *
from ranked_data
where rnk<=2
) -- analysis
select count(distinct billing_country) as countries_with_rock_1, (select count(distinct billing_country) from final_output) total_countries
from final_output
where genre_name='Rock' and rnk=1;



-- Q#3: Customer Purchasing Behavior Analysis: How do the purchasing habits (frequency, basket size, spending amount) of long-term customers differ from those of new customers? What insights can these patterns provide about customer loyalty and retention strategies?

with overall_data as(
select
c.customer_id, c.first_name, c.last_name, i.invoice_id, i.invoice_date,
il.invoice_line_id, il.track_id, il.unit_price, il.quantity,
(il.unit_price * il.quantity) as total
from customer c
join invoice i on c.customer_id = i.customer_id
join invoice_line il on i.invoice_id = il.invoice_id
),

customers_data as(
select customer_id,
min(invoice_date) as first_purchase_date,
max(invoice_date) as recent_purchase_date,
datediff(max(invoice_date), min(invoice_date)) as purchasing_period,
count(distinct invoice_id) as count_of_invoices,
sum(total) as total_amount_spent
from overall_data
group by customer_id
),

categorised_final_data as (
select *,
case
when first_purchase_date < '2017-12-31' and purchasing_period > 365 * 2 then 'long term customer'
when first_purchase_date > '2017-12-31' then 'new customer'
else null
end as customer_category
from customers_data
),

basket_sizes as (
select
c.customer_id, o.invoice_id,
count(distinct o.track_id) as basket_size,
sum(o.total) as basket_price
from categorised_final_data c
join overall_data o on c.customer_id = o.customer_id
group by c.customer_id, o.invoice_id
),

avg_basket_sizes as (
select
customer_id,
avg(basket_size) as avg_basket_size
from basket_sizes
group by customer_id
),

parameters_compared as (
select
c.customer_id, c.customer_category, b.avg_basket_size,
round((count_of_invoices * 365.0 / purchasing_period), 2) as frequency_yearly,
total_amount_spent,
(total_amount_spent / count_of_invoices) as avg_order_value
from categorised_final_data c
join avg_basket_sizes b
on c.customer_id = b.customer_id
)

select customer_category,
count(*) as count_customers,
round(avg(avg_basket_size), 2) as avg_cat_basket_size,
round(avg(frequency_yearly), 2) as avg_cat_freq,
round(avg(total_amount_spent), 2) as avg_cat_total_spend,
round(avg(avg_order_value), 2) as avg_order_value_cat
from parameters_compared
group by customer_category;


-- Q4: Product Affinity Analysis: Which music genres, artists, or albums are frequently purchased together by customers? How can this information guide product recommendations and cross-selling initiatives?

-- genre_pairs
with combined_data as(
select 
il.invoice_id, il.track_id, 
t.genre_id, g.name as genre_name
from invoice_line il 
join track t on il.track_id=t.track_id
join genre g on t.genre_id=g.genre_id
),
genre_pairs as(
select c1.invoice_id, 
c1.genre_id as genre1_id, c1.genre_name as genre1_name,
c2.genre_id as genre2_id, c2.genre_name as genre2_name
from combined_data c1
join combined_data c2 on c1.invoice_id=c2.invoice_id and c1.genre_id<c2.genre_id
)

select genre1_id, genre1_name, 
genre2_id, genre2_name, count(distinct invoice_id) as together_occur_in_invoices,
round(count(distinct invoice_id)*100.0/(select count(distinct invoice_id) from invoice_line),2) as percent_invoices_where_pair_occurs
from genre_pairs
group by genre1_id, genre2_id
order by together_occur_in_invoices desc;

-- album pairs co-occur
with combined_data as(
select 
il.invoice_id, il.track_id, 
al.album_id, al.title as album_name
from invoice_line il 
join track t on il.track_id=t.track_id
join album al on al.album_id=t.album_id
),
album_pairs as(
select c1.invoice_id, 
c1.album_id as album1_id, c1.album_name as album1_name,
c2.album_id as album2_id, c2.album_name as album2_name
from combined_data c1
join combined_data c2 on c1.invoice_id=c2.invoice_id and c1.album_id<c2.album_id
)

select album1_id, album1_name, 
album2_id, album2_name, count(distinct invoice_id) as together_occur_in_invoices,
round(count(distinct invoice_id)*100.0/(select count(distinct invoice_id) from invoice_line),2) as percent_invoices_where_pair_occurs
from album_pairs
group by album1_id, album2_id
order by together_occur_in_invoices desc;

-- artist pairs
with combined_data as(
select 
il.invoice_id, il.track_id, 
ar.artist_id, ar.name as artist_name
from invoice_line il 
join track t on il.track_id=t.track_id
join album al on al.album_id=t.album_id
join artist ar on al.artist_id=ar.artist_id
),
artist_pairs as(
select c1.invoice_id, 
c1.artist_id as artist1_id, c1.artist_name as artist1_name,
c2.artist_id as artist2_id, c2.artist_name as artist2_name
from combined_data c1
join combined_data c2 on c1.invoice_id=c2.invoice_id and c1.artist_id<c2.artist_id
)

select artist1_id, artist1_name, 
artist2_id, artist2_name, count(distinct invoice_id) as together_occur_in_invoices,
round(count(distinct invoice_id)*100.0/(select count(distinct invoice_id) from invoice_line),2) as percent_invoices_where_pair_occurs
from artist_pairs
group by artist1_id, artist2_id
having count(distinct invoice_id)>=10
order by together_occur_in_invoices desc;




-- Q5: Regional Market Analysis: Do customer purchasing behaviors and churn rates vary across different geographic regions or store locations? How might these correlate with local demographic or economic factors?

-- purchasing behaviors as per location
select i.billing_country, 
count(distinct i.invoice_id) as total_transactions,
count(distinct i.customer_id) as customer_count,
round(sum(il.unit_price*il.quantity)/ count(distinct i.customer_id),2) as avg_sales_per_customer,
round(count(il.invoice_line_id)/count(distinct il.invoice_id),2) as avg_basket_size
from invoice i 
join invoice_line il on i.invoice_id=il.invoice_id
group by i.billing_country;

-- churn rates as per location

with earlier_customers as(
select billing_country, customer_id, count(distinct invoice_id) as number_purchases
from invoice 
where invoice_date< date_sub('2020-12-30', interval 6 month)
group by billing_country, customer_id
),
last6_months_customers as(
select billing_country, customer_id, count(distinct invoice_id) as number_purchases
from invoice
where invoice_date between date_sub('2020-12-30', interval 6 month) and '2020-12-30'
group by billing_country,customer_id
),
churned_customers as(
select e.billing_country,e.customer_id
from earlier_customers e 
left join last6_months_customers l on e.customer_id=l.customer_id and e.billing_country=l.billing_country
where l.billing_country is null
),
countrywise_count_churned as(
select billing_country, count(*) as n_cust_churned
from churned_customers
group by billing_country
),
countrywise_count_earlier as(
select billing_country, count(*) as n_cust_in_earlier_period
from earlier_customers
group by billing_country
)
select ce.billing_country, coalesce(n_cust_churned,0) as n_customers_churned,
n_cust_in_earlier_period, coalesce(round((n_cust_churned*100.0/n_cust_in_earlier_period),2),0) as churn_rate
from countrywise_count_earlier ce
left join countrywise_count_churned cc on ce.billing_country=cc.billing_country
order by churn_rate desc, billing_country asc;


-- Q6: Customer Risk Profiling: 
-- Based on customer profiles (age, gender, location, purchase history), 
-- which customer segments are more likely to churn or pose a higher risk of reduced spending? 
-- What factors contribute to this risk?


-- Below code was used to check, whether there are cases where billing country is different from customer's country.
-- NO SUCH case found

-- select distinct c.customer_id, c.country, i.billing_country
-- from customer c
-- join invoice i on c.customer_id=i.customer_id
-- where c.country<> i.billing_country
-- order by c.customer_id

with customer_spending as(
select c.customer_id, i.billing_country,
sum(i.total) as total_spent,
round(sum(i.total)/count(distinct i.invoice_id),2) as avg_spend_per_transaction,
max(i.invoice_date) as last_purchase_date,
count(distinct i.invoice_id) as n_transactions
from customer c
join invoice i on c.customer_id=i.customer_id
group by c.customer_id, i.billing_country
),
basket_size as(
select i.customer_id, i.invoice_id, count(distinct il.invoice_line_id) as basket_s
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
group by i.customer_id, i.invoice_id
),
avg_basket_size as(
select customer_id, round(avg(basket_s),2) as average_basket_size
from basket_size
group by customer_id
),
combined_data as(
select cs.customer_id, cs.billing_country, cs.total_spent, cs.avg_spend_per_transaction,
cs.last_purchase_date, datediff('2020-12-30',cs.last_purchase_date) as days_since_last_purchase, 
cs.n_transactions as total_purchases, bs.average_basket_size,
ntile(3) over(order by cs.n_transactions) as freq_tile,
ntile(3) over(order by cs.total_spent) as spend_tile
from customer_spending cs
join avg_basket_size bs on cs.customer_id=bs.customer_id
),
profiling as(
select customer_id, billing_country, total_spent, avg_spend_per_transaction, last_purchase_date,
days_since_last_purchase, total_purchases, average_basket_size, 
case
when days_since_last_purchase>180 and freq_tile = 1 then 'Critical Risk'
when days_since_last_purchase>180 then 'High Risk(churn risk)'
when freq_tile = 1 then 'Medium Risk(low freq risk)'
when spend_tile = 1  then 'Low Spender(value risk)'
else 'Low Risk'
end as Risk_profiling
from combined_data)
select Risk_profiling, avg(total_spent) as avg_total_spent_of_profile, avg(avg_spend_per_transaction) as avg_spent_per_transac_of_profile, 
avg(days_since_last_purchase) as avg_of_days_since_last_purchase, avg(total_purchases) as avg_num_of_total_purchases_of_profile,
avg(average_basket_size) as avg_bskt_size_of_profile
from profiling
group by Risk_profiling;



-- Q7: Customer Lifetime Value Modeling: How can you leverage customer data (tenure, purchase history, engagement) to predict the lifetime value of different customer segments? This could inform targeted marketing and loyalty program strategies. Can you observe any common characteristics or purchase patterns among customers who have stopped purchasing?

with customer_spending as(
select c.customer_id, i.billing_country,
sum(i.total) as total_spent,
round(sum(i.total)/count(distinct i.invoice_id),2) as avg_spend_per_transaction,
max(i.invoice_date) as last_purchase_date,
count(distinct i.invoice_id) as n_transactions
from customer c
join invoice i on c.customer_id=i.customer_id
group by c.customer_id, i.billing_country
),
basket_size as(
select i.customer_id, i.invoice_id, count(distinct il.invoice_line_id) as basket_s
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
group by i.customer_id, i.invoice_id
),
avg_basket_size as(
select customer_id, round(avg(basket_s),2) as average_basket_size
from basket_size
group by customer_id
),
combined_data as(
select cs.customer_id, cs.billing_country, cs.total_spent, cs.avg_spend_per_transaction,
cs.last_purchase_date, datediff('2020-12-30',cs.last_purchase_date) as days_since_last_purchase, 
cs.n_transactions as total_purchases, bs.average_basket_size,
ntile(3) over (order by cs.total_spent) as total_spent_tile,
ntile(3) over (order by cs.avg_spend_per_transaction) as avg_spend_tile,
ntile(3) over (order by cs.n_transactions) as purchase_freq_tile,
ntile(3) over (order by bs.average_basket_size) as basket_size_tile
from customer_spending cs
join avg_basket_size bs on cs.customer_id=bs.customer_id
)
select customer_id,billing_country, total_spent, avg_spend_per_transaction, last_purchase_date,
days_since_last_purchase, total_purchases, average_basket_size, 
case
when total_spent_tile = 1 and avg_spend_tile = 1 then 'Low Value'
when total_spent_tile = 3 and avg_spend_tile = 3 then 'High Value'
else 'Medium Value' 
end as Cust_segment,
case
when days_since_last_purchase <= 180 then 'Active'
else 'Inactive'
end as activity_status,
case
when basket_size_tile = 1 then 'Small Basket Purchaser'
when basket_size_tile = 2 then 'Medium Basket Purchaser'
else 'Large Basket Purchaser'
end as Basket_size_classified,
case
when purchase_freq_tile = 1 then 'Less Frequent purchaser'
when purchase_freq_tile = 2 then 'Moderately Frequent Purchaser'
else 'Highly Frequent Purchaser'
end as purchasing_behavior
from combined_data
order by total_spent desc;

-- QUES 8 and 9 didnt require sql query. their solution is present in docs file

-- Q10:
alter table album
add column ReleaseYear integer;


-- Q11: Chinook is interested in understanding the purchasing behavior of customers based on their geographical location. They want to know the average total amount spent by customers from each country, along with the number of customers and the average number of tracks purchased per customer. Write an SQL query to provide this information.

with customers_data as(
select i.customer_id, i.billing_country,
sum(il.unit_price*il.quantity) as total_spent,
count(il.track_id) as tracks_purchased
from invoice i
join invoice_line il on i.invoice_id=il.invoice_id
group by i.customer_id, i.billing_country
)
select billing_country, round(avg(total_spent),2) as avg_total_spent_per_customer, 
count(distinct customer_id) as number_of_customers,
round(avg(tracks_purchased),2) as avg_tracks_per_customer
from customers_data
group by billing_country
order by avg_total_spent_per_customer desc;