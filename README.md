# 🚀 Data Engineering Journey — My Learning Portfolio

[![Python](https://img.shields.io/badge/Python-3.11+-blue?logo=python)](https://python.org)
[![SQL](https://img.shields.io/badge/SQL-PostgreSQL-336791?logo=postgresql)](https://postgresql.org)
[![Git](https://img.shields.io/badge/Git-Version%20Control-orange?logo=git)](https://git-scm.com)
[![Status](https://img.shields.io/badge/Status-Active%20Learning-green)](.)

> A structured, phase-by-phase journey through Data Engineering. Each phase = a real project.
> Built from scratch. Committed with discipline. Understood deeply.

---

## 🗺️ The DE Data Flow

```
External Sources (APIs / DBs / Files / Streams)
        │
        ▼
   ┌──────────┐    ┌──────────┐    ┌──────────────┐
   │  EXTRACT │───▶│TRANSFORM │───▶│    LOAD      │
   │  (Python)│    │ (Pandas/ │    │(Warehouse/   │
   │          │    │  Spark)  │    │ Data Lake)   │
   └──────────┘    └──────────┘    └──────────────┘
        │                                 │
        ▼                                 ▼
   Kafka (stream)               Redshift / BigQuery
        │                                 │
        ▼                                 ▼
   Airflow (schedule)           dbt (transform/test)
                                          │
                                          ▼
                                    Dashboard (BI)
```

---

## 📚 Phases

| # | Phase | Status | Key Skill |
|---|-------|--------|-----------|
| 1 | [Python + Git Foundation](./phase-01-python-git/) | ✅ In Progress | Python, Git, CLI |
| 2 | [SQL Deep Dive](./phase-02-sql/) | 🔜 Next | PostgreSQL, Analytics |
| 3 | [Databases](./phase-03-databases/) | ⏳ Planned | RDBMS, NoSQL |
| 4 | [Data Warehousing](./phase-04-data-warehousing/) | ⏳ Planned | Star Schema, SCD |
| 5 | [ETL Pipelines](./phase-05-etl-pipelines/) | ⏳ Planned | Pandas, dbt |
| 6 | [Big Data / Spark](./phase-06-spark/) | ⏳ Planned | PySpark |
| 7 | [File Formats](./phase-07-file-formats/) | ⏳ Planned | Parquet, Avro |
| 8 | [Cloud Platform](./phase-08-cloud/) | ⏳ Planned | AWS S3, Glue, Redshift |
| 9 | [Orchestration](./phase-09-orchestration/) | ⏳ Planned | Apache Airflow |
| 10 | [Data Quality](./phase-10-data-quality/) | ⏳ Planned | Great Expectations |
| 11 | [Kafka Streaming](./phase-11-kafka-streaming/) | ⏳ Planned | Kafka, Real-time |
| 12 | [Capstone Project](./phase-12-capstone/) | ⏳ Planned | Everything combined |

---

## 🛠️ Tech Stack (will grow each phase)

- **Languages**: Python, SQL
- **Databases**: PostgreSQL, MongoDB
- **Big Data**: Apache Spark (PySpark)
- **ETL**: Pandas, dbt, Apache Airflow
- **Streaming**: Apache Kafka
- **Cloud**: AWS (S3, Glue, Redshift, Lambda)
- **File Formats**: CSV, JSON, Parquet, Avro
- **Version Control**: Git + GitHub

---

## 📖 How to Navigate This Repo

Each phase folder contains:
- `README.md` — Detailed explanation of concepts + how things connect
- `projects/` — Working code (runnable!)
- `notes/` — Concept notes and mental models
- `quiz/` — Self-test questions + answers

---

*Learning in public. Building in phases. Understanding deeply.*
