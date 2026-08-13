"""
main.py — Multi-Database Pipeline Runner
========================================
Demonstrates:
1. Document Database (MongoDB style) — Schema-on-Read, indexing, aggregation pipeline
2. Cache Engine (Redis style) — Cache-Aside strategy, TTL, Cache Hit/Miss metrics
3. Relational Exporter — Flattening nested JSON payloads to SQL Data Warehouse format

Run:
    python main.py
"""

import json
import sys
import time

# Force UTF-8 encoding on Windows terminals
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8")

from cache_engine import CacheEngine
from document_store import DocumentDatabase
from relational_exporter import RelationalExporter



def generate_sample_events():
    """Generates realistic nested NoSQL event payloads."""
    return [
        {
            "_id": "EVT_20260813_001",
            "event_type": "purchase",
            "timestamp": "2026-08-13T10:15:30Z",
            "user": {"user_id": "U101", "tier": "premium", "city": "Mumbai"},
            "device": {"os": "iOS", "type": "mobile"},
            "items": [
                {"product_id": "PROD_LAPTOP", "qty": 1, "price": 75000.00},
                {"product_id": "PROD_MOUSE", "qty": 2, "price": 450.00},
            ],
            "total_amount": 75900.00,
        },
        {
            "_id": "EVT_20260813_002",
            "event_type": "purchase",
            "timestamp": "2026-08-13T10:18:12Z",
            "user": {"user_id": "U102", "tier": "standard", "city": "Delhi"},
            "device": {"os": "Android", "type": "mobile"},
            "items": [
                {"product_id": "PROD_KEYBOARD", "qty": 1, "price": 1200.00},
            ],
            "total_amount": 1200.00,
        },
        {
            "_id": "EVT_20260813_003",
            "event_type": "purchase",
            "timestamp": "2026-08-13T11:05:45Z",
            "user": {"user_id": "U101", "tier": "premium", "city": "Mumbai"},
            "device": {"os": "macOS", "type": "desktop"},
            "items": [
                {"product_id": "PROD_MONITOR", "qty": 1, "price": 22000.00},
            ],
            "total_amount": 22000.00,
        },
        {
            "_id": "EVT_20260813_004",
            "event_type": "page_view",
            "timestamp": "2026-08-13T11:12:00Z",
            "user": {"user_id": "U103", "tier": "standard", "city": "Bangalore"},
            "device": {"os": "Windows", "type": "desktop"},
            "items": [],
            "total_amount": 0.00,
        },
        {
            "_id": "EVT_20260813_005",
            "event_type": "purchase",
            "timestamp": "2026-08-13T11:30:22Z",
            "user": {"user_id": "U104", "tier": "premium", "city": "Hyderabad"},
            "device": {"os": "Android", "type": "mobile"},
            "items": [
                {"product_id": "PROD_HEADPHONES", "qty": 1, "price": 3500.00},
            ],
            "total_amount": 3500.00,
        },
    ]


