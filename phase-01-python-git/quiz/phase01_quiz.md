# Phase 1 Quiz: Python + Git 🧠

Test yourself on these. Try to answer BEFORE looking at the answers.

---

## 📝 Conceptual Questions

**Q1.** What is a virtual environment and why do you need one?

<details>
<summary>Answer</summary>

A virtual environment is an isolated Python installation for one project.
It ensures that project A's `pandas==1.5` doesn't conflict with project B's `pandas==2.0`.
In a DE team, every project has its own `venv` with a locked `requirements.txt`.

```bash
python -m venv venv
venv\Scripts\activate     # Windows
pip install -r requirements.txt
```
</details>

---

**Q2.** What is the difference between `git merge` and `git rebase`?

<details>
<summary>Answer</summary>

- `git merge`: Creates a new "merge commit" that combines two branches.
  History is preserved exactly as-is. Safer for shared branches.
- `git rebase`: Re-applies your commits on top of another branch.
  History is rewritten to be linear. Cleaner, but never do it on public branches.

Use merge for main ← feature. Use rebase for local cleanup before a PR.
</details>

---

**Q3.** What does `if __name__ == "__main__":` do and why do we use it?

<details>
<summary>Answer</summary>

When Python runs a file directly, `__name__` is set to `"__main__"`.
When a file is imported by another module, `__name__` is the file's name.

This pattern prevents your `main()` function from running during imports.
Critical for: testing (you can import without side effects), Airflow DAGs
(which import your Python files), and PySpark jobs.
</details>

---

**Q4.** What's the difference between a Python `list` and a `generator`? Which is better for reading a 10GB CSV?

<details>
<summary>Answer</summary>

- **List**: Loads all data into memory at once. Reading a 10GB file = 10GB of RAM used.
- **Generator**: Yields one item at a time using `yield`. Only holds ONE row in memory.

For a 10GB CSV → use a generator (or pandas chunking, or Spark in Phase 6).

```python
# List (BAD for large files)
def read_all(file):
    return [line for line in file]  # Loads everything!

# Generator (GOOD)
def read_lazy(file):
    for line in file:
        yield line  # One line at a time
```
</details>

---

**Q5.** Where should you store database passwords and API keys in a Python project?

<details>
<summary>Answer</summary>

NEVER in the code or in a committed file.

Use:
1. **Environment variables**: `os.environ.get("DB_PASSWORD")`
2. **A `.env` file** (added to `.gitignore`) with `python-dotenv`
3. **AWS Secrets Manager** or **HashiCorp Vault** in production
4. **Airflow Variables/Connections** when using Airflow

```python
import os
from dotenv import load_dotenv

load_dotenv()  # Loads .env file
password = os.environ.get("DB_PASSWORD")
```
</details>

---

## 💻 Coding Challenges

**C1.** Write a Python decorator called `retry` that retries a function up to 3 times if it raises an exception.

<details>
<summary>Answer</summary>

```python
import time
from functools import wraps

def retry(max_attempts=3, delay=1):
    def decorator(func):
        @wraps(func)
        def wrapper(*args, **kwargs):
            for attempt in range(1, max_attempts + 1):
                try:
                    return func(*args, **kwargs)
                except Exception as e:
                    if attempt == max_attempts:
                        raise
                    print(f"Attempt {attempt} failed: {e}. Retrying in {delay}s...")
                    time.sleep(delay)
        return wrapper
    return decorator

@retry(max_attempts=3, delay=2)
def call_flaky_api():
    raise ConnectionError("API down!")
```

WHY THIS MATTERS IN DE: Network calls, API requests, and DB writes can fail
transiently. Retry decorators are used in Airflow tasks, API connectors,
and Kafka producers.
</details>

---

**C2.** Given a list of dicts, write a function that returns rows where a specific column is null.

<details>
<summary>Answer</summary>

```python
def get_null_rows(rows: list[dict], column: str) -> list[dict]:
    null_markers = {"", "null", "none", "na", "n/a", None}
    return [
        row for row in rows
        if str(row.get(column, "")).strip().lower() in null_markers
    ]

# Usage
data = [
    {"id": "1", "name": "Alice"},
    {"id": "2", "name": ""},
    {"id": "3", "name": None},
]
print(get_null_rows(data, "name"))
# → [{"id": "2", "name": ""}, {"id": "3", "name": None}]
```
</details>

---

**C3.** What's wrong with this code? Fix it.

```python
def load_data(filename):
    f = open(filename, 'r')
    data = f.readlines()
    return data

def process():
    try:
        rows = load_data("data.csv")
    except:
        pass  # silently ignore errors
```

<details>
<summary>Answer</summary>

Two bugs:
1. `f = open(...)` without `with` — if an exception occurs, the file never closes.
   Fix: use `with open(...) as f:`
2. `except: pass` — silently swallows ALL exceptions, including keyboard interrupts.
   Fix: always log the error and re-raise, or handle specific exceptions.

```python
import logging

def load_data(filename):
    with open(filename, "r") as f:  # ✅ auto-closes
        return f.readlines()

def process():
    try:
        rows = load_data("data.csv")
    except FileNotFoundError as e:   # ✅ specific exception
        logging.error(f"File not found: {e}")
        raise  # ✅ don't swallow — let the caller handle it
```
</details>

---

## 🏋️ Hands-On Challenge

Run the CSV processor with the sample data and answer:

```bash
python main.py \
  --file sample_data/sales.csv \
  --schema quantity:int,price:float \
  --required-cols customer_id,order_date \
  --numeric-cols price,quantity \
  --export output/clean_sales.csv
```

1. How many duplicate rows were found?
2. Which rows were flagged as null violations?
3. Was there a statistical outlier in the `price` column? What was the value?
4. How many rows made it to the output?

Write your answers in a comment and commit them to GitHub!
