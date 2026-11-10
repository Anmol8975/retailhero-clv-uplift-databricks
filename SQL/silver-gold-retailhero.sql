CREATE OR REPLACE TABLE uplift_model.gold.model_features AS
SELECT
  u.client_id,
  u.treatment_flg,
  u.target,

  -- client demographics
  c.age,
  c.gender,
  to_timestamp(c.first_issue_date, 'yyyy-MM-dd HH:mm:ss') AS first_issue_date,
  to_timestamp(c.first_redeem_date, 'yyyy-MM-dd HH:mm:ss') AS first_redeem_date,

  -- purchase behavior features
  p.total_transactions,
  p.total_regular_points_received,
  p.total_express_points_received,
  p.total_regular_points_spent,
  p.total_express_points_spent,
  p.total_purchase_sum,
  p.total_trn_sum_from_iss,
  p.total_trn_sum_from_red,
  p.total_product_quantity,
  p.total_unique_stores,
  p.total_unique_products,
  p.avg_regular_points_received,
  p.avg_express_points_received,
  p.avg_regular_points_spent,
  p.avg_express_points_spent,
  p.avg_purchase_sum,
  p.avg_product_quantity,
  p.avg_trn_sum_from_iss,
  p.avg_trn_sum_from_red,
  p.pct_weekend_purchases,
  p.last_transaction_datetime,
  p.first_transaction_datetime,
  DATEDIFF(DAY, p.first_transaction_datetime, p.last_transaction_datetime) AS customer_tenure_days,

  -- product-level features
  pr.alcohol_spend,
  pr.own_brand_spend,
  pr.unique_top_categories,
  pr.unique_sub_categories,
  pr.unique_brands

FROM uplift_model.bronze.uplift_train u
JOIN uplift_model.bronze.clients c ON u.client_id = c.client_id
JOIN uplift_model.silver.purchases_features p ON u.client_id = p.client_id
JOIN uplift_model.silver.product_features pr ON u.client_id = pr.client_id;