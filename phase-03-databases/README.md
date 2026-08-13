# Phase 3: Databases & NoSQL Systems 🗄️

## 🎯 Goal
Understand database architecture deeply — RDBMS vs. NoSQL, CAP Theorem, ACID vs. BASE, B-Trees vs. LSM-Trees, and how to work with Document Stores (MongoDB) and Key-Value Caching (Redis) in data engineering pipelines.

---

## 🧠 Why Databases Matter in Data Engineering

Data Engineers don't just query databases; we **ingest from**, **sync between**, and **design storage layers** across multiple database types. 

In production, source systems are rarely purely SQL. You will encounter:
- **Transactional SQL (PostgreSQL/MySQL)**: Order management, financial ledgers, user accounts.
- **Document DBs (MongoDB/DynamoDB)**: Unstructured/Semi-structured JSON payloads, web clickstream, product catalogs.
- **Key-Value Stores (Redis)**: High-speed caching, user sessions, real-time rate limiting.
- **Columnar NoSQL (Cassandra/HBase)**: High-throughput write-heavy time-series and sensor logs.

---

## 🗂️ The Core Theoretical Foundations

```
                          ┌───────────────────────────┐
                          │   DATABASE ARCHITECTURES  │
                          └─────────────┬─────────────┘
                                        │
             ┌──────────────────────────┴──────────────────────────┐
             ▼                                                     ▼
     ┌──────────────┐                                      ┌──────────────┐
     │    RDBMS     │                                      │    NoSQL     │
     ├──────────────┤                                      ├──────────────┤
     │ PostgreSQL   │                                      │ MongoDB      │
     │ MySQL        │                                      │ Redis        │
     │ Oracle       │                                      │ Cassandra    │
     └──────┬───────┘                                      └──────┬───────┘
            │                                                     │
            ▼                                                     ▼
     • Schema-on-Write                                     • Schema-on-Read
     • ACID Compliant                                      • BASE Properties
     • B-Tree Indexing                                     • LSM-Tree / In-Memory
     • Vertical Scaling                                    • Horizontal Scaling
```

---

## 📊 1. RDBMS vs. NoSQL Matrix

| Feature | RDBMS (PostgreSQL, MySQL) | NoSQL (MongoDB, Redis, Cassandra) |
| :--- | :--- | :--- |
| **Data Structure** | Structured Tables (Rows & Columns) | Unstructured/Semi-structured (JSON, Key-Value, Columns) |
| **Schema** | **Schema-on-Write** (Strict predefined schema) | **Schema-on-Read** (Flexible, dynamic payloads) |
| **Scaling** | **Vertical** (Scale Up: bigger CPU/RAM) | **Horizontal** (Scale Out: sharding across cluster nodes) |
| **Transactions** | **ACID** (Strong Consistency) | **BASE** (Eventual Consistency) |
| **Primary Use Case** | Financials, OLTP Apps, Structured Relations | Real-time streams, IoT logs, Caching, Dynamic Catalogs |

---

## 🌐 2. The CAP Theorem & PACELC

The **CAP Theorem** states that in any distributed data store, you can only guarantee **2 out of 3** guarantees simultaneously under a network partition:

```
                  Consistency (C)
                     /       \
                    /         \
                   /   SYSTEM  \
                  /  CHOICES    \
                 /               \
Availability (A) ───────────────── Partition Tolerance (P)
```

1. **Consistency (C)**: Every read receives the most recent write or an error.
2. **Availability (A)**: Every non-failing node returns a non-error response (without guarantee that it contains the latest write).
3. **Partition Tolerance (P)**: The system continues to operate despite network message loss or node disconnection.

> **Crucial DE Insight**: Network partitions ($P$) are unavoidable in real distributed cloud networks. Therefore, distributed databases MUST choose between **CP** (Consistency & Partition Tolerance) or **AP** (Availability & Partition Tolerance).

- **CP Systems** (e.g., HBase, MongoDB primary node writes): Choose correctness over availability.
- **AP Systems** (e.g., Cassandra, CouchDB): Choose availability and responsiveness over immediate consistency (Eventual Consistency).

### PACELC Extension
> **If there is a Partition ($P$)**, how does the system trade off **Availability ($A$)** and **Consistency ($C$)**?
> **Else ($E$)**, when the system is running normally, how does it trade off **Latency ($L$)** and **Consistency ($C$)**?

---

## 🔒 3. ACID vs. BASE

### ACID (RDBMS Guarantee)
- **Atomicity**: All operations in a transaction succeed or all roll back (All or Nothing).
- **Consistency**: Data transitions from one valid state to another, enforcing constraints.
- **Isolation**: Concurrent transactions execute without interfering with each other.
- **Durability**: Committed data is stored permanently in non-volatile storage (Write-Ahead Log - WAL).

### BASE (NoSQL Guarantee)
- **Basically Available**: The system guarantees availability (responses may be stale).
- **Soft-state**: State of the system can change over time without user input due to eventual consistency updates.
- **Eventual Consistency**: Data will become consistent across all nodes given enough time without new updates.

---

## ⚙️ 4. Storage Engine Internals: B-Trees vs. LSM-Trees

How databases write data to disk determines their read/write performance profile:

### B-Tree Storage Engines (e.g., PostgreSQL, MySQL InnoDB)
- **Structure**: Balanced tree with fixed-size pages (typically 8KB or 16KB).
- **In-Place Updates**: Overwrites data directly on disk pages.
- **Best For**: **Read-heavy workloads** with fast point lookups and range scans.
- **Drawback**: Random disk write overhead due to page fragmentation.

### LSM-Tree (Log-Structured Merge-Tree) (e.g., Cassandra, RocksDB, Bigtable)
- **Structure**: Append-only log files. Writes go to an in-memory buffer (**MemTable**) and are flushed to immutable disk files (**SSTables**).
- **Append-Only**: Never updates existing files on disk; periodically performs background **compaction**.
- **Best For**: **Write-heavy workloads** (log ingestion, clickstreams, sensor data).
- **Drawback**: Read amplification (may need to check multiple SSTables + Bloom Filters).

---

## 🛠️ Project: Multi-Database Ingestion & Cache Engine

In `projects/multi_db_pipeline/`, we build a complete Python engine that demonstrates:
1. **Document Storage Engine**: Ingesting raw JSON clickstream/event payloads, indexing documents, and running MongoDB-style aggregation pipelines.
2. **Key-Value Cache Engine**: Implementing a Redis-style **Cache-Aside** strategy with TTL (Time-To-Live) and LRU eviction for fast session lookups.
3. **Relational Extractor**: Flattening nested NoSQL JSON documents into normalized SQL tables ready for Data Warehouse ingestion.

---

## 📁 File Structure

```
phase-03-databases/
├── README.md                              ← This overview
├── notes/
│   └── nosql_and_storage_internals.md    ← Deep dive into MongoDB & Redis patterns
├── projects/
│   └── multi_db_pipeline/
│       ├── document_store.py              ← MongoDB-style document engine & aggregations
│       ├── cache_engine.py                ← Redis-style Cache-Aside & TTL engine
│       ├── relational_exporter.py         ← Flattening NoSQL -> SQL DW format
│       └── main.py                        ← Full pipeline runner
└── quiz/
    └── phase03_quiz.md                    ← Test your understanding
```

---

## 🏃 Running the Project

```bash
cd phase-03-databases/projects/multi_db_pipeline
python main.py
```
