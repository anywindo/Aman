from __future__ import annotations

import math
import statistics
import uuid
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


class ChangePointDetector(BaseDetector):
    """Detects mean shifts in throughput metrics using paired rolling windows."""

    METRIC_KEYS = ("bytesPerSecond", "packetsPerSecond", "flowsPerSecond")

    def __init__(self, *, config: Dict[str, Any], base_path) -> None:  # type: ignore[override]
        super().__init__(config=config, base_path=base_path)
        defaults: Dict[str, Any] = {
            "windowSeconds": 60.0,
            "thresholdStdDevs": 2.0,
            "minSamples": 180,
            "minGapSeconds": 45.0,
        }
        self.settings = {**defaults, **(self.config or {})}

    def process(self, request: Dict[str, Any], context: Any) -> Dict[str, Any]:
        metrics: List[MutableMapping[str, Any]] = list(request.get("metrics") or [])
        if len(metrics) < int(self.settings.get("minSamples", 180)):
            context.add_score(
                detector="changepoint",
                score=0.0,
                label="changepoint-inactive",
                reasons=["changepoint.insufficient-data"],
            )
            diagnostics = self._build_diagnostics(sample_interval=None, window_steps=None, change_points=[])
            context.change_point_diagnostics = diagnostics
            return {"changePointDiagnostics": diagnostics}

        times, series_map = self._extract_series(metrics)
        if not series_map:
            context.add_score(
                detector="changepoint",
                score=0.0,
                label="changepoint-no-series",
                reasons=["changepoint.no-series"],
            )
            diagnostics = self._build_diagnostics(sample_interval=None, window_steps=None, change_points=[])
            context.change_point_diagnostics = diagnostics
            return {"changePointDiagnostics": diagnostics}

        sample_interval = self._estimate_sample_interval(times)
        if sample_interval <= 0:
            context.add_score(
                detector="changepoint",
                score=0.0,
                label="changepoint-bad-sample-interval",
                reasons=["changepoint.invalid-sample-interval"],
            )
            diagnostics = self._build_diagnostics(sample_interval=None, window_steps=None, change_points=[])
            context.change_point_diagnostics = diagnostics
            return {"changePointDiagnostics": diagnostics}

        window_seconds = float(self.settings.get("windowSeconds", 60.0))
        window_steps = max(2, int(round(window_seconds / sample_interval)))
        min_gap_seconds = float(self.settings.get("minGapSeconds", 45.0))
        min_gap_steps = max(1, int(round(min_gap_seconds / sample_interval)))
        threshold = float(self.settings.get("thresholdStdDevs", 3.0))

        change_points: List[Dict[str, Any]] = []
        best_scores: List[float] = []

        for metric_key in self.METRIC_KEYS:
            series = series_map.get(metric_key)
            if not series or len(series) < window_steps * 2:
                continue
            metric_points = self._detect_for_series(times, series, metric_key, window_steps, threshold, min_gap_steps)
            change_points.extend(metric_points)
            if metric_points:
                best_scores.append(max(abs(point["score"]) for point in metric_points))

        diagnostics = self._build_diagnostics(sample_interval, window_steps, change_points)
        context.change_point_diagnostics = diagnostics
        if not change_points:
            context.add_score(
                detector="changepoint",
                score=0.0,
                label="changepoint-none",
                reasons=["changepoint.none"],
            )
            return {
                "changePoints": [],
                "changePointDiagnostics": diagnostics,
            }

        aggregate_score = max(best_scores) if best_scores else 0.0
        normalized_score = min(1.0, aggregate_score / max(threshold, 1e-6))
        context.add_score(
            detector="changepoint",
            score=normalized_score,
            label="changepoint-detected",
            reasons=["changepoint.detected"],
        )
        return {
            "changePoints": change_points,
            "changePointDiagnostics": diagnostics,
        }

    # ---- helpers ----------------------------------------------------------

    def _extract_series(self, metrics: Iterable[MutableMapping[str, Any]]) -> tuple[List[float], Dict[str, List[float]]]:
        records: List[tuple[float, Dict[str, float]]] = []
        for entry in metrics:
            try:
                ts = _parse_timestamp(entry["timestamp"])
            except Exception:
                continue
            record: Dict[str, float] = {}
            for metric_key in self.METRIC_KEYS:
                try:
                    record[metric_key] = float(entry.get(metric_key, 0.0))
                except (TypeError, ValueError):
                    record[metric_key] = 0.0
            records.append((ts, record))

        records.sort(key=lambda item: item[0])
        times = [item[0] for item in records]
        series_map: Dict[str, List[float]] = {key: [] for key in self.METRIC_KEYS}
        for _, record in records:
            for key in self.METRIC_KEYS:
                series_map[key].append(record.get(key, 0.0))

        series_map = {key: values for key, values in series_map.items() if any(values)}
        return times, series_map

    @staticmethod
    def _estimate_sample_interval(times: List[float]) -> float:
        if len(times) < 2:
            return 0.0
        diffs = [times[idx + 1] - times[idx] for idx in range(len(times) - 1)]
        diffs = [diff for diff in diffs if diff > 0]
        if not diffs:
            return 0.0
        return statistics.median(diffs)

    def _detect_for_series(
        self,
        times: List[float],
        series: List[float],
        metric: str,
        window_steps: int,
        threshold: float,
        min_gap_steps: int,
    ) -> List[Dict[str, Any]]:
        change_points: List[Dict[str, Any]] = []
        last_index: Optional[int] = None

        for center in range(window_steps, len(series) - window_steps):
            if last_index is not None and center - last_index < min_gap_steps:
                continue

            before_window = series[center - window_steps:center]
            after_window = series[center:center + window_steps]
            if not before_window or not after_window:
                continue

            mean_before = statistics.fmean(before_window)
            mean_after = statistics.fmean(after_window)
            diff = mean_after - mean_before

            # Pooled standard deviation of combined windows.
            combined = before_window + after_window
            if len(combined) < 4:
                continue
            variance = statistics.pvariance(combined)
            std_dev = math.sqrt(variance)
            if std_dev <= 1e-9:
                if abs(diff) <= 1e-6:
                    continue
                score = math.copysign(threshold * 2.0, diff)
            else:
                score = diff / std_dev
            if abs(score) < threshold:
                continue

            timestamp = times[center]
            change_points.append(
                {
                    "id": str(uuid.uuid4()),
                    "timestamp": _isoformat(timestamp),
                    "metric": metric,
                    "direction": "increase" if diff > 0 else "decrease",
                    "beforeMean": mean_before,
                    "afterMean": mean_after,
                    "meanDelta": diff,
                    "score": score,
                }
            )
            last_index = center

        return change_points

    def _build_diagnostics(
        self,
        sample_interval: Optional[float],
        window_steps: Optional[int],
        change_points: Iterable[Dict[str, Any]],
    ) -> Dict[str, Any]:
        count = len(change_points) if isinstance(change_points, list) else len(list(change_points))
        return {
            "sampleIntervalSeconds": sample_interval,
            "windowSteps": window_steps,
            "thresholdStdDevs": float(self.settings.get("thresholdStdDevs", 3.0)),
            "windowSeconds": float(self.settings.get("windowSeconds", 60.0)),
            "detected": count,
        }
