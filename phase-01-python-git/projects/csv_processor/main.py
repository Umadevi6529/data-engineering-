"""
main.py — Entry Point for the CSV Data Processor
=================================================
HOW IT WORKS:
- This is the "orchestrator" — it wires together all modules.
- Think of it like an Airflow DAG: it defines the sequence of tasks.
- The `if __name__ == "__main__":` guard means this only runs when you
  execute the file directly, not when it's imported by another module.

THE PIPELINE (mini ETL):
    main.py
      │
      ├── [EXTRACT]   → CSVReader reads the file
      │
      ├── [VALIDATE]  → DataValidator checks quality
      │
      ├── [TRANSFORM] → DataProcessor cleans + enriches
      │
      └── [LOAD]      → ReportGenerator writes output

COMMAND LINE INTERFACE:
- We use argparse to accept arguments from the terminal.
- This makes it reusable: just change the arguments, not the code.
- In production, these would be environment variables or Airflow DAG params.

HOW TO RUN:
    python main.py --file sample_data/sales.csv
    python main.py --file sample_data/sales.csv --export output/clean.csv
    python main.py --file sample_data/sales.csv --schema age:int,salary:float
    python main.py --help
"""

import argparse
import csv
import logging
import os
import sys

# ── Force UTF-8 output on Windows (fixes emoji/unicode in console) ───────────
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

from processor import DataProcessor
from reporter import ReportGenerator
from validator import DataValidator



# ─────────────────────────────────────────────────────────────
# LOGGING SETUP
# ─────────────────────────────────────────────────────────────
# WHY LOGGING INSTEAD OF PRINT?
# - In production, logs go to CloudWatch, Datadog, or Splunk.
# - You can set log levels: DEBUG < INFO < WARNING < ERROR < CRITICAL.
# - You can filter without changing code: set level=WARNING to silence DEBUG.
# - Airflow, Spark, and dbt all use structured logging.
# ─────────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger(__name__)


def parse_schema(schema_str: str) -> dict[str, str]:
    """
    Parse a schema string like "age:int,salary:float,name:str"
    into a dict: {"age": "int", "salary": "float", "name": "str"}

    This is a command-line-friendly way to define a schema.
    In production, schemas come from:
    - A JSON config file
    - A database schema registry (like Apache Avro Schema Registry)
    - An AWS Glue Data Catalog
    - A dbt YAML schema file
    """
    if not schema_str:
        return {}
    schema = {}
    for pair in schema_str.split(","):
        pair = pair.strip()
        if ":" in pair:
            col, dtype = pair.split(":", 1)
            schema[col.strip()] = dtype.strip()
    return schema


def read_csv(filepath: str) -> list[dict]:
    """
    Read a CSV file into a list of dictionaries.

    WHY LIST OF DICTS?
    - Each dict = one row, with column names as keys.
    - This is the same structure as pandas DataFrame rows.
    - Easy to pass between functions without worrying about column positions.

    EXAMPLE:
    CSV:  name, age, salary
          Alice, 30, 50000

    Result: [{"name": "Alice", "age": "30", "salary": "50000"}]

    NOTE: Everything is a string at this point — that's what CSV gives us.
    Type casting happens in the processor.
    """
    if not os.path.exists(filepath):
        logger.error(f"File not found: {filepath}")
        sys.exit(1)

    rows = []
    try:
        with open(filepath, "r", newline="", encoding="utf-8-sig") as f:
            # DictReader auto-maps header row to dict keys
            reader = csv.DictReader(f)
            for row in reader:
                # Strip whitespace from all values
                rows.append({k: v.strip() for k, v in row.items()})
    except PermissionError:
        logger.error(f"Permission denied reading: {filepath}")
        sys.exit(1)
    except csv.Error as e:
        logger.error(f"CSV parse error: {e}")
        sys.exit(1)

    return rows


