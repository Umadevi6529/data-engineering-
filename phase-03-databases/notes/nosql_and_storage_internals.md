# Deep Dive: NoSQL Patterns & Caching Architectures 📑

## 1. MongoDB & Document Store Query Patterns

Document databases store data in flexible, semi-structured documents (usually BSON/JSON).

### Document Modeling: Embedding vs. Referencing

- **Embedding (Denormalization)**: Store nested data inside a single document.
  - **Pros**: Fast reads in a single query; atomic updates per document.
  - **Cons**: Document size limit (e.g., MongoDB 16MB limit); potential data duplication.
  - *Example*: Storing order line items inside the Order document.
```json
{
  "_id": "ORD_1001",
  "customer_id": "CUST_501",
  "items": [
    { "product_id": "PROD_A", "qty": 2, "price": 49.99 },
    { "product_id": "PROD_B", "qty": 1, "price": 19.99 }
  ]
}
```

- **Referencing (Normalization)**: Store references (`ObjectIDs` or Foreign Keys) to other documents.
  - **Pros**: Avoids data duplication; scales beyond 16MB document limit.
  - **Cons**: Requires `$lookup` (JOIN operations in MongoDB) which are slower.

---

### MongoDB Aggregation Pipeline vs. SQL Equivalent

In MongoDB, analytical queries use an **Aggregation Pipeline** where documents pass through stages:

| Aggregation Stage | SQL Equivalent | Description |
| :--- | :--- | :--- |
| `$match` | `WHERE` / `HAVING` | Filters documents to pass only matching ones |
| `$group` | `GROUP BY` | Groups documents by a specified identifier |
| `$project` | `SELECT` | Reshapes each document (include/exclude fields, calculate fields) |
| `$sort` | `ORDER BY` | Sorts all input documents |
| `$limit` / `$skip` | `LIMIT` / `OFFSET` | Controls pagination |
| `$lookup` | `LEFT OUTER JOIN` | Performs equality join to another collection |
| `$unwind` | *Explode array rows* | Deconstructs an array field from the input documents to output a document for each element |

---

## 2. Redis & Key-Value Caching Strategies

Redis is an in-memory, key-value data store used as a database, cache, and message broker.

### Core Redis Data Types for DE Pipelines
1. **Strings**: Simple key-value text or binary data (TTL expiration supported).
2. **Hashes**: Field-value pairs representing object properties (`HSET user:100 name "Alice" age "30"`).
3. **Lists**: Ordered string lists (`LPUSH`, `RPOP`) - useful for message queues.
4. **Sets**: Unordered unique strings (`SADD active_users "user_1"`) - useful for deduplication.
5. **Sorted Sets (ZSet)**: Sets scored by floating-point values - useful for real-time leaderboards.
6. **Pub/Sub**: Event notification bus.

---

### Common Caching Patterns in Pipelines

```
Client / Pipeline ───▶ 1. Check Cache (Redis) ───[HIT]───▶ Return Data
      │                                                         ▲
   [MISS]                                                       │
      └──────────────▶ 2. Fetch from DB ────▶ 3. Populate Cache ┘
```

#### A. Cache-Aside (Lazy Loading)
- Application reads from Cache first.
- On **Cache Miss**, reads from primary Database, writes result to Cache, and returns to caller.
- **Pros**: Resilient to cache failures; cache only holds requested data.
- **Cons**: Initial read penalty on cache miss; data can become stale if updates bypass cache.

#### B. Write-Through
- Application writes to Cache, and Cache synchronously writes to DB before responding.
- **Pros**: Cache is never stale.
- **Cons**: Higher write latency.

#### C. Write-Behind (Write-Back)
- Application writes to Cache immediately. Asynchronously, a background job pushes batch writes to DB.
- **Pros**: Blazing fast write throughput for high-volume logs.
- **Cons**: Risk of data loss if Redis node crashes before async DB flush.

---

## 3. Data Engineering Ingestion Pipeline Pattern

In enterprise DE pipelines:
1. **Ingest**: Raw JSON payload from API/IoT/Mongo CDC -> Data Lake (S3/GCP Bucket as Raw Parquet/JSON).
2. **Speed Layer**: Redis caches frequent customer lookup keys for real-time APIs.
3. **Batch Layer**: Spark/Pandas extracts JSON from Data Lake, flattens schema, cleans types, and loads into Data Warehouse (Redshift/BigQuery/Postgres).
