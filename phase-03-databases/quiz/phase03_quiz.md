# Phase 3 Quiz: Databases & NoSQL Systems 🧠

Test your knowledge on database architectures, CAP Theorem, ACID vs BASE, NoSQL modeling, and caching.

---

## 📝 Part A: Conceptual Questions

**Q1.** Explain the CAP Theorem. If a network partition occurs in a cloud environment, why can't a distributed database guarantee both 100% Consistency and 100% Availability?

<details>
<summary>Answer</summary>

The CAP Theorem states that a distributed system can guarantee at most 2 out of 3 properties: **Consistency (C)**, **Availability (A)**, and **Partition Tolerance (P)**.

In cloud environments, network partitions ($P$) — such as dropped packets or network latency spikes — are inevitable. When a partition occurs between Node A and Node B:
- If Node A receives a write update, it cannot instantly replicate it to Node B due to the network split.
- If a client reads from Node B:
  - To maintain **Consistency (C)**, Node B must reject the read or wait, sacrificing **Availability (A)** (CP System).
  - To maintain **Availability (A)**, Node B returns its current (stale) data, sacrificing **Consistency (C)** (AP System).

Hence, during network partitions, systems MUST choose between Consistency (CP) or Availability (AP).
</details>

---

**Q2.** Compare **B-Tree** vs. **LSM-Tree** storage engines. Which engine is better suited for high-throughput write-heavy log ingestion (e.g., Kafka / Clickstream), and why?

<details>
<summary>Answer</summary>

- **B-Trees** (used in PostgreSQL, MySQL) perform **in-place updates** on fixed-size disk pages. They excel at fast random reads and point queries, but random writes cause disk page fragmentation and overhead.
- **LSM-Trees** (Log-Structured Merge-Trees, used in Cassandra, RocksDB) perform **append-only writes**. Writes are immediately stored in an in-memory `MemTable` and flushed to disk as immutable `SSTables`. Background threads merge/compact these tables later.

**Winner for Write-Heavy Ingestion: LSM-Trees.**
Because LSM-Trees convert random writes into sequential append-only writes, they provide significantly higher write throughput without random disk seeks.
</details>

---

**Q3.** Describe the **Cache-Aside (Lazy Loading)** caching pattern. What happens on a Cache Miss?

<details>
<summary>Answer</summary>

In the **Cache-Aside** pattern:
1. The application checks the cache (e.g., Redis) first for a given key.
2. **On Cache Hit**: The cached value is immediately returned to the caller (high speed, low latency).
3. **On Cache Miss**:
   - The application queries the primary database / backend system.
   - The application writes the fetched data into the cache (with a Time-To-Live expiration).
   - The application returns the data to the caller.

**Advantage**: The cache only holds data that is actively requested, and if the cache goes down, requests fall back safely to the primary database.
</details>

---

**Q4.** What is the difference between **Schema-on-Write** and **Schema-on-Read**?

<details>
<summary>Answer</summary>

- **Schema-on-Write (RDBMS / Warehouses)**: The schema structure (table columns, types, constraints) must be defined BEFORE any data is written. Incoming rows are strictly validated upon insertion. If a column is missing or types mismatch, insertion fails.
- **Schema-on-Read (NoSQL / Data Lakes)**: Data is ingested in raw form (e.g., arbitrary JSON, CSV, Parquet) without strict up-front validation. The schema is applied dynamically when the data is parsed or queried.

**DE Impact**: Schema-on-Read provides immense flexibility for rapidly evolving raw event payloads, while Schema-on-Write guarantees strict data quality for analytics and reporting.
</details>

---

## 💻 Part B: System Architecture Scenarios

**Scenario 1:**
You are designing a high-traffic e-commerce platform that expects 100,000 requests per minute during Black Friday. The platform needs:
1. Transactional checkout processing where user balances can NEVER be wrong.
2. A real-time product recommendations catalog with flexible specs per item.
3. User session authentication token validation with sub-millisecond latency.

Which database technology (RDBMS, Document NoSQL, Key-Value) would you select for each component?

<details>
<summary>Answer</summary>

1. **Checkout Processing**: **RDBMS (PostgreSQL / MySQL)**. Requires ACID compliance to ensure financial transactions and inventory counts never suffer from race conditions or partial writes.
2. **Product Catalog**: **Document NoSQL (MongoDB / DynamoDB)**. Different products (laptops vs t-shirts vs books) have wildly different attributes; JSON documents allow flexible attributes without adding hundreds of NULL columns.
3. **Session Tokens**: **Key-Value Cache (Redis)**. In-memory speed provides sub-millisecond validation for incoming user tokens without overwhelming the primary transactional database.
</details>

---

## 🏋️ Part C: Hands-On Challenge

Run the Phase 3 project in Python:

```bash
cd phase-03-databases/projects/multi_db_pipeline
python main.py
```

Observe the output and answer:
1. What was the **hit rate** of the Redis-style Cache Engine during the user profile lookups?
2. How many parent rows (`stg_events`) and child rows (`stg_event_items`) were extracted by the `RelationalExporter`?
3. Which user tier generated the highest revenue in the MongoDB-style aggregation pipeline result?

Commit your observations and code to GitHub!
