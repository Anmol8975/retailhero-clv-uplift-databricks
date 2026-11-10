# SQL Transformations: Medallion Pipeline (`Bronze ➔ Silver ➔ Gold`)

This folder contains the **Databricks SQL** transformation scripts executed by the **`retailhero-bronze-gold-job`** workflow on the **Serverless Starter Warehouse** to convert raw Bronze Delta tables into client-level Silver aggregations and a model-ready Gold feature table.

---

## Script Overview

| Script | Job Task | Upstream Tables | Downstream Table(s) | Execution Time |
| :--- | :--- | :--- | :--- | :--- |
| [`bronze-silver-retailhero.sql`](./bronze-silver-retailhero.sql) | `bronze-silver` | `uplift_model.bronze.purchases`<br>`uplift_model.bronze.products` | `uplift_model.silver.purchases_features`<br>`uplift_model.silver.product_features` | `55s` |
| [`silver-gold-retailhero.sql`](./silver-gold-retailhero.sql) | `silver-gold` | `uplift_model.bronze.uplift_train`<br>`uplift_model.bronze.clients`<br>`uplift_model.silver.purchases_features`<br>`uplift_model.silver.product_features` | `uplift_model.gold.model_features` | `11s` |

*(In the Databricks Workspace, these scripts correspond to the saved queries `bronze-silver-retail-sql` and `silver-gold-retail-sql`.)*

---

## 1. Bronze ➔ Silver (`bronze-silver-retailhero.sql`)

Aggregates raw transaction line items (`45.78M+` rows) and product metadata down to the **`client_id` grain** across two Silver Delta tables.

### `uplift_model.silver.purchases_features`
Built from `uplift_model.bronze.purchases` (`GROUP BY client_id`), producing `client_id` plus **22 behavioral and loyalty features**:
* **Activity & Basket Diversity:** `total_transactions` (`COUNT(DISTINCT transaction_id)`), `total_unique_stores`, `total_unique_products`, and `total_product_quantity`
* **Spend & Loyalty Totals (`SUM`):** `total_purchase_sum`, `total_trn_sum_from_iss`, `total_trn_sum_from_red`, `total_regular_points_received`, `total_express_points_received`, `total_regular_points_spent`, and `total_express_points_spent`
* **Per-Record Averages (`AVG`):** `avg_purchase_sum`, `avg_product_quantity`, `avg_trn_sum_from_iss`, `avg_trn_sum_from_red`, `avg_regular_points_received`, `avg_express_points_received`, `avg_regular_points_spent`, and `avg_express_points_spent`
* **Temporal Features:** Parses string `transaction_datetime` using `to_timestamp(..., 'yyyy-MM-dd HH:mm:ss')` to derive `first_transaction_datetime`, `last_transaction_datetime`, and `pct_weekend_purchases` (`DAYOFWEEK(...) IN (1, 7)`)

### `uplift_model.silver.product_features`
Joins `uplift_model.bronze.purchases` with `uplift_model.bronze.products` on `product_id` (`GROUP BY client_id`), producing `client_id` plus **5 category and brand affinity features**:
* **Specialty Spend:** `alcohol_spend` (`is_alcohol = 1`) and `own_brand_spend` (`is_own_trademark = 1`)
* **Assortment Breadth:** `unique_top_categories` (`level_1`), `unique_sub_categories` (`level_2`), and `unique_brands` (`brand_id`)

---

## 2. Silver ➔ Gold (`silver-gold-retailhero.sql`)

Builds the final **`uplift_model.gold.model_features`** table (**35 columns**) by inner-joining `uplift_model.bronze.uplift_train`, `uplift_model.bronze.clients`, `uplift_model.silver.purchases_features`, and `uplift_model.silver.product_features` on `client_id`:

* **Experiment Columns (3):** `client_id`, `treatment_flg`, `target`
* **Demographics & Loyalty Dates (4):** `age`, `gender`, plus parsed `first_issue_date` and `first_redeem_date` timestamps (`to_timestamp(..., 'yyyy-MM-dd HH:mm:ss')`)
* **Purchase History & Tenure (23):** All 22 purchase features from `silver.purchases_features` plus `customer_tenure_days` (`DATEDIFF(DAY, first_transaction_datetime, last_transaction_datetime)`)
* **Product Affinity (5):** All 5 product features from `silver.product_features`

---

## Execution & Lineage Summary (`retailhero-bronze-gold-job`)

* **Compute:** Databricks Serverless Starter Warehouse (Performance Optimization enabled)
* **Total Job Duration:** `1m 7s` (`bronze-silver`: `55s` ➔ `silver-gold`: `11s`)
* **Lineage:** `6` upstream table references ➔ `3` downstream tables
* **Query Metrics:** `3` SQL queries executed | `230,374,335` rows read | `1,000,363` rows written

---

## Execution Order

1. Ensure the raw Delta tables (`purchases`, `products`, `clients`, `uplift_train`) exist in `uplift_model.bronze` and that the `uplift_model.silver` and `uplift_model.gold` schemas have been created.
2. Run **`bronze-silver-retailhero.sql`** to materialize `silver.purchases_features` and `silver.product_features`.
3. Run **`silver-gold-retailhero.sql`** to materialize `gold.model_features`.
