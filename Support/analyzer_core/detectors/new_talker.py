from __future__ import annotations

import math
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, MutableMapping, Optional

from .base import BaseDetector


def _parse_timestamp(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if not isinstance(value, str):
        raise ValueError(f"Unsupported timestamp type: {type(value)}")
    if value.endswith("Z"):
        value = value[:-1]
    return datetime.fromisoformat(value).replace(tzinfo=timezone.utc).timestamp()


def _isoformat(ts: float) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


class NewTalkerDetector(BaseDetector):
    """Flags tags that appear for the first time within a recent window and estimates entropy deltas."""

    TAG_TYPES = ("destination", "process", "port")

    def __init__(self, *, config: Dict[str, Any], base_path) -> None:  # type: ignore[override]
        super().__init__(config=config, base_path=base_path)
        defaults: Dict[str, Any] = {
            "recentWindowSeconds": 180.0,
            "minBytes": 2048.0,
            "maxEntries": 10,
        }
        self.settings = {**defaults, **(self.config or {})}

    def process(self, request: Dict[str, Any], context: Any) -> Dict[str, Any]:
        metrics: List[MutableMapping[str, Any]] = list(request.get("metrics") or [])
        if not metrics:
            diagnostics = self._build_diagnostics(0, 0, 0)
            context.new_talker_diagnostics = diagnostics
            context.add_score(
                detector="newtalker",
                score=0.0,
                label="newtalker-no-metrics",
                reasons=["newtalker.no-metrics"],
            )
            return {"newTalkerDiagnostics": diagnostics}

        entries = self._collect_entries(metrics)
        total_seen = sum(len(tag_map) for tag_map in entries.values())
        if total_seen == 0:
            diagnostics = self._build_diagnostics(0, 0, 0)
            context.new_talker_diagnostics = diagnostics
            context.add_score(
                detector="newtalker",
                score=0.0,
                label="newtalker-none",
                reasons=["newtalker.none"],
            )
            return {
                "newTalkers": [],
                "newTalkerDiagnostics": diagnostics,
            }
        recent_window = float(self.settings.get("recentWindowSeconds", 180.0))
        min_bytes = float(self.settings.get("minBytes", 2048.0))
        max_entries = int(self.settings.get("maxEntries", 10))

        series_start = min(tag.first_seen for tag_map in entries.values() for tag in tag_map.values())
        series_end = max(tag.last_seen for tag_map in entries.values() for tag in tag_map.values())
        recent_cutoff = series_end - recent_window

        new_talkers: List[Dict[str, Any]] = []
        for tag_type, tag_map in entries.items():
            baseline_entropy = self._entropy([tag.total_bytes for tag in tag_map.values()])
            for tag in tag_map.values():
                if tag.total_bytes < min_bytes:
                    continue
                if tag.first_seen < recent_cutoff and tag.unique_windows > 1:
                    continue
                entropy_without = self._entropy([value.total_bytes for value in tag_map.values() if value.identifier != tag.identifier])
                delta = baseline_entropy - entropy_without
                new_talkers.append(
                    {
                        "id": str(uuid.uuid4()),
                        "tagType": tag_type,
                        "tagValue": tag.identifier,
                        "firstSeen": _isoformat(tag.first_seen),
                        "lastSeen": _isoformat(tag.last_seen),
                        "totalBytes": tag.total_bytes,
                        "samples": tag.unique_windows,
                        "entropyDelta": delta,
                    }
                )

        new_talkers.sort(key=lambda item: (item["firstSeen"], -item["totalBytes"]))
        selected = new_talkers[:max_entries]

        diagnostics = self._build_diagnostics(total_seen, len(new_talkers), len(selected))
        context.new_talker_diagnostics = diagnostics

        if not selected:
            context.add_score(
                detector="newtalker",
                score=0.0,
                label="newtalker-none",
                reasons=["newtalker.none"],
            )
            return {
                "newTalkers": [],
                "newTalkerDiagnostics": diagnostics,
            }

        context.add_score(
            detector="newtalker",
            score=min(1.0, len(selected) / max_entries),
            label="newtalker-detected",
            reasons=[f"newtalker.count:{len(selected)}"],
        )
        context.new_talkers.extend(selected)
        return {
            "newTalkers": selected,
            "newTalkerDiagnostics": diagnostics,
        }

    # ---- helper structures -------------------------------------------------

    class _TagInfo:
        def __init__(self, identifier: str, first_seen: float) -> None:
            self.identifier = identifier
            self.first_seen = first_seen
            self.last_seen = first_seen
            self.total_bytes = 0.0
            self.unique_windows = 0
            self.window_ids: set[int] = set()

        def register(self, bytes_value: float, timestamp: float, window_id: int) -> None:
            self.total_bytes += max(0.0, bytes_value)
            self.last_seen = max(self.last_seen, timestamp)
            if window_id not in self.window_ids:
                self.window_ids.add(window_id)
                self.unique_windows += 1

    def _collect_entries(self, metrics: List[MutableMapping[str, Any]]) -> Dict[str, Dict[str, "NewTalkerDetector._TagInfo"]]:
        tag_entries: Dict[str, Dict[str, NewTalkerDetector._TagInfo]] = {tag_type: {} for tag_type in self.TAG_TYPES}
        for index, metric in enumerate(sorted(metrics, key=lambda item: _parse_timestamp(item.get("timestamp", 0)))):
            timestamp = _parse_timestamp(metric.get("timestamp"))
            tag_metrics = metric.get("tagMetrics") or {}
            if not isinstance(tag_metrics, MutableMapping):
                continue
            for tag_type in self.TAG_TYPES:
                tag_values = tag_metrics.get(tag_type)
                if not isinstance(tag_values, MutableMapping):
                    continue
                for identifier, stats in tag_values.items():
                    if not isinstance(stats, MutableMapping):
                        continue
                    bytes_value = float(stats.get("bytes", 0.0) or 0.0)
                    tag_map = tag_entries[tag_type]
                    info = tag_map.get(identifier)
                    if info is None:
                        info = self._TagInfo(identifier=identifier, first_seen=timestamp)
                        tag_map[identifier] = info
                    info.register(bytes_value=bytes_value, timestamp=timestamp, window_id=index)
        return tag_entries

    @staticmethod
    def _entropy(values: Iterable[float]) -> float:
        total = sum(values)
        if total <= 0:
            return 0.0
        entropy = 0.0
        for value in values:
            if value <= 0:
                continue
            probability = value / total
            entropy -= probability * math.log2(probability)
        return entropy

    @staticmethod
    def _build_diagnostics(total_seen: int, detected: int, selected: int) -> Dict[str, Any]:
        return {
            "uniqueTagsEvaluated": total_seen,
            "detected": detected,
            "returned": selected,
        }
