"""
processor.py — Core Data Processing Engine
===========================================
HOW IT WORKS:
- This is the "Transform" step of our mini ETL pipeline.
- We take raw, dirty rows and produce clean, enriched data.
- We also compute statistics that describe the dataset.

IN DATA ENGINEERING:
- In production, this might be done with Pandas (Phase 5) or PySpark (Phase 6).
- Here, we build it manually to understand WHAT those tools are doing under the hood.
- Mental model: pandas.read_csv() + pandas.describe() + pandas.dropna()
  → that's exactly what this module replicates.
"""

import statistics
import time
from dataclasses import dataclass, field
from functools import wraps
from typing import Any, Callable


# ─────────────────────────────────────────────────────────────
# DECORATOR: timer — measures how long a function takes
# ─────────────────────────────────────────────────────────────
# WHY DECORATORS?
# Airflow tasks, dbt macros, and Spark transformations all use decorators.
# They let you add cross-cutting behavior (timing, logging, retrying)
# without changing the function itself. This is the "AOP" pattern.
# ─────────────────────────────────────────────────────────────
def timer(func: Callable) -> Callable:
    """Decorator that logs execution time of any function."""
    @wraps(func)  # Preserves the original function's name and docstring
    def wrapper(*args, **kwargs):
        start = time.perf_counter()
        result = func(*args, **kwargs)
        elapsed = time.perf_counter() - start
        print(f"  ⏱  {func.__name__}() completed in {elapsed:.4f}s")
        return result
    return wrapper


@dataclass
class ColumnStats:
    """
    Statistics for a single numeric column.

    STATISTICS THAT MATTER IN DE:
    - mean/median: Are values reasonable? A salary mean of $10M means something is wrong.
    - std_dev: How spread out is the data? High std = outliers likely.
    - min/max: Range validation (e.g., age can't be -5 or 999).
    - outlier_count: Rows that deviate >3 standard deviations (the "3-sigma rule").
    """
    column_name: str
    count: int = 0           # Total non-null values
    mean: float = 0.0
    median: float = 0.0
    std_dev: float = 0.0
    min_val: float = 0.0
    max_val: float = 0.0
    outlier_count: int = 0
    outlier_rows: list = field(default_factory=list)


@dataclass
class ProcessingResult:
    """Result of the full processing pipeline."""
    original_row_count: int
    cleaned_row_count: int
    removed_duplicates: int
    removed_nulls: int
    column_stats: dict[str, ColumnStats] = field(default_factory=dict)
    cleaned_rows: list[dict] = field(default_factory=list)
    processing_time_seconds: float = 0.0


