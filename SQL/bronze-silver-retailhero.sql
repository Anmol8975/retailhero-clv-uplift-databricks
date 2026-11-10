CREATE OR REPLACE TABLE uplift_model.silver.purchases_features AS
SELECT client_id,
       COUNT(DISTINCT transaction_id) AS total_transactions,
       SUM(regular_points_received) AS total_regular_points_received,
       SUM(express_points_received) AS total_express_points_received,
       SUM(regular_points_spent) AS total_regular_points_spent,
       SUM(express_points_spent) AS total_express_points_spent,
       SUM(purchase_sum) AS total_purchase_sum,
       SUM(trn_sum_from_iss) AS total_trn_sum_from_iss,
       SUM(trn_sum_from_red) AS total_trn_sum_from_red,
       SUM(product_quantity) AS total_product_quantity,
       COUNT(DISTINCT store_id) AS total_unique_stores,
       COUNT(DISTINCT product_id) AS total_unique_products,
       AVG(regular_points_received) AS avg_regular_points_received,
       AVG(express_points_received) AS avg_express_points_received,
       AVG(regular_points_spent) AS avg_regular_points_spent,
       AVG(express_points_spent) AS avg_express_points_spent,
       AVG(purchase_sum) AS avg_purchase_sum,
       AVG(product_quantity) AS avg_product_quantity,
       AVG(trn_sum_from_iss) AS avg_trn_sum_from_iss,
       AVG(trn_sum_from_red) AS avg_trn_sum_from_red,
       AVG(CASE WHEN EXTRACT(DAYOFWEEK FROM to_timestamp(transaction_datetime, 'yyyy-MM-dd HH:mm:ss')) IN (1,7) THEN 1 ELSE 0 END) AS pct_weekend_purchases,
       MAX(to_timestamp(transaction_datetime, 'yyyy-MM-dd HH:mm:ss')) AS last_transaction_datetime,
       MIN(to_timestamp(transaction_datetime, 'yyyy-MM-dd HH:mm:ss')) AS first_transaction_datetime
FROM uplift_model.bronze.purchases
GROUP BY client_id;


CREATE OR REPLACE TABLE uplift_model.silver.product_features AS
SELECT
  pur.client_id,
  SUM(CASE WHEN prod.is_alcohol = 1 THEN pur.purchase_sum ELSE 0 END) AS alcohol_spend,
  SUM(CASE WHEN prod.is_own_trademark = 1 THEN pur.purchase_sum ELSE 0 END) AS own_brand_spend,
  COUNT(DISTINCT prod.level_1) AS unique_top_categories,
  COUNT(DISTINCT prod.level_2) AS unique_sub_categories,
  COUNT(DISTINCT prod.brand_id) AS unique_brands
FROM uplift_model.bronze.purchases pur
JOIN uplift_model.bronze.products prod ON pur.product_id = prod.product_id
GROUP BY pur.client_id;