# Deep Dive: Dimensional Modeling & SCD Architectures 📖

## 1. Kimball vs. Inmon Methodologies

In Data Warehousing history, two rival design philosophies emerged:

### Bill Inmon ("Top-Down" Enterprise Bus Architecture)
- **Concept**: Build an Enterprise-wide Data Warehouse in 3rd Normal Form (3NF) first, then build departmental Data Marts on top.
- **Pros**: Single source of truth; avoids data redundancy.
- **Cons**: High initial cost; slow time-to-market; extremely complex maintenance.

### Ralph Kimball ("Bottom-Up" Dimensional Architecture)
- **Concept**: Build Dimensional Data Marts directly for specific business processes using Star Schemas, linked together by **Conformed Dimensions**.
- **Pros**: Fast time-to-market; easy to query for business analysts; high performance.
- **Cons**: Requires strict discipline to enforce conformed dimensions across marts.

> **Modern DW Consensus**: The Kimball dimensional approach (Star Schema) combined with Cloud Data Warehouses (Snowflake, BigQuery, dbt) is the industry standard for 95% of Data Engineering teams today.

---

## 2. Surrogate Keys vs. Natural Keys

- **Natural / Business Key**: The primary key from the source operational system (e.g. `customer_id = 'CUST_101'`).
- **Surrogate Key**: An artificial integer primary key generated inside the Data Warehouse (e.g. `customer_sk = 5021`).

### Why DWs MUST Use Surrogate Keys:
1. **Handling SCD Type 2**: A single natural customer (`CUST_101`) will have **multiple rows** in a historical DW table when their address/tier changes over time. Each row needs a unique primary key -> `customer_sk`.
2. **System Independence**: Merging data from 2 source systems where both use overlapping natural keys (e.g. System A has `ID=1` and System B has `ID=1`).
3. **Performance**: Integer join keys (`INT` / `BIGINT`) are faster to index and join in databases than string keys (`VARCHAR`).

---

## 3. Classification of Dimensions & Facts

### Dimension Types
- **Conformed Dimension**: A shared dimension used across multiple fact tables (e.g., `Dim_Date` or `Dim_Customer` shared between Sales Fact and Returns Fact).
- **Junk Dimension**: A single dimension table combining low-cardinality flags/indicators (e.g., `is_gift_wrapped`, `payment_status`, `shipping_method`) to avoid bloating the fact table.
- **Degenerate Dimension**: A dimension attribute stored directly in the fact table without a separate dimension table (e.g., `invoice_number` or `order_id`).
- **Role-Playing Dimension**: A single dimension table joined multiple times under different aliases to a fact table (e.g., `Dim_Date` joined as `Order_Date`, `Ship_Date`, and `Delivery_Date`).

### Fact Table Types
1. **Transaction Fact Table**: One row per atomic transaction event (e.g. point-of-sale line item).
2. **Periodic Snapshot Fact Table**: Summarized snapshot at regular time intervals (e.g. monthly bank account balance, daily warehouse stock inventory).
3. **Accumulating Snapshot Fact Table**: One row for a workflow process with multiple milestone dates (e.g., Order Placed -> Order Shipped -> Order Delivered).

---

## 4. SCD Type 2 Implementation Algorithm

When loading data into an SCD Type 2 dimension table:

```
                  Incoming Record from Source (Natural Key = K)
                                      │
                         Is Natural Key K in Dim Table?
                                     / \
                                NO  /   \ YES
                                   /     \
                                  ▼       ▼
                       Insert New Row    Has any tracked attribute changed?
                       sk = AUTO          / \
                       is_current = TRUE NO/   \ YES
                       effective = NOW    /     \
                       end = 9999        ▼       ▼
                                     No Action  1. Update existing row:
                                                   is_current = FALSE
                                                   end_date = NOW()
                                                2. Insert new row:
                                                   sk = AUTO
                                                   is_current = TRUE
                                                   effective = NOW()
                                                   end_date = 9999
```

---

## 5. Point-in-Time Point Queries (SCD Type 2)

How do you query historical facts against an SCD Type 2 dimension?

```sql
-- Query: Show all sales made in March 2024 with the customer's state AT THE TIME of order:
SELECT
    f.order_id,
    c.customer_name,
    c.city            AS city_at_time_of_order,
    f.total_amount
FROM fact_sales f
JOIN dim_customers_scd2 c
  ON f.customer_id = c.customer_id
 AND f.order_date >= c.effective_date
 AND f.order_date <  c.end_date
WHERE f.order_date BETWEEN '2024-03-01' AND '2024-03-31';
```
Notice how joining using `effective_date` and `end_date` matches the exact historical state of the customer when the order took place!
