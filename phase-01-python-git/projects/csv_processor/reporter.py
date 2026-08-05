"""
reporter.py — Report Generation Module
=======================================
HOW IT WORKS:
- This is the "Load" step of our mini ETL — but instead of loading to a DB,
  we're generating a human-readable report.
- In production, this would write to: a database, S3 bucket, Slack webhook,
  email alert, or a BI dashboard like Tableau.

IN DATA ENGINEERING:
- Data profiling reports are standard in every mature DE team.
- Tools like Great Expectations (Phase 10) generate HTML reports automatically.
- For now, we build ours from scratch: plain text + optional CSV export.

THE CONCEPT OF "OBSERVABILITY":
- Once data hits your pipeline, you need to KNOW what happened to it.
- How many rows were processed? How many dropped? Were there anomalies?
- This report IS your pipeline's observability layer.
"""

import csv
import io
import os
from datetime import datetime

from processor import ProcessingResult
from validator import ValidationResult


class ReportGenerator:
    """
    Generates human-readable data quality and processing reports.

    REPORT SECTIONS:
    1. Pipeline Summary  — How did the run go overall?
    2. Validation Report — What did we find in the raw data?
    3. Processing Report — What did we do to clean it?
    4. Statistics        — What does the data look like numerically?
    5. Recommendations   — What should you fix next time?
    """

    def generate(
        self,
        filename: str,
        validation: ValidationResult,
        processing: ProcessingResult,
    ) -> str:
        """
        Generate a full text report combining validation + processing results.

        Returns:
            Formatted string report (also prints to console)
        """
        now = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        lines = []

        # ── HEADER ──────────────────────────────────────────────────────────
        lines += [
            "=" * 65,
            "  [DATA PIPELINE EXECUTION REPORT]",
            "=" * 65,
            f"  File        : {filename}",
            f"  Run Time    : {now}",
            f"  Status      : {'SUCCESS' if validation.is_valid else 'FAILED'}",
            "=" * 65,
            "",
        ]

        # ── SECTION 1: VALIDATION ───────────────────────────────────────────
        lines += [
            "──────────────────────────────────────────────────────────────",
            "  [1] VALIDATION RESULTS",
            "──────────────────────────────────────────────────────────────",
            validation.summary(),
            "",
        ]

        # ── SECTION 2: PROCESSING SUMMARY ───────────────────────────────────
        rows_dropped = processing.removed_duplicates + processing.removed_nulls
        pct_kept = (
            (processing.cleaned_row_count / processing.original_row_count * 100)
            if processing.original_row_count
            else 0
        )
        lines += [
            "──────────────────────────────────────────────────────────────",
            "  [2] PROCESSING SUMMARY",
            "──────────────────────────────────────────────────────────────",
            f"  Original rows       : {processing.original_row_count}",
            f"  Duplicates removed  : {processing.removed_duplicates}",
            f"  Null rows removed   : {processing.removed_nulls}",
            f"  Clean rows output   : {processing.cleaned_row_count} ({pct_kept:.1f}% of input)",
            f"  Processing time     : {processing.processing_time_seconds:.4f}s",
            "",
        ]

        # ── SECTION 3: COLUMN STATISTICS ────────────────────────────────────
        if processing.column_stats:
            lines += [
                "──────────────────────────────────────────────────────────────",
                "  [3] COLUMN STATISTICS",
                "──────────────────────────────────────────────────────────────",
            ]
            for col, stats in processing.column_stats.items():
                lines += [
                    f"  Column: '{col}'",
                    f"    Count   : {stats.count}",
                    f"    Mean    : {stats.mean:.2f}",
                    f"    Median  : {stats.median:.2f}",
                    f"    Std Dev : {stats.std_dev:.2f}",
                    f"    Min     : {stats.min_val:.2f}",
                    f"    Max     : {stats.max_val:.2f}",
                    f"    Outliers: {stats.outlier_count}",
                ]
                if stats.outlier_rows:
                    lines.append("    Outlier rows:")
                    for o in stats.outlier_rows[:5]:
                        lines.append(f"      Row {o['row_index'] + 1}: value = {o['value']}")
                lines.append("")

        # ── SECTION 4: RECOMMENDATIONS ──────────────────────────────────────
        recommendations = self._generate_recommendations(validation, processing)
        if recommendations:
            lines += [
                "──────────────────────────────────────────────────────────────",
                "  [4] RECOMMENDATIONS",
                "──────────────────────────────────────────────────────────────",
            ]
            for i, rec in enumerate(recommendations, 1):
                lines.append(f"  {i}. {rec}")
            lines.append("")

        lines.append("=" * 65)
        report = "\n".join(lines)
        return report

    def _generate_recommendations(
        self,
        validation: ValidationResult,
        processing: ProcessingResult,
    ) -> list[str]:
        """
        Generate actionable recommendations based on the data findings.

        IN A REAL DE TEAM:
        This is what a data quality SLA looks like. If nulls > 10% in a
        required column, you page the on-call engineer or block the pipeline.
        """
        recs = []

        if processing.removed_duplicates > 0:
            recs.append(
                f"Source data has {processing.removed_duplicates} duplicates. "
                "Check your upstream system for double-writes."
            )

        for col, count in validation.null_counts.items():
            if count > 0 and processing.original_row_count > 0:
                pct = count / processing.original_row_count
                if pct > 0.3:
                    recs.append(
                        f"Column '{col}' has {pct:.0%} nulls. Consider imputation "
                        "or excluding this column from analysis."
                    )

        for col, stats in processing.column_stats.items():
            if stats.outlier_count > 0:
                recs.append(
                    f"Column '{col}' has {stats.outlier_count} statistical outliers "
                    f"(>3σ from mean). Investigate before using in aggregations."
                )

        if not recs:
            recs.append("Data quality looks good! No major issues detected.")

        return recs

    def export_csv(
        self, rows: list[dict], output_path: str
    ) -> None:
        """
        Write cleaned rows to a CSV file.

        This is the "Load" step — writing output data.

        IN PRODUCTION:
        Instead of a CSV, you would:
        - Write to PostgreSQL with INSERT or COPY command
        - Write to S3 as a Parquet file
        - Stream to Kafka topic
        - Insert into BigQuery table
        """
        if not rows:
            print("  [WARNING] No rows to export.")
            return

        os.makedirs(os.path.dirname(output_path), exist_ok=True)

        with open(output_path, "w", newline="", encoding="utf-8") as f:
            writer = csv.DictWriter(f, fieldnames=rows[0].keys())
            writer.writeheader()
            writer.writerows(rows)

        print(f"  [OK] Cleaned data exported to: {output_path}")
        print(f"  Rows written: {len(rows)}")
