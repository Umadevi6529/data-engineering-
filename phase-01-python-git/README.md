# Phase 1: Python + Git Foundation 🐍

## 🎯 Goal
Build the programming and version-control foundation that every Data Engineering task runs on.

---

## 🧠 Why Does This Phase Matter?

Think of building a data pipeline like building a factory:
- **Python** is your assembly line — it automates repetitive work (reading files, calling APIs, transforming data)
- **Git** is your blueprint archive — it tracks every change, lets you collaborate, and lets you roll back mistakes
- **Virtual environments** are your clean rooms — isolate dependencies per project so nothing breaks

In DE, you'll write Python for:
- ETL scripts (Extract → Transform → Load)
- Apache Airflow DAGs (pipeline schedulers)
- PySpark jobs (big data processing)
- Data quality checks
- API data ingestion

---

## 📚 Concepts Covered

### 1. Virtual Environments
```bash
python -m venv venv          # Create isolated env
source venv/bin/activate     # Activate (Linux/Mac)
venv\Scripts\activate        # Activate (Windows)
pip install pandas           # Install ONLY in this env
pip freeze > requirements.txt  # Lock dependencies
```

**Why?** Project A needs `pandas==1.5`, Project B needs `pandas==2.0`. Without venv, they'd conflict. With venv, each has its own world.

### 2. Git Workflow
```bash
git init                     # Start tracking a folder
git add .                    # Stage changes
git commit -m "feat: add CSV parser"  # Save snapshot
git branch feature/sql-parser         # Create feature branch
git checkout feature/sql-parser       # Switch to branch
git merge feature/sql-parser          # Merge back to main
git push origin main                  # Push to GitHub
```

**The DE Git Workflow:**
1. `main` branch = stable, production-ready code
2. Feature branches = where you develop
3. Pull Requests = code review before merging
4. Tags = mark release points (v1.0, v2.0)

### 3. Python Core Patterns for DE

#### File I/O
```python
# Reading files (the DE bread and butter)
with open("data.csv", "r") as f:
    lines = f.readlines()

# Why 'with'? It auto-closes the file even if an error occurs
```

#### Error Handling
```python
try:
    data = load_csv("file.csv")
except FileNotFoundError as e:
    logger.error(f"File not found: {e}")
    raise  # Don't silently swallow errors in pipelines!
finally:
    cleanup()  # Always runs — great for closing DB connections
```

#### Decorators (used everywhere in Airflow/dbt)
```python
def timer(func):
    def wrapper(*args, **kwargs):
        start = time.time()
        result = func(*args, **kwargs)
        print(f"{func.__name__} took {time.time()-start:.2f}s")
        return result
    return wrapper

@timer
def load_million_rows():
    pass  # This automatically gets timed
```

---

## 🛠️ Project: CSV Data Processor CLI

**What it does:**
1. Reads any CSV file from command line
2. Detects and cleans dirty data (nulls, wrong types, duplicates)
3. Computes statistics (mean, median, std dev, outliers)
4. Generates a text report
5. Optionally exports cleaned data

**How it connects to DE:**
> This is literally a mini ETL pipeline:
> - **Extract**: Read the CSV
> - **Transform**: Clean + compute stats
> - **Load**: Write report/output

---

## 🧪 Quiz (Test Yourself After Completing This Phase)

**Answer these without looking:**
1. What is the difference between `git merge` and `git rebase`?
2. Why should you never store passwords in a Python file? Where should they go?
3. What does `*args` and `**kwargs` do?
4. Explain the difference between a list and a generator in Python. Which is better for processing a 10GB CSV file?
5. What is `requirements.txt` and why does it matter in a DE team?
6. Write a Python function that reads a CSV and returns rows where a column value is NULL.
7. What is the `__name__ == "__main__"` pattern used for?

---

## 📁 Structure
```
phase-01-python-git/
├── README.md           ← This file
├── notes/
│   ├── python_core.md  ← Key Python patterns for DE
│   └── git_workflow.md ← Git commands + branching strategy
└── projects/
    └── csv_processor/
        ├── README.md
        ├── requirements.txt
        ├── main.py         ← Entry point
        ├── processor.py    ← Core logic
        ├── validator.py    ← Data validation
        ├── reporter.py     ← Report generation
        └── sample_data/
            └── sales.csv   ← Test dataset
```