class DataProcessor:
    """
    Core processing engine — the 'Transform' in ETL.

    PIPELINE FLOW:
    raw_rows
        │
        ▼
    deduplicate()      ← Remove exact copies
        │
        ▼
    drop_nulls()       ← Remove rows where required cols are null
        │
        ▼
    cast_types()       ← Convert strings to int/float
        │
        ▼
    compute_stats()    ← Calculate mean, median, outliers
        │
        ▼
    cleaned_rows + stats

    This is EXACTLY what Pandas does with:
        df.drop_duplicates()
        df.dropna()
        df.astype()
        df.describe()
    """

    def __init__(self, schema: dict[str, str] | None = None):
        """
        Args:
            schema: Column type mappings e.g. {"age": "int", "salary": "float"}
        """
        self.schema = schema or {}

    @timer
    def process(
        self,
        rows: list[dict],
        drop_null_cols: list[str] | None = None,
        numeric_cols: list[str] | None = None,
    ) -> ProcessingResult:
        """
        Full processing pipeline.

        Args:
            rows: Raw list of dicts from CSV
            drop_null_cols: Drop rows where these columns are null
            numeric_cols: Columns to run statistics on

        Returns:
            ProcessingResult with cleaned data and statistics
        """
        start_time = time.perf_counter()
        original_count = len(rows)

        # Step 1: Deduplicate
        deduped, removed_dupes = self._deduplicate(rows)

        # Step 2: Drop rows with nulls in key columns
        if drop_null_cols:
            cleaned, removed_nulls = self._drop_null_rows(deduped, drop_null_cols)
        else:
            cleaned, removed_nulls = deduped, 0

        # Step 3: Cast types based on schema
        typed = self._cast_types(cleaned)

        # Step 4: Compute statistics for numeric columns
        stats = {}
        if numeric_cols:
            for col in numeric_cols:
                stats[col] = self._compute_column_stats(typed, col)

        elapsed = time.perf_counter() - start_time

        return ProcessingResult(
            original_row_count=original_count,
            cleaned_row_count=len(typed),
            removed_duplicates=removed_dupes,
            removed_nulls=removed_nulls,
            column_stats=stats,
            cleaned_rows=typed,
            processing_time_seconds=elapsed,
        )

    def _deduplicate(self, rows: list[dict]) -> tuple[list[dict], int]:
        """
        Remove exact duplicate rows while preserving order.

        HOW IT WORKS:
        - We iterate through rows and track seen "fingerprints".
        - Each row is converted to a frozenset → hashable → usable in a set.
        - First occurrence is kept; subsequent duplicates are discarded.

        IN PANDAS: df.drop_duplicates()
        """
        seen: set[frozenset] = set()
        unique_rows = []
        for row in rows:
            fingerprint = frozenset(row.items())
            if fingerprint not in seen:
                seen.add(fingerprint)
                unique_rows.append(row)
        return unique_rows, len(rows) - len(unique_rows)

    def _drop_null_rows(
        self, rows: list[dict], required_cols: list[str]
    ) -> tuple[list[dict], int]:
        """
        Drop rows where any of the required columns are null.

        WHY THIS MATTERS:
        - A fact table row with a null customer_id is useless — you can't join on it.
        - A null timestamp means you can't do time-series analysis.
        - It's better to DROP these rows and track them in a "quarantine" table
          (an advanced DE pattern called "dead letter queue").

        IN PANDAS: df.dropna(subset=['customer_id', 'timestamp'])
        """
        null_markers = {"", "null", "none", "na", "n/a", "nan", "-", None}
        valid_rows = []
        for row in rows:
            if all(
                str(row.get(col, "")).strip().lower() not in null_markers
                for col in required_cols
                if col in row
            ):
                valid_rows.append(row)
        return valid_rows, len(rows) - len(valid_rows)

    def _cast_types(self, rows: list[dict]) -> list[dict]:
        """
        Convert string values to their proper Python types based on schema.

        WHY THIS MATTERS:
        CSV files store EVERYTHING as strings. "123" is not the same as 123.
        - "123" + "456" = "123456" (string concat!)
        - 123 + 456 = 579 (math!)
        Type casting is critical before any calculation.

        IN PANDAS: df.astype({'age': int, 'salary': float})
        """
        type_map = {"int": int, "float": float, "str": str}
        cast_rows = []

        for row in rows:
            new_row = {}
            for col, value in row.items():
                expected_type_str = self.schema.get(col, "str")
                cast_fn = type_map.get(expected_type_str, str)
                try:
                    # Only cast non-null values
                    if value and str(value).strip() not in {"", "null", "none"}:
                        new_row[col] = cast_fn(value)
                    else:
                        new_row[col] = None
                except (ValueError, TypeError):
                    new_row[col] = value  # Keep original if cast fails
            cast_rows.append(new_row)

        return cast_rows

    def _compute_column_stats(self, rows: list[dict], col: str) -> ColumnStats:
        """
        Compute descriptive statistics for a numeric column.

        THE OUTLIER DETECTION (3-Sigma Rule):
        - Calculate mean (μ) and standard deviation (σ).
        - Any value outside [μ - 3σ, μ + 3σ] is a statistical outlier.
        - In a normal distribution, 99.7% of values fall within 3 sigma.
        - Outliers could be data errors OR genuinely interesting anomalies.

        IN PANDAS: df['salary'].describe() + df[df['salary'] > mean + 3*std]
        IN DE USE: Outliers in transaction amounts could signal fraud!
        """
        stats = ColumnStats(column_name=col)

        # Extract numeric values, skipping nulls
        values = []
        for row in rows:
            val = row.get(col)
            try:
                if val is not None:
                    values.append(float(val))
            except (ValueError, TypeError):
                pass

        if not values:
            return stats

        stats.count = len(values)
        stats.mean = statistics.mean(values)
        stats.median = statistics.median(values)
        stats.min_val = min(values)
        stats.max_val = max(values)

        if len(values) >= 2:
            stats.std_dev = statistics.stdev(values)
            # 3-sigma outlier detection
            lower = stats.mean - 3 * stats.std_dev
            upper = stats.mean + 3 * stats.std_dev
            for i, (row, val) in enumerate(zip(rows, [r.get(col) for r in rows])):
                try:
                    if val is not None and (float(val) < lower or float(val) > upper):
                        stats.outlier_count += 1
                        stats.outlier_rows.append({"row_index": i, "value": val})
                except (ValueError, TypeError):
                    pass

        return stats
