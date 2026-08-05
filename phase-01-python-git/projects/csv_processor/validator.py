"""
validator.py — Data Validation Module
=====================================
HOW IT WORKS:
- This module is responsible for the "quality gate" of our pipeline.
- Before we do any transformation, we need to know: is this data trustworthy?
- Think of it like a bouncer at a club — bad data doesn't get in.

IN DATA ENGINEERING:
- Every real pipeline has a validation step.
- Tools like Great Expectations (Phase 10) do this at scale.
- For now, we build it from scratch to understand the logic.
"""

import csv
from dataclasses import dataclass, field
from typing import Any


@dataclass
class ValidationResult:
    """
    A structured result from validating a dataset.

    Why dataclass?
    - It auto-generates __init__, __repr__, __eq__ — less boilerplate.
    - Used heavily in modern Python DE code.
    """
    is_valid: bool
    total_rows: int
    null_counts: dict = field(default_factory=dict)
    duplicate_count: int = 0
    type_errors: list = field(default_factory=list)
    warnings: list = field(default_factory=list)
    errors: list = field(default_factory=list)

    def summary(self) -> str:
        """Human-readable summary of validation results."""
        lines = [
            f"  Total rows      : {self.total_rows}",
            f"  Duplicates      : {self.duplicate_count}",
            f"  Valid           : {'✅ YES' if self.is_valid else '❌ NO'}",
        ]
        if self.null_counts:
            lines.append("  Null counts by column:")
            for col, count in self.null_counts.items():
                pct = (count / self.total_rows * 100) if self.total_rows else 0
                lines.append(f"    - {col}: {count} ({pct:.1f}%)")
        if self.type_errors:
            lines.append("  Type errors:")
            for err in self.type_errors[:5]:  # show first 5 only
                lines.append(f"    - {err}")
        if self.warnings:
            lines.append("  Warnings:")
            for w in self.warnings:
                lines.append(f"    ⚠️  {w}")
        if self.errors:
            lines.append("  Errors:")
            for e in self.errors:
                lines.append(f"    ❌ {e}")
        return "\n".join(lines)


class DataValidator:
    """
    Validates CSV data before processing.

    DE CONCEPT: Schema validation
    - Real pipelines define an expected schema (column names, types, nullability).
    - If incoming data doesn't match, we reject or quarantine it.
    - This prevents garbage from reaching the warehouse.

    Methods:
        validate(rows, schema): Full validation of a dataset
        check_nulls(rows): Find missing values per column
        check_duplicates(rows): Detect exact-row duplicates
        check_types(rows, schema): Check if values match expected types
    """

    SUPPORTED_TYPES = {
        "int": int,
        "float": float,
        "str": str,
    }

    def validate(
        self,
        rows: list[dict],
        schema: dict[str, str] | None = None,
        required_columns: list[str] | None = None,
        null_threshold: float = 0.5,  # warn if >50% nulls in a column
    ) -> ValidationResult:
        """
        Run all validations on the dataset.

        Args:
            rows: List of dicts (from CSV reader)
            schema: Optional dict like {"age": "int", "salary": "float"}
            required_columns: Columns that must not have any nulls
            null_threshold: Fraction above which we warn about nulls

        Returns:
            ValidationResult with all findings
        """
        result = ValidationResult(
            is_valid=True,
            total_rows=len(rows),
        )

        if not rows:
            result.is_valid = False
            result.errors.append("Dataset is empty — nothing to process.")
            return result

        # --- Check 1: Null / missing values ---
        result.null_counts = self.check_nulls(rows)
        for col, count in result.null_counts.items():
            pct = count / len(rows)
            if pct > null_threshold:
                result.warnings.append(
                    f"Column '{col}' has {pct:.0%} null values. Consider dropping or imputing."
                )
            if required_columns and col in required_columns and count > 0:
                result.is_valid = False
                result.errors.append(
                    f"Required column '{col}' has {count} null(s) — pipeline will fail."
                )

        # --- Check 2: Duplicate rows ---
        result.duplicate_count = self.check_duplicates(rows)
        if result.duplicate_count > 0:
            result.warnings.append(
                f"Found {result.duplicate_count} duplicate rows. They will be removed."
            )

        # --- Check 3: Type validation ---
        if schema:
            result.type_errors = self.check_types(rows, schema)
            if result.type_errors:
                result.warnings.append(
                    f"Found {len(result.type_errors)} type mismatches. Check schema."
                )

        return result

    def check_nulls(self, rows: list[dict]) -> dict[str, int]:
        """
        Count nulls (empty strings, None, 'null', 'NA', 'N/A') per column.

        WHY THIS MATTERS:
        Null handling is one of the most common bugs in data pipelines.
        A join on a null key produces wrong results. An AVG with nulls
        may give unexpected outputs. Always know your nulls!
        """
        if not rows:
            return {}

        null_markers = {"", "null", "none", "na", "n/a", "nan", "-"}
        null_counts: dict[str, int] = {col: 0 for col in rows[0].keys()}

        for row in rows:
            for col, value in row.items():
                if value is None or str(value).strip().lower() in null_markers:
                    null_counts[col] += 1

        return null_counts

    def check_duplicates(self, rows: list[dict]) -> int:
        """
        Count exact duplicate rows.

        HOW IT WORKS:
        - Convert each row dict to a frozenset of (key, value) pairs.
        - A frozenset is hashable → can be added to a set.
        - Duplicates = total rows - unique rows.
        """
        seen = set()
        duplicate_count = 0
        for row in rows:
            # frozenset makes the dict hashable for set membership
            row_key = frozenset(row.items())
            if row_key in seen:
                duplicate_count += 1
            else:
                seen.add(row_key)
        return duplicate_count

    def check_types(self, rows: list[dict], schema: dict[str, str]) -> list[str]:
        """
        Verify that column values can be cast to the expected type.

        Example schema: {"age": "int", "price": "float", "name": "str"}

        IN REAL DE:
        This is called "schema enforcement" or "schema-on-write".
        Parquet files do this automatically. For raw CSVs, we do it manually.
        """
        errors = []
        for row_idx, row in enumerate(rows):
            for col, expected_type_str in schema.items():
                if col not in row:
                    continue
                value = row[col]
                if value is None or str(value).strip() == "":
                    continue  # Skip nulls (handled by null check)

                expected_type = self.SUPPORTED_TYPES.get(expected_type_str)
                if not expected_type:
                    continue

                try:
                    expected_type(value)
                except (ValueError, TypeError):
                    errors.append(
                        f"Row {row_idx + 1}, col '{col}': "
                        f"cannot cast '{value}' to {expected_type_str}"
                    )
        return errors
