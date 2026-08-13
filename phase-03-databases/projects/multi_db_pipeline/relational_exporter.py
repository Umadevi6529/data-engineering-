"""
relational_exporter.py — NoSQL to SQL DW Extractor
===================================================
HOW IT WORKS:
- Data Engineers often need to pull raw nested JSON documents from NoSQL
  databases (MongoDB, DynamoDB) and convert them into flat relational tables.
- This module takes nested JSON documents and flattens them into 
  normalized tables suitable for PostgreSQL / Snowflake / Redshift.

DE CONCEPT:
- Schema Normalization: Splitting a single nested document into 
  parent and child relational tables connected via Foreign Keys.
"""

from typing import Any, Dict, List, Tuple


class RelationalExporter:
    """
    Extracts & transforms raw nested NoSQL JSON documents
    into normalized Relational tables (Parent + Child tables).
    """

    @staticmethod
    def flatten_events(documents: List[Dict[str, Any]]) -> Tuple[List[Dict[str, Any]], List[Dict[str, Any]]]:
        """
        Transforms raw event JSON documents:
        Parent Table:  events (event_id, user_id, event_type, timestamp, device_os)
        Child Table:   event_items (item_id, event_id, item_code, quantity, price)

        Returns:
            (parent_rows, child_rows)
        """
        parent_rows = []
        child_rows = []

        for doc in documents:
            event_id = doc.get("_id") or doc.get("event_id")
            user_info = doc.get("user", {})
            device_info = doc.get("device", {})

            # 1. Extract Parent Row (Flattens nested dicts like user and device)
            p_row = {
                "event_id": event_id,
                "event_type": doc.get("event_type", "unknown"),
                "timestamp": doc.get("timestamp"),
                "user_id": user_info.get("user_id"),
                "user_tier": user_info.get("tier", "standard"),
                "device_os": device_info.get("os", "unknown"),
                "device_type": device_info.get("type", "unknown"),
                "total_amount": float(doc.get("total_amount", 0.0)),
            }
            parent_rows.append(p_row)

            # 2. Extract Child Rows (Unwinds array field: items)
            items = doc.get("items", [])
            for idx, item in enumerate(items, 1):
                c_row = {
                    "item_id": f"{event_id}_item_{idx}",
                    "event_id": event_id,  # Foreign Key linking to Parent
                    "product_id": item.get("product_id"),
                    "quantity": int(item.get("qty", 1)),
                    "unit_price": float(item.get("price", 0.0)),
                    "item_subtotal": round(int(item.get("qty", 1)) * float(item.get("price", 0.0)), 2),
                }
                child_rows.append(c_row)

        return parent_rows, child_rows

    @staticmethod
    def to_sql_inserts(table_name: str, rows: List[Dict[str, Any]]) -> str:
        """
        Generates standard ANSI SQL INSERT statements for PostgreSQL/DW.
        """
        if not rows:
            return f"-- No rows for table {table_name}"

        columns = list(rows[0].keys())
        col_names_str = ", ".join(columns)

        statements = [f"-- Table: {table_name} ({len(rows)} records)"]
        for r in rows:
            val_strs = []
            for col in columns:
                val = r[col]
                if val is None:
                    val_strs.append("NULL")
                elif isinstance(val, (int, float)):
                    val_strs.append(str(val))
                else:
                    # Escape single quotes in string literals
                    clean_str = str(val).replace("'", "''")
                    val_strs.append(f"'{clean_str}'")

            vals_joined = ", ".join(val_strs)
            stmt = f"INSERT INTO {table_name} ({col_names_str}) VALUES ({vals_joined});"
            statements.append(stmt)

        return "\n".join(statements)
