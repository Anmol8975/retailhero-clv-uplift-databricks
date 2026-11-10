# RetailHero CLV & Uplift Data Engineering Pipeline on Databricks

A **Medallion SQL data engineering pipeline** built on **Databricks Free Edition** using **Unity Catalog**, **Delta Lake**, **Serverless SQL**, and **Databricks Jobs**. This repository covers the end-to-end data ingestion, cleaning, and feature engineering workflow that transforms **45.78M+ raw retail transactions** into a model-ready Gold feature table (`uplift_model.gold.model_features`) for Customer Lifetime Value (CLV) and Uplift Modeling.

---

## Architecture Overview

```text
Local RetailHero CSVs (~4.36 GB purchases.csv)
   │  Converted locally to Parquet (purchases reduced to 546.03 MB)
   ▼
Unity Catalog Volume (/Volumes/uplift_model/default/retailhero_raw)
   │  Loaded into Delta tables via Serverless SQL read_files()
   ▼
[Bronze Layer]  uplift_model.bronze.*
   │  • purchases (45,786,568 rows)      • clients (400,162 rows)
   │  • products (43,038 rows)           • uplift_train (200,039 rows)
   │  • uplift_test (200,123 rows)
   │
   │  Databricks Job Task 1: bronze-silver (bronze-silver-retail-sql · 55s)
   ▼
[Silver Layer]  uplift_model.silver.*
   │  • purchases_features (22 client-level transaction & loyalty features)
   │  • product_features (5 client-level category & brand affinity features)
   │
   │  Databricks Job Task 2: silver-gold (silver-gold-retail-sql · 11s)
   ▼
[Gold Layer]    uplift_model.gold.model_features
      • 35 columns joining experiment labels, parsed demographics,
        customer tenure, purchase behavior, and product affinity
```

---

## Tech Stack

* **Platform & Governance:** Databricks Free Edition, Unity Catalog (`uplift_model` catalog across `bronze`, `silver`, and `gold` schemas), Delta Lake
* **Compute & Orchestration:** Databricks Serverless Starter Warehouse (`2XS`), Databricks Jobs & Pipelines
* **Language:** Databricks SQL (`read_files()`, timestamp parsing, aggregations, multi-table joins)

---

## 1. Ingestion & Storage Optimization

Browser uploads of the raw `4.36 GB` (`43,59,156 KB`) `purchases.csv` file stalled at `0%`. Converting the raw CSVs into compressed `.parquet` files locally reduced `purchases` by ~87% down to **546.03 MB**, enabling reliable staging inside a Unity Catalog Managed Volume (`/Volumes/uplift_model/default/retailhero_raw`) and fast Delta table creation using SQL `read_files()`.

| Table | Raw CSV Size | Staged Parquet Size | Bronze Row Count |
| :--- | :--- | :--- | :--- |
| `purchases` | ~4.36 GB (`43,59,156 KB`) | `546.03 MB` | `45,786,568` |
| `clients` | `20.73 MB` | `11.49 MB` | `400,162` |
| `products` | `3.71 MB` | `962.55 KB` | `43,038` |
| `uplift_train` | `2.86 MB` | `1.97 MB` | `200,039` |
| `uplift_test` | `2.10 MB` | `1.92 MB` | `200,123` |

---

## 2. Medallion Transformations (`SQL/`)

### Bronze Layer (`uplift_model.bronze`)
Exact 1:1 Delta tables ingested from the staged Parquet files in `/Volumes/uplift_model/default/retailhero_raw` (`clients`, `products`, `purchases`, `uplift_train`, `uplift_test`).

### Silver Layer (`uplift_model.silver`)
Implemented in **`bronze-silver-retail-sql`**, generating two client-level feature tables:

* **`uplift_model.silver.purchases_features`** *(from `bronze.purchases`, grouped by `client_id`)*
  * **Volume & Diversity:** `total_transactions` (`COUNT(DISTINCT transaction_id)`), `total_unique_stores`, `total_unique_products`, and `total_product_quantity`
  * **Spend & Loyalty Totals/Averages:** `SUM` and `AVG` across `purchase_sum`, `trn_sum_from_iss`, `trn_sum_from_red`, `regular_points_received`, `express_points_received`, `regular_points_spent`, `express_points_spent`, and `product_quantity`
  * **Temporal Behavior:** Parses string `transaction_datetime` via `to_timestamp(..., 'yyyy-MM-dd HH:mm:ss')` to compute `first_transaction_datetime`, `last_transaction_datetime`, and `pct_weekend_purchases`
* **`uplift_model.silver.product_features`** *(joins `bronze.purchases` and `bronze.products` on `product_id`, grouped by `client_id`)*
  * **Category & Brand Affinity:** `alcohol_spend` (`is_alcohol = 1`), `own_brand_spend` (`is_own_trademark = 1`), `unique_top_categories` (`level_1`), `unique_sub_categories` (`level_2`), and `unique_brands` (`brand_id`)

### Gold Layer (`uplift_model.gold`)
Implemented in **`silver-gold-retail-sql`**, creating **`uplift_model.gold.model_features`**:

* Joins `bronze.uplift_train`, `bronze.clients`, `silver.purchases_features`, and `silver.product_features` on `client_id`
* Includes experiment assignment and outcome (`treatment_flg`, `target`), client demographics (`age`, `gender`, parsed `first_issue_date` and `first_redeem_date`), all Silver purchase and product features, and derived `customer_tenure_days` (`DATEDIFF(DAY, first_transaction_datetime, last_transaction_datetime)`)

---

## 3. Automated Databricks Job (`retailhero-bronze-gold-job`)

Both transformation scripts are orchestrated sequentially as a Databricks Job running on the **Serverless Starter Warehouse** with performance optimization enabled:

* **DAG Flow:** `bronze-silver` (`55s`) ➔ `silver-gold` (`11s`)
* **Total Duration:** `1m 7s` (`Succeeded`)
* **Lineage:** `6` upstream tables ➔ `3` downstream tables
* **Execution Scale:** `230,374,335` rows read across `3` SQL queries ➔ `1,000,363` rows written

---

## Repository Structure

```text
retailhero-clv-uplift-databricks/
├── Raw_Data/    # Ingestion / raw setup SQL scripts
├── SQL/         # Bronze-to-Silver and Silver-to-Gold SQL transformation scripts
├── LICENSE      # MIT License
└── README.md
```
