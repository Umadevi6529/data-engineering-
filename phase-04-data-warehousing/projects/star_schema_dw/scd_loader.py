"""
scd_loader.py — SCD Type 2 ETL Processing Engine
=================================================
HOW IT WORKS:
- Manages Slowly Changing Dimension Type 2 (SCD2) loading logic.
- Takes incoming operational records, compares them against current DW records.
- If a tracked attribute changes (e.g., city, region, tier):
    1. Updates old DW record: set is_current = FALSE, end_date = change_date
    2. Inserts new DW record: set is_current = TRUE, effective_date = change_date, end_date = 9999-12-31
"""

import sqlite3
from datetime import datetime, date
from typing import Dict, Any, List, Optional


class SCD2Loader:
    """
    SCD Type 2 Loader Engine.
    Compatible with SQLite / PostgreSQL connections.
    """

    def __init__(self, db_conn: sqlite3.Connection):
        self.conn = db_conn

    def process_customer_update(self, incoming: Dict[str, Any], change_date: str) -> str:
        """
        Processes an incoming customer record using SCD Type 2.

        Returns status string: 'INSERTED_NEW', 'UPDATED_SCD2', or 'NO_CHANGE'
        """
        cursor = self.conn.cursor()
        customer_id = incoming["customer_id"]

        # Fetch current active record for this natural key
        cursor.execute(
            """
            SELECT customer_sk, city, region, tier
            FROM dim_customers_scd2
            WHERE customer_id = ? AND is_current = 1
            """,
            (customer_id,),
        )
        current_rec = cursor.fetchone()

        if current_rec is None:
            # Case 1: Brand new customer -> Insert new current row
            cursor.execute(
                """
                INSERT INTO dim_customers_scd2 (
                    customer_id, first_name, last_name, email, city, region, tier,
                    effective_date, end_date, is_current
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, '9999-12-31', 1)
                """,
                (
                    customer_id,
                    incoming["first_name"],
                    incoming["last_name"],
                    incoming["email"],
                    incoming["city"],
                    incoming["region"],
                    incoming["tier"],
                    change_date,
                ),
            )
            self.conn.commit()
            return "INSERTED_NEW"

        customer_sk, current_city, current_region, current_tier = current_rec

        # Check if tracked attributes have changed
        has_changed = (
            current_city != incoming["city"]
            or current_region != incoming["region"]
            or current_tier != incoming["tier"]
        )

        if not has_changed:
            return "NO_CHANGE"

        # Case 2: Attribute changed -> Execute SCD Type 2 Update
        # Step 2a: Expire current active row
        cursor.execute(
            """
            UPDATE dim_customers_scd2
            SET is_current = 0, end_date = ?
            WHERE customer_sk = ?
            """,
            (change_date, customer_sk),
        )

        # Step 2b: Insert new current row with updated attributes
        cursor.execute(
            """
            INSERT INTO dim_customers_scd2 (
                customer_id, first_name, last_name, email, city, region, tier,
                effective_date, end_date, is_current
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, '9999-12-31', 1)
            """,
            (
                customer_id,
                incoming["first_name"],
                incoming["last_name"],
                incoming["email"],
                incoming["city"],
                incoming["region"],
                incoming["tier"],
                change_date,
            ),
        )
        self.conn.commit()
        return "UPDATED_SCD2"

    def get_surrogate_key_for_date(self, customer_id: str, txn_date: str) -> Optional[int]:
        """
        Point-in-Time Surrogate Key Lookup:
        Finds the matching customer_sk for a fact transaction on a specific date.
        """
        cursor = self.conn.cursor()
        cursor.execute(
            """
            SELECT customer_sk
            FROM dim_customers_scd2
            WHERE customer_id = ?
              AND effective_date <= ?
              AND end_date > ?
            """,
            (customer_id, txn_date, txn_date),
        )
        row = cursor.fetchone()
        return row[0] if row else None