def main():
    """
    Main entry point — the pipeline orchestrator.

    FLOW:
    1. Parse CLI arguments
    2. Read CSV file
    3. Validate the raw data
    4. Process (clean + transform) the data
    5. Generate and print the report
    6. Optionally export clean CSV
    """

    # ── STEP 0: Parse Arguments ─────────────────────────────────────────────
    parser = argparse.ArgumentParser(
        description="📊 CSV Data Processor — A mini ETL pipeline",
        formatter_class=argparse.RawDescriptionHelpFormatter,
        epilog="""
Examples:
  python main.py --file sales.csv
  python main.py --file sales.csv --schema age:int,salary:float
  python main.py --file sales.csv --required-cols customer_id,order_date
  python main.py --file sales.csv --export output/clean_sales.csv
  python main.py --file sales.csv --numeric-cols salary,age
        """,
    )

    parser.add_argument(
        "--file", required=True, help="Path to the input CSV file"
    )
    parser.add_argument(
        "--schema",
        default="",
        help="Column type schema, e.g. 'age:int,salary:float,name:str'",
    )
    parser.add_argument(
        "--required-cols",
        default="",
        help="Comma-separated column names that must not be null",
    )
    parser.add_argument(
        "--numeric-cols",
        default="",
        help="Comma-separated numeric columns for statistics",
    )
    parser.add_argument(
        "--export",
        default="",
        help="Optional: path to export cleaned CSV (e.g. output/clean.csv)",
    )
    parser.add_argument(
        "--null-threshold",
        type=float,
        default=0.5,
        help="Warn if null fraction in a column exceeds this value (default: 0.5 = 50 percent)",
    )

    args = parser.parse_args()

    # ── STEP 1: Extract — Read CSV ──────────────────────────────────────────
    logger.info(f"Starting pipeline for: {args.file}")
    print(f"\n[EXTRACT] Reading file: {args.file}")
    rows = read_csv(args.file)
    print(f"   Loaded {len(rows)} rows, {len(rows[0]) if rows else 0} columns")

    if not rows:
        logger.error("No data to process. Exiting.")
        sys.exit(1)

    # ── Parse optional arguments ────────────────────────────────────────────
    schema = parse_schema(args.schema)
    required_cols = [c.strip() for c in args.required_cols.split(",") if c.strip()]
    numeric_cols  = [c.strip() for c in args.numeric_cols.split(",") if c.strip()]

    # ── STEP 2: Validate — Check data quality ───────────────────────────────
    print("\n[VALIDATE] Validating data...")
    validator = DataValidator()
    validation_result = validator.validate(
        rows=rows,
        schema=schema if schema else None,
        required_columns=required_cols if required_cols else None,
        null_threshold=args.null_threshold,
    )

    # Abort if validation hard-fails (e.g. required col has nulls)
    if not validation_result.is_valid:
        logger.error("Validation failed. Pipeline aborted.")
        print("\n[FAILED] PIPELINE ABORTED -- See errors above.")
        print(validation_result.summary())
        sys.exit(1)

    # ── STEP 3: Transform — Process data ────────────────────────────────────
    print("\n[TRANSFORM] Processing data...")
    processor = DataProcessor(schema=schema)
    processing_result = processor.process(
        rows=rows,
        drop_null_cols=required_cols if required_cols else None,
        numeric_cols=numeric_cols if numeric_cols else None,
    )

    # ── STEP 4: Load — Generate report ──────────────────────────────────────
    print("\n[REPORT] Generating report...")
    reporter = ReportGenerator()
    report = reporter.generate(
        filename=args.file,
        validation=validation_result,
        processing=processing_result,
    )
    print("\n" + report)

    # ── STEP 5: (Optional) Export cleaned data ───────────────────────────────
    if args.export:
        print(f"\n[EXPORT] Exporting cleaned data...")
        reporter.export_csv(processing_result.cleaned_rows, args.export)

    logger.info("Pipeline completed successfully.")
    print("\n[DONE] Pipeline finished.")


# ─────────────────────────────────────────────────────────────
# THE __name__ == "__main__" GUARD
# ─────────────────────────────────────────────────────────────
# WHY THIS PATTERN?
# When Python imports this file as a module (e.g. in tests),
# it does NOT run main(). Only when you run `python main.py`
# directly does __name__ equal "__main__".
#
# This is standard in ALL Python projects — Airflow DAGs,
# PySpark jobs, CLI tools. Always use this pattern.
# ─────────────────────────────────────────────────────────────
if __name__ == "__main__":
    main()
