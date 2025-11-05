from __future__ import annotations

import math
import statistics
from datetime import datetime, timezone
from typing import Any, Dict, Iterable, List, MutableMapping, Optional, Tuple

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


def _seasonal_baseline(series: List[float], period_steps: int) -> Tuple[List[float], List[float]]:
    if period_steps <= 1 or len(series) < period_steps:
        return list(series), [0.0 for _ in series]

    seasonal_sums = [0.0] * period_steps
    seasonal_counts = [0] * period_steps
    for idx, value in enumerate(series):
        bucket = idx % period_steps
        seasonal_sums[bucket] += value
        seasonal_counts[bucket] += 1

    seasonal_means = [
        (seasonal_sums[idx] / seasonal_counts[idx]) if seasonal_counts[idx] else 0.0
        for idx in range(period_steps)
    ]

    baseline = [seasonal_means[idx % period_steps] for idx in range(len(series))]
    residuals = [value - baseline[idx] for idx, value in enumerate(series)]
    return baseline, residuals


class SeasonalityDetector(BaseDetector):
    """Detects repeating patterns and emits baseline bands for core metrics."""

    METRIC_KEYS = (
        ("bytesPerSecond", "bytes"),
        ("packetsPerSecond", "packets"),
        ("flowsPerSecond", "flows"),
    )

    def __init__(self, *, config: Dict[str, Any], base_path) -> None:  # type: ignore[override]
        super().__init__(config=config, base_path=base_path)
        defaults: Dict[str, Any] = {
            "periodCandidates": [60.0, 300.0, 900.0, 3600.0],
            "minCycles": 2.0,
            "minSamples": 60,
            "bandStdDevs": 2.0,
        }
        self.settings = {**defaults, **(self.config or {})}

    def process(self, request: Dict[str, Any], context: Any) -> Dict[str, Any]:
        metrics: List[MutableMapping[str, Any]] = list(request.get("metrics") or [])
        if len(metrics) < int(self.settings.get("minSamples", 60)):
            context.add_score(
                detector="seasonality",
                score=0.0,
                label="seasonality-inactive",
                reasons=["seasonality.insufficient-data"],
            )
            return {}

        times, series_map = self._extract_series(metrics)
        if not series_map:
            context.add_score(
                detector="seasonality",
                score=0.0,
                label="seasonality-no-series",
                reasons=["seasonality.no-series"],
            )
            return {}

        sample_interval = self._estimate_sample_interval(times)
        if sample_interval <= 0:
            context.add_score(
                detector="seasonality",
                score=0.0,
                label="seasonality-bad-sample-interval",
                reasons=["seasonality.invalid-sample-interval"],
            )
            return {}

        chosen_period, diagnostics = self._choose_period(series_map, sample_interval)
        if chosen_period is None:
            context.add_score(
                detector="seasonality",
                score=0.0,
                label="seasonality-no-period",
                reasons=["seasonality.period-missing"],
            )
            return {}

        period_steps = max(2, int(round(chosen_period / sample_interval)))
        metric_payload: Dict[str, Any] = {}
        confidences: List[float] = []
        band_std_multiplier = float(self.settings.get("bandStdDevs", 2.0))

        for metric_key, label in self.METRIC_KEYS:
            series = series_map.get(metric_key)
            if not series:
                continue
            baseline, residuals = _seasonal_baseline(series, period_steps)
            residual_std = math.sqrt(statistics.pvariance(residuals)) if len(residuals) > 1 else 0.0
            margin = band_std_multiplier * residual_std
            total_var = statistics.pvariance(series) if len(series) > 1 else 0.0
            explained = 0.0
            if total_var > 0.0:
                residual_var = statistics.pvariance(residuals) if len(residuals) > 1 else 0.0
                explained = max(0.0, min(1.0, 1.0 - (residual_var / (total_var + 1e-9))))
            confidences.append(explained)

            band = [
                {
                    "timestamp": _isoformat(times[idx]),
                    "baseline": baseline[idx],
                    "lower": max(0.0, baseline[idx] - margin),
                    "upper": baseline[idx] + margin,
                }
                for idx in range(len(series))
            ]

            metric_payload[metric_key] = {
                "confidence": explained,
                "residualStdDev": residual_std,
                "band": band,
            }

        if not metric_payload:
            context.add_score(
                detector="seasonality",
                score=0.0,
                label="seasonality-no-metrics",
                reasons=["seasonality.metrics-missing"],
            )
            return {}

        overall_confidence = sum(confidences) / len(confidences) if confidences else 0.0
        context.set_seasonality_confidence(overall_confidence)
        context.add_score(
            detector="seasonality",
            score=overall_confidence,
            label="seasonality-baseline",
            reasons=[f"seasonality.period:{int(chosen_period)}"],
        )

        payload = {
            "periodSeconds": chosen_period,
            "sampleIntervalSeconds": sample_interval,
            "metrics": metric_payload,
            "diagnostics": diagnostics,
        }

        context.update_seasonality(payload)
        return {"seasonality": payload}

    # ---- helpers ------------------------------------------------------------

    def _extract_series(self, metrics: Iterable[MutableMapping[str, Any]]) -> Tuple[List[float], Dict[str, List[float]]]:
        records: List[Tuple[float, Dict[str, float]]] = []
        for entry in metrics:
            try:
                ts = _parse_timestamp(entry["timestamp"])
            except Exception:
                continue
            record: Dict[str, float] = {}
            for metric_key, _ in self.METRIC_KEYS:
                try:
                    record[metric_key] = float(entry.get(metric_key, 0.0))
                except (TypeError, ValueError):
                    record[metric_key] = 0.0
            records.append((ts, record))

        records.sort(key=lambda item: item[0])
        times = [item[0] for item in records]

        series_map: Dict[str, List[float]] = {key: [] for key, _ in self.METRIC_KEYS}
        for _, record in records:
            for metric_key in series_map.keys():
                series_map[metric_key].append(record.get(metric_key, 0.0))

        series_map = {key: values for key, values in series_map.items() if any(values)}
        return times, series_map

    @staticmethod
    def _estimate_sample_interval(times: List[float]) -> float:
        times = sorted(times)
        if len(times) < 2:
            return 0.0
        diffs = [times[idx + 1] - times[idx] for idx in range(len(times) - 1)]
        diffs = [diff for diff in diffs if diff > 0]
        if not diffs:
            return 0.0
        return statistics.median(diffs)

    def _choose_period(self, series_map: Dict[str, List[float]], sample_interval: float) -> Tuple[Optional[float], Dict[str, Any]]:
        diagnostics: Dict[str, Any] = {
            "candidates": [],
            "selected": None,
        }
        period_candidates = list(self.settings.get("periodCandidates", []))
        min_cycles = float(self.settings.get("minCycles", 2.0))
        best_period: Optional[float] = None
        best_score = -math.inf

        for raw_period in period_candidates:
            try:
                period_seconds = float(raw_period)
            except (TypeError, ValueError):
                continue
            if period_seconds <= 0:
                continue
            period_steps = int(round(period_seconds / sample_interval))
            if period_steps < 2:
                continue
            cycles = min(len(series) / period_steps for series in series_map.values() if series)
            if cycles < min_cycles:
                diagnostics["candidates"].append({
                    "periodSeconds": period_seconds,
                    "cycles": cycles,
                    "status": "insufficient-cycles",
                })
                continue

            explained_scores: List[float] = []
            for series in series_map.values():
                if len(series) < period_steps:
                    continue
                baseline, residuals = _seasonal_baseline(series, period_steps)
                total_var = statistics.pvariance(series) if len(series) > 1 else 0.0
                residual_var = statistics.pvariance(residuals) if len(residuals) > 1 else 0.0
                if total_var <= 0.0:
                    continue
                explained_scores.append(1.0 - (residual_var / (total_var + 1e-9)))

            if not explained_scores:
                diagnostics["candidates"].append({
                    "periodSeconds": period_seconds,
                    "cycles": cycles,
                    "status": "no-explained-score",
                })
                continue

            average_score = sum(explained_scores) / len(explained_scores)
            diagnostics["candidates"].append({
                "periodSeconds": period_seconds,
                "cycles": cycles,
                "explained": average_score,
                "status": "evaluated",
            })

            if average_score > best_score:
                best_score = average_score
                best_period = period_seconds

        if best_period is not None:
            diagnostics["selected"] = {
                "periodSeconds": best_period,
                "explained": best_score,
            }

        return best_period, diagnostics
