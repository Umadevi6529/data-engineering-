"""
cache_engine.py — Redis-style Key-Value Cache Engine
=====================================================
HOW IT WORKS:
- Simulates an In-Memory Key-Value Data Store (Redis).
- Implements TTL (Time-To-Live) key expiration.
- Implements LRU (Least Recently Used) eviction when max size is reached.
- Implements the Cache-Aside (Lazy Loading) pattern for data pipelines.

DE CONCEPT:
- In production DE pipelines, caching repeated expensive database lookups
  (e.g., user profiles, product tax rates) reduces database load by up to 90%.
"""

import time
from collections import OrderedDict
from typing import Any, Callable, Dict, Optional, Tuple


class CacheEngine:
    """
    Simulated Redis Key-Value Cache with TTL & LRU Eviction.
    """

    def __init__(self, max_capacity: int = 100):
        self.max_capacity = max_capacity
        # Store format: key -> (value, expire_timestamp)
        self._store: OrderedDict[str, Tuple[Any, Optional[float]]] = OrderedDict()
        self.hits = 0
        self.misses = 0

    def get(self, key: str) -> Optional[Any]:
        """
        Retrieves value by key.
        Checks for TTL expiration. Evicts if expired.
        """
        if key not in self._store:
            self.misses += 1
            return None

        val, expire_at = self._store[key]

        # Check TTL expiration
        if expire_at is not None and time.time() > expire_at:
            del self._store[key]
            self.misses += 1
            return None

        # Move to end to record recent access (LRU order)
        self._store.move_to_end(key)
        self.hits += 1
        return val

    def set(self, key: str, value: Any, ttl_seconds: Optional[int] = None) -> None:
        """
        Sets a key-value pair with optional TTL (in seconds).
        """
        expire_at = (time.time() + ttl_seconds) if ttl_seconds else None

        if key in self._store:
            self._store.move_to_end(key)

        self._store[key] = (value, expire_at)

        # Evict oldest item if capacity exceeded (LRU Eviction)
        if len(self._store) > self.max_capacity:
            self._store.popitem(last=False)

    def delete(self, key: str) -> bool:
        """Deletes key from cache."""
        if key in self._store:
            del self._store[key]
            return True
        return False

    def cache_aside(
        self, key: str, fetch_from_db_func: Callable[[], Any], ttl_seconds: int = 300
    ) -> Tuple[Any, bool]:
        """
        Implements the Cache-Aside Pattern:
        1. Try to get value from Cache.
        2. If HIT: return cached value (is_hit = True).
        3. If MISS: call fetch_from_db_func(), save result to Cache with TTL, return (is_hit = False).
        """
        cached_val = self.get(key)
        if cached_val is not None:
            return cached_val, True  # Cache Hit

        # Cache Miss -> Fallback to Database/Source
        db_val = fetch_from_db_func()
        if db_val is not None:
            self.set(key, db_val, ttl_seconds=ttl_seconds)

        return db_val, False  # Cache Miss

    def get_stats(self) -> Dict[str, Any]:
        """Returns Cache efficiency statistics."""
        total_requests = self.hits + self.misses
        hit_rate = (self.hits / total_requests * 100) if total_requests > 0 else 0.0
        return {
            "total_keys": len(self._store),
            "hits": self.hits,
            "misses": self.misses,
            "hit_rate_pct": round(hit_rate, 2),
        }