def main():
    print("=" * 70)
    print("  🚀 PHASE 3: MULTI-DATABASE & CACHING PIPELINE ENGINE")
    print("=" * 70)

    # -------------------------------------------------------------------------
    # STEP 1: Document Database Operations (MongoDB Style)
    # -------------------------------------------------------------------------
    print("\n[STEP 1] Initializing Document Database & Collection...")
    db = DocumentDatabase("analytics_db")
    events_coll = db.get_collection("clickstream_events")

    # Ingest events
    sample_events = generate_sample_events()
    inserted_ids = events_coll.insert_many(sample_events)
    print(f"  ✅ Ingested {len(inserted_ids)} raw JSON documents into collection 'clickstream_events'")

    # Create index
    print("  🔍 Creating index on field 'user.tier'...")
    events_coll.create_index("user.tier")

    # Execute MongoDB Aggregation Pipeline
    print("\n[STEP 2] Running MongoDB-style Aggregation Pipeline:")
    print("  Pipeline: $match (purchase events) -> $group (by user.tier) -> $project")

    pipeline = [
        {"$match": {"event_type": "purchase"}},
        {
            "$group": {
                "_id": "$user.tier",
                "total_revenue": {"$sum": "$total_amount"},
                "purchase_count": {"$sum": 1},
                "avg_ticket_size": {"$avg": "$total_amount"},
            }
        },
        {
            "$project": {
                "user_tier": "$_id",
                "total_revenue": 1,
                "purchase_count": 1,
                "avg_ticket_size": 1,
            }
        },
    ]

    agg_results = events_coll.aggregate(pipeline)
    print("\n  Aggregation Results:")
    print(json.dumps(agg_results, indent=4))

    # -------------------------------------------------------------------------
    # STEP 3: Key-Value Cache Operations (Redis Style & Cache-Aside)
    # -------------------------------------------------------------------------
    print("\n[STEP 3] Initializing Redis-style Cache Engine (Cache-Aside Pattern)...")
    cache = CacheEngine(max_capacity=50)

    # Mock primary database fetch function
    def db_fetch_user_profile(user_id: str):
        print(f"    🐢 [DB READ] Querying SQL database for user '{user_id}'...")
        profiles = {
            "U101": {"user_id": "U101", "name": "Priya Sharma", "tier": "premium", "credit_limit": 500000},
            "U102": {"user_id": "U102", "name": "Rahul Verma", "tier": "standard", "credit_limit": 50000},
            "U104": {"user_id": "U104", "name": "Meera Iyer", "tier": "premium", "credit_limit": 300000},
        }
        time.sleep(0.05)  # Simulate DB latency
        return profiles.get(user_id)

    # Requests simulation (Testing Hits vs Misses)
    user_requests = ["U101", "U102", "U101", "U104", "U101", "U102"]

    print("  Processing user profile lookups:")
    for user_id in user_requests:
        cache_key = f"user_profile:{user_id}"
        # Cache-Aside pattern call
        profile, is_hit = cache.cache_aside(
            key=cache_key,
            fetch_from_db_func=lambda uid=user_id: db_fetch_user_profile(uid),
            ttl_seconds=60,
        )
        status_str = "⚡ [CACHE HIT]" if is_hit else "❌ [CACHE MISS -> DB FETCH]"
        print(f"    Lookup '{user_id}': {status_str} -> Name: {profile['name'] if profile else 'N/A'}")

    stats = cache.get_stats()
    print(f"\n  Cache Efficiency Metrics:")
    print(f"    - Total Requests : {stats['hits'] + stats['misses']}")
    print(f"    - Hits           : {stats['hits']}")
    print(f"    - Misses         : {stats['misses']}")
    print(f"    - Hit Rate       : {stats['hit_rate_pct']}%")

    # -------------------------------------------------------------------------
    # STEP 4: Flattening NoSQL Documents to Relational SQL Schema
    # -------------------------------------------------------------------------
    print("\n[STEP 4] Relational Exporter (NoSQL Document -> SQL DW Format)...")
    exporter = RelationalExporter()
    parent_rows, child_rows = exporter.flatten_events(sample_events)

    print(f"  Flattened {len(sample_events)} documents into:")
    print(f"    - Parent Table 'stg_events': {len(parent_rows)} rows")
    print(f"    - Child Table  'stg_event_items': {len(child_rows)} rows")

    print("\n  Generated ANSI SQL Inserts for Parent Table (stg_events):")
    print("-" * 60)
    print(exporter.to_sql_inserts("stg_events", parent_rows[:2]))
    print("-" * 60)

    print("\n  Generated ANSI SQL Inserts for Child Table (stg_event_items):")
    print("-" * 60)
    print(exporter.to_sql_inserts("stg_event_items", child_rows[:3]))
    print("-" * 60)

    print("\n[DONE] Multi-Database Pipeline Run Complete! 🎉")


if __name__ == "__main__":
    main()
