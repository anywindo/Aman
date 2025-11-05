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


class MultivariateDetector(BaseDetector):
    """Computes joint anomaly scores across throughput metrics."""

    FEATURE_KEYS: tuple[str, ...] = ("bytesPerSecond", "packetsPerSecond", "flowsPerSecond")

    def __init__(self, *, config: Dict[str, Any], base_path) -> None:  # type: ignore[override]
        super().__init__(config=config, base_path=base_path)
        defaults: Dict[str, Any] = {
            "windowSeconds": 60.0,
            "threshold": 3.0,
            "minSamples": 180,
            "minFeatures": 2,
        }
        self.settings = {**defaults, **(self.config or {})}

    def process(self, request: Dict[str, Any], context: Any) -> Dict[str, Any]:
        metrics: List[MutableMapping[str, Any]] = list(request.get("metrics") or [])
        if len(metrics) < int(self.settings.get("minSamples", 180)):
            context.add_score(
                detector="multivariate",
                score=0.0,
                label="multivariate-inactive",
                reasons=["multivariate.insufficient-data"],
            )
            diagnostics = self._build_diagnostics(sample_interval=None, window_steps=None, evaluated=0)
            context.multivariate_diagnostics = diagnostics
            return {"multivariateDiagnostics": diagnostics}

        times, feature_series = self._extract_series(metrics)
        usable_features = [key for key, series in feature_series.items() if series and any(series)]
        if len(usable_features) < int(self.settings.get("minFeatures", 2)):
            context.add_score(
                detector="multivariate",
                score=0.0,
                label="multivariate-too-few-features",
                reasons=["multivariate.few-features"],
            )
            diagnostics = self._build_diagnostics(sample_interval=None, window_steps=None, evaluated=0)
            context.multivariate_diagnostics = diagnostics
            return {"multivariateDiagnostics": diagnostics}

        sample_interval = self._estimate_sample_interval(times)
        if sample_interval <= 0:
            context.add_score(
                detector="multivariate",
                score=0.0,
                label="multivariate-bad-interval",
                reasons=["multivariate.invalid-sample-interval"],
            )
            diagnostics = self._build_diagnostics(sample_interval=None, window_steps=None, evaluated=0)
            context.multivariate_diagnostics = diagnostics
            return {"multivariateDiagnostics": diagnostics}

        window_seconds = float(self.settings.get("windowSeconds", 60.0))
        window_steps = max(5, int(round(window_seconds / sample_interval)))
        threshold = float(self.settings.get("threshold", 3.0))

        evaluations = 0
        detections: List[Dict[str, Any]] = []
        for index in range(window_steps, len(times)):
            history_slice = slice(index - window_steps, index)
            current_point = {feature: feature_series[feature][index] for feature in usable_features}
            baseline_stats = self._baseline_stats(feature_series, usable_features, history_slice)
            if not baseline_stats:
                continue
            evaluations += 1
            z_scores = self._z_scores(current_point, baseline_stats)
            if not z_scores:
                continue
            score = math.sqrt(sum(value**2 for value in z_scores.values()))
            if score < threshold:
                continue

            contributions = self._feature_contributions(z_scores)
            detections.append(
                {
                    "id": str(uuid.uuid4()),
                    "timestamp": _isoformat(times[index]),
                    "score": score,
                    "features": {feature: current_point.get(feature) for feature in usable_features},
                    "zScores": z_scores,
                    "contributions": contributions,
                }
            )

        diagnostics = self._build_diagnostics(sample_interval, window_steps, evaluations)
        context.multivariate_diagnostics = diagnostics

        if not detections:
            context.add_score(
                detector="multivariate",
                score=0.0,
                label="multivariate-none",
                reasons=["multivariate.none"],
            )
            return {
                "multivariateScores": [],
                "multivariateDiagnostics": diagnostics,
            }

        top_score = max(item["score"] for item in detections)
        normalized = min(1.0, top_score / max(threshold, 1e-6))
        context.add_score(
            detector="multivariate",
            score=normalized,
            label="multivariate-detected",
            reasons=["multivariate.detected"],
        )
        context.multivariate_scores.extend(detections)
        return {
            "multivariateScores": detections,
            "multivariateDiagnostics": diagnostics,
        }

    # ---- helpers ---------------------------------------------------------

    def _extract_series(self, metrics: Iterable[MutableMapping[str, Any]]) -> tuple[List[float], Dict[str, List[float]]]:
        records: List[tuple[float, Dict[str, float]]] = []
        for entry in metrics:
            try:
                ts = _parse_timestamp(entry["timestamp"])
            except Exception:
                continue
            record: Dict[str, float] = {}
            for feature in self.FEATURE_KEYS:
                try:
                    record[feature] = float(entry.get(feature, 0.0))
                except (TypeError, ValueError):
                    record[feature] = 0.0
            records.append((ts, record))

        records.sort(key=lambda item: item[0])
        times = [item[0] for item in records]
        features: Dict[str, List[float]] = {feature: [] for feature in self.FEATURE_KEYS}
        for _, record in records:
            for feature in self.FEATURE_KEYS:
                features[feature].append(record.get(feature, 0.0))
        return times, features

    @staticmethod
    def _estimate_sample_interval(times: List[float]) -> float:
        if len(times) < 2:
            return 0.0
        diffs = [times[idx + 1] - times[idx] for idx in range(len(times) - 1)]
        diffs = [diff for diff in diffs if diff > 0]
        if not diffs:
            return 0.0
        return statistics.median(diffs)

    def _baseline_stats(
        self,
        feature_series: Dict[str, List[float]],
        usable_features: List[str],
        history_slice: slice,
    ) -> Dict[str, tuple[float, float]]:
        stats: Dict[str, tuple[float, float]] = {}
        for feature in usable_features:
            window = feature_series[feature][history_slice]
            if len(window) < 5:
                continue
            mean = statistics.fmean(window)
            variance = statistics.pvariance(window)
            std_dev = math.sqrt(variance) if variance > 0 else 0.0
            stats[feature] = (mean, std_dev)
        return stats

    @staticmethod
    def _z_scores(
        point: Dict[str, float],
        stats: Dict[str, tuple[float, float]],
    ) -> Dict[str, float]:
        z_scores: Dict[str, float] = {}
        for feature, (mean, std_dev) in stats.items():
            value = point.get(feature)
            if value is None:
                continue
            if std_dev <= 1e-9:
                if abs(value - mean) <= 1e-6:
                    continue
                z_scores[feature] = math.copysign(10.0, value - mean)
            else:
                z_scores[feature] = (value - mean) / std_dev
        return z_scores

    @staticmethod
    def _feature_contributions(z_scores: Dict[str, float]) -> List[Dict[str, Any]]:
        if not z_scores:
            return []
        weights = {feature: abs(z) for feature, z in z_scores.items()}
        total = sum(weights.values()) or 1.0
        contributions = [
            {
                "feature": feature,
                "weight": weight / total,
                "zScore": z_scores[feature],
                "direction": "increase" if z_scores[feature] >= 0 else "decrease",
            }
            for feature, weight in weights.items()
        ]
        contributions.sort(key=lambda entry: abs(entry["zScore"]), reverse=True)
        return contributions

    @staticmethod
    def _build_diagnostics(sample_interval: Optional[float], window_steps: Optional[int], evaluated: int) -> Dict[str, Any]:
        return {
            "sampleIntervalSeconds": sample_interval,
            "windowSteps": window_steps,
            "evaluatedPoints": evaluated,
        }

