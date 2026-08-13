"""
document_store.py — Simulated NoSQL Document Database Engine
============================================================
HOW IT WORKS:
- Simulates a MongoDB-like Document Database.
- Stores documents as semi-structured JSON/dict objects in Collections.
- Implements secondary field Indexing for fast lookups.
- Implements a MongoDB-style Aggregation Pipeline ($match, $group, $project).

DE CONCEPT:
- Document databases store flexible schema payloads.
- Useful when source data varies row-by-row (e.g. event clickstream, dynamic product specs).
"""

import time
import uuid
from typing import Any, Dict, List, Optional


class DocumentCollection:
    """
    Simulates a MongoDB Collection.
    Holds semi-structured documents (dicts) with unique '_id' primary keys.
    """

    def __init__(self, name: str):
        self.name = name
        self._documents: Dict[str, Dict[str, Any]] = {}
        self._indexes: Dict[str, Dict[Any, List[str]]] = {}

    def create_index(self, field_name: str) -> None:
        """
        Creates a secondary index on a specific document field.
        Speed up $match queries on that field from O(N) scan to O(1) index lookup.
        """
        self._indexes[field_name] = {}
        for doc_id, doc in self._documents.items():
            val = self._extract_nested_field(doc, field_name)
            if val is not None:
                if val not in self._indexes[field_name]:
                    self._indexes[field_name][val] = []
                self._indexes[field_name][val].append(doc_id)

    def insert_one(self, document: Dict[str, Any]) -> str:
        """Inserts a single document into the collection."""
        doc = document.copy()
        if "_id" not in doc:
            doc["_id"] = f"doc_{uuid.uuid4().hex[:8]}"

        doc_id = doc["_id"]
        self._documents[doc_id] = doc

        # Update existing indexes
        for field_name, index_map in self._indexes.items():
            val = self._extract_nested_field(doc, field_name)
            if val is not None:
                if val not in index_map:
                    index_map[val] = []
                index_map[val].append(doc_id)

        return doc_id

    def insert_many(self, documents: List[Dict[str, Any]]) -> List[str]:
        """Inserts multiple documents."""
        return [self.insert_one(doc) for doc in documents]

    def find_one(self, query: Dict[str, Any]) -> Optional[Dict[str, Any]]:
        """Finds the first document matching query."""
        results = self.find(query)
        return results[0] if results else None

    def find(self, query: Dict[str, Any] = None) -> List[Dict[str, Any]]:
        """
        Find documents matching a filter query dictionary.
        Utilizes index if available.
        """
        if not query:
            return list(self._documents.values())

        # Check if indexed query is possible
        candidate_ids = None
        for field_name, value in query.items():
            if field_name in self._indexes:
                matching_ids = set(self._indexes[field_name].get(value, []))
                candidate_ids = matching_ids if candidate_ids is None else candidate_ids.intersection(matching_ids)

        if candidate_ids is not None:
            candidate_docs = [self._documents[doc_id] for doc_id in candidate_ids if doc_id in self._documents]
        else:
            candidate_docs = list(self._documents.values())

        # Final filtering scan
        matched = []
        for doc in candidate_docs:
            if self._matches_query(doc, query):
                matched.append(doc)
        return matched

    def aggregate(self, pipeline: List[Dict[str, Any]]) -> List[Dict[str, Any]]:
        """
        Executes a MongoDB-style aggregation pipeline:
        Supported stages: $match, $group, $project
        """
        current_docs = list(self._documents.values())

        for stage in pipeline:
            if "$match" in stage:
                current_docs = self._stage_match(current_docs, stage["$match"])
            elif "$group" in stage:
                current_docs = self._stage_group(current_docs, stage["$group"])
            elif "$project" in stage:
                current_docs = self._stage_project(current_docs, stage["$project"])

        return current_docs

    # --- Pipeline Stage Implementations ---

    def _stage_match(self, docs: List[Dict[str, Any]], match_spec: Dict[str, Any]) -> List[Dict[str, Any]]:
        return [doc for doc in docs if self._matches_query(doc, match_spec)]

    def _stage_group(self, docs: List[Dict[str, Any]], group_spec: Dict[str, Any]) -> List[Dict[str, Any]]:
        group_id_spec = group_spec.get("_id")
        groups: Dict[Any, List[Dict[str, Any]]] = {}

        for doc in docs:
            # Evaluate group key
            if isinstance(group_id_spec, str) and group_id_spec.startswith("$"):
                field_name = group_id_spec[1:]
                group_key = self._extract_nested_field(doc, field_name)
            else:
                group_key = group_id_spec

            if group_key not in groups:
                groups[group_key] = []
            groups[group_key].append(doc)

        aggregated_results = []
        for g_key, g_docs in groups.items():
            res_doc = {"_id": g_key}
            for key, expr in group_spec.items():
                if key == "_id":
                    continue
                if isinstance(expr, dict):
                    if "$sum" in expr:
                        sum_target = expr["$sum"]
                        if sum_target == 1:
                            res_doc[key] = len(g_docs)
                        elif isinstance(sum_target, str) and sum_target.startswith("$"):
                            f_name = sum_target[1:]
                            res_doc[key] = sum(
                                float(self._extract_nested_field(d, f_name) or 0) for d in g_docs
                            )
                    elif "$avg" in expr:
                        avg_target = expr["$avg"]
                        if isinstance(avg_target, str) and avg_target.startswith("$"):
                            f_name = avg_target[1:]
                            vals = [float(self._extract_nested_field(d, f_name) or 0) for d in g_docs]
                            res_doc[key] = round(sum(vals) / len(vals), 2) if vals else 0
            aggregated_results.append(res_doc)

        return aggregated_results

    def _stage_project(self, docs: List[Dict[str, Any]], project_spec: Dict[str, Any]) -> List[Dict[str, Any]]:
        projected = []
        for doc in docs:
            new_doc = {}
            for field, val in project_spec.items():
                if val == 1:
                    new_doc[field] = self._extract_nested_field(doc, field)
                elif isinstance(val, str) and val.startswith("$"):
                    f_name = val[1:]
                    new_doc[field] = self._extract_nested_field(doc, f_name)
                else:
                    new_doc[field] = val
            projected.append(new_doc)
        return projected

    # --- Helper methods ---

    def _matches_query(self, doc: Dict[str, Any], query: Dict[str, Any]) -> bool:
        for field, expected_val in query.items():
            actual_val = self._extract_nested_field(doc, field)
            if actual_val != expected_val:
                return False
        return True

    def _extract_nested_field(self, doc: Dict[str, Any], field_path: str) -> Any:
        """Helper to extract dot-notation fields e.g., 'user.location.city'."""
        parts = field_path.split(".")
        curr = doc
        for p in parts:
            if isinstance(curr, dict) and p in curr:
                curr = curr[p]
            else:
                return None
        return curr


class DocumentDatabase:
    """Simulates a MongoDB database containing collections."""

    def __init__(self, db_name: str):
        self.db_name = db_name
        self._collections: Dict[str, DocumentCollection] = {}

    def get_collection(self, collection_name: str) -> DocumentCollection:
        if collection_name not in self._collections:
            self._collections[collection_name] = DocumentCollection(collection_name)
        return self._collections[collection_name]
