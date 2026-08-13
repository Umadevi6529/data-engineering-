# Phase 4 Quiz: Data Warehousing & Dimensional Modeling 🧠

Test your knowledge on Kimball dimensional modeling, Star Schema design, Surrogate Keys, and Slowly Changing Dimensions (SCD Types 1, 2, and 3).

---

## 📝 Part A: Conceptual Questions

**Q1.** What is the difference between a **Natural Key** and a **Surrogate Key**? Why MUST a Data Warehouse use Surrogate Keys for SCD Type 2 dimensions?

<details>
<summary>Answer</summary>

- **Natural Key (Business Key)**: The primary identifier assigned by the source operational system (e.g. `customer_id = 'CUST_1001'`).
- **Surrogate Key**: An artificial auto-incrementing integer created by the Data Warehouse (e.g. `customer_sk = 45012`).

**Why DWs MUST use Surrogate Keys for SCD Type 2**:
In SCD Type 2, when a customer updates their address or status, a **new row** is inserted into the dimension table to store the new historical version. 
Since both rows belong to the same customer, they share the **same Natural Key** (`CUST_1001`). Therefore, the Natural Key can no longer serve as a unique primary key! 
Surrogate Keys (`customer_sk = 1` for old address, `customer_sk = 2` for new address) allow each historical snapshot to have a unique primary key for fact table joins.
</details>

---

**Q2.** Compare **Star Schema** vs. **Snowflake Schema**. Why is Star Schema preferred in modern cloud data warehouses like Snowflake, Amazon Redshift, and Google BigQuery?

<details>
<summary>Answer</summary>

- **Star Schema**: A center Fact table surrounded by flat, de-normalized Dimension tables (1 join level).
- **Snowflake Schema**: Dimension tables are normalized into sub-dimension tables (e.g., `Dim_Product` -> `Dim_SubCategory` -> `Dim_Category`).

**Why Star Schema is Preferred**:
Modern cloud data warehouses use **Columnar Storage Engines** that excel at scanning de-normalized data. Star Schemas minimize multi-table `JOIN` operations, allowing query engines to execute analytical aggregations significantly faster and with simpler SQL syntax.
</details>

---

**Q3.** Explain the 4 steps of **Kimball's Dimensional Design Process**.

<details>
<summary>Answer</summary>

1. **Select the Business Process**: Identify the operational process to model (e.g., Sales Orders, Retail Store Purchases).
2. **Declare the Grain**: Define exactly what one row in the fact table represents (e.g., *"One row per line-item on a customer receipt"*).
3. **Identify the Dimensions**: Determine the attributes describing the context (*Who, What, Where, When, Why, How*).
4. **Identify the Facts**: Identify the numeric, aggregatable measures resulting from the event (`quantity`, `gross_revenue`, `discount`).
</details>

---

**Q4.** Differentiate between **SCD Type 1**, **SCD Type 2**, and **SCD Type 3**.

<details>
<summary>Answer</summary>

- **SCD Type 1 (Overwrite)**: Overwrites the old value with the new value. Historical state is lost. (Used for fixing typos).
- **SCD Type 2 (Add New Row)**: Keeps full history by inserting a new row with a new Surrogate Key, setting `effective_date`, `end_date`, and `is_current` flags. (Used for critical historical reporting like location or tier changes).
- **SCD Type 3 (Add New Column)**: Adds a new column (e.g. `previous_region`) to the existing row to track previous vs. current values. (Used when only the immediate prior state is needed).
</details>

---

## 💻 Part B: SQL Query Challenges

**Scenario:**
You have a Star Schema Data Warehouse with `fact_sales` and `dim_customers_scd2`.

**C1.** Write a SQL query to find total net revenue generated in 2024 grouped by the customer's **region AT THE TIME the sale took place** (Point-in-Time Historical Reporting).

<details>
<summary>Answer</summary>

```sql
SELECT
    c.region,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.net_revenue)         AS historical_net_revenue
FROM fact_sales f
JOIN dim_customers_scd2 c ON f.customer_sk = c.customer_sk
JOIN dim_date d          ON f.date_key = d.date_key
WHERE d.year = 2024
GROUP BY c.region
ORDER BY historical_net_revenue DESC;
```
Notice: By joining `f.customer_sk = c.customer_sk`, each fact row automatically joins to the exact historical row matching the customer's region when the purchase occurred!
</details>

---

**C2.** Write a SQL query to find total revenue grouped by the customer's **CURRENT region today**, regardless of where they lived when they made the purchase (Current State Reporting).

<details>
<summary>Answer</summary>

```sql
SELECT
    curr_c.region              AS current_region,
    COUNT(DISTINCT f.order_id) AS total_orders,
    SUM(f.net_revenue)         AS net_revenue
FROM fact_sales f
JOIN dim_customers_scd2 hist_c ON f.customer_sk = hist_c.customer_sk
-- Join again to get the CURRENT active record using the Natural Key:
JOIN dim_customers_scd2 curr_c ON hist_c.customer_id = curr_c.customer_id AND curr_c.is_current = TRUE
JOIN dim_date d               ON f.date_key = d.date_key
WHERE d.year = 2024
GROUP BY curr_c.region
ORDER BY net_revenue DESC;
```
</details>

---

## 🏋️ Part C: Hands-On Tasks

Run the Phase 4 project in Python:

```bash
cd phase-04-data-warehousing/projects/star_schema_dw
python main.py
```

Observe the execution output:
1. What was the `customer_sk` assigned to Priya Sharma (`CUST_001`) during her initial insert in Jan 2024 vs. her post-update insert in June 2024?
2. Which region was credited with her Jan 2024 order of ₹70,900?
3. Which region was credited with her July 2024 order of ₹13,500?

Commit your answers and code to your GitHub repository!
