from __future__ import annotations

import statistics
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from pathlib import Path
from typing import Any, Dict, Iterable, List, MutableMapping, Optional

from .base import BaseDetector


def _parse_timestamp(value: Any) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if not isinstance(value, str):
        raise ValueError(f"Unsupported timestamp type: {type(value)}")
    try:
        if value.endswith("Z"):
            value = value[:-1]
        return datetime.fromisoformat(value).replace(tzinfo=timezone.utc).timestamp()
    except Exception as exc:  # pragma: no cover - defensive casting
        raise ValueError(f"Cannot parse timestamp: {value}") from exc


def _isoformat(ts: float) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def _safe_float(value: Any) -> Optional[float]:
    if value is None:
        return None
    if isinstance(value, (int, float)):
        return float(value)
    if isinstance(value, str):
        try:
            return float(value)
        except ValueError:
            return None
    return None


def _format_bytes(value: float) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    if value <= 0:
        return "0 B"
    idx = 0
    while value >= 1024 and idx < len(units) - 1:
        value /= 1024
        idx += 1
    return f"{value:.1f} {units[idx]}"


class LegacyAnomalyDetector(BaseDetector):
    """Phase 1-5 anomaly logic wrapped as a detector stage."""

    def __init__(self, *, config: Dict[str, Any], base_path: Path) -> None:
        super().__init__(config=config, base_path=base_path)
        defaults = {
            "algorithm": "zscore",
            "windowSeconds": 60,
            "zThreshold": 3.0,
        }
        self.defaults = {**defaults, **(self.config or {})}

    # ---- Statistical helpers -------------------------------------------------

    @staticmethod
    def _sliding_baseline(values: List[float], window: int) -> List[float]:
        baseline: List[float] = []
        for idx in range(len(values)):
            start = max(0, idx - window + 1)
            window_values = values[start: idx + 1]
            if window_values:
                baseline.append(sum(window_values) / len(window_values))
            else:
                baseline.append(values[idx])
        return baseline

    @staticmethod
    def _ewma(values: List[float], alpha: float) -> List[float]:
        if not values:
            return []
        baseline = [values[0]]
        estimate = values[0]
        for value in values[1:]:
            estimate = alpha * value + (1.0 - alpha) * estimate
            baseline.append(estimate)
        return baseline

    @staticmethod
    def _rolling_stats(values: List[float]) -> tuple[float, float]:
        if len(values) < 2:
            return values[0], 0.0
        mean = sum(values) / len(values)
        try:
            std = statistics.pstdev(values)
        except statistics.StatisticsError:
            std = 0.0
        if std == 0.0:
            med = statistics.median(values)
            deviations = [abs(v - med) for v in values]
            mad = statistics.median(deviations) if deviations else 0.0
            std = 1.4826 * mad
        return mean, std

    @staticmethod
    def _rolling_stats_mad(values: List[float]) -> tuple[float, float]:
        median = statistics.median(values)
        deviations = [abs(v - median) for v in values]
        mad = statistics.median(deviations) if deviations else 0.0
        if mad <= 1e-9:
            return median, 0.0
        return median, 1.4826 * mad

    def process(self, request: Dict[str, Any], context: Any) -> Dict[str, Any]:
        metrics = request.get("metrics") or []
        packets = request.get("packets") or []
        params = {**self.defaults, **(request.get("params") or {})}
        payload_config = request.get("payloadConfig") or {}

        capture_mode = payload_config.get("captureMode", "standard")
        payload_enabled = bool(payload_config.get("payloadInspectionEnabled", False))

        if not metrics:
            raise ValueError("No metrics supplied")

        try:
            times = [_parse_timestamp(m["timestamp"]) for m in metrics]
            bytes_series = [float(m.get("bytesPerSecond", 0.0)) for m in metrics]
            packet_series = [float(m.get("packetsPerSecond", 0.0)) for m in metrics]
            flow_series = [float(m.get("flowsPerSecond", 0.0)) for m in metrics]
            windows = [m.get("window", "perSecond") for m in metrics]
            protocol_hists = [m.get("protocolHistogram", {}) or {} for m in metrics]
            tag_metrics_list = [m.get("tagMetrics", {}) or {} for m in metrics]
        except (KeyError, ValueError, TypeError) as exc:
            raise ValueError(f"Invalid metric record: {exc}") from exc

        paired = sorted(
            zip(times, bytes_series, packet_series, flow_series, windows, protocol_hists, tag_metrics_list),
            key=lambda item: item[0]
        )
        times = [p[0] for p in paired]
        bytes_series = [p[1] for p in paired]
        packet_series = [p[2] for p in paired]
        flow_series = [p[3] for p in paired]
        windows = [p[4] for p in paired]
        protocol_hists = [p[5] for p in paired]
        tag_metrics_list = [p[6] for p in paired]

        diffs = [times[i + 1] - times[i] for i in range(len(times) - 1)]
        sample_interval = max(1.0, statistics.median(diffs)) if diffs else 1.0

        window_seconds = float(params.get("windowSeconds", 60))
        z_threshold = float(params.get("zThreshold", 3.0))
        window_count = max(3, int(round(window_seconds / sample_interval)))

        algorithm = (params.get("algorithm") or "zscore").lower()
        ewma_alpha = float(params.get("ewmaAlpha", 0.3))

        if algorithm == "ewma":
            baseline_bytes = self._ewma(bytes_series, ewma_alpha)
            baseline_packets = self._ewma(packet_series, ewma_alpha)
            baseline_flows = self._ewma(flow_series, ewma_alpha)
            byte_anomalies = self._detect_anomalies_ewma(times, bytes_series, baseline_bytes, "bytesPerSecond", z_threshold, window_count)
            packet_anomalies = self._detect_anomalies_ewma(times, packet_series, baseline_packets, "packetsPerSecond", z_threshold, window_count)
            flow_anomalies = self._detect_anomalies_ewma(times, flow_series, baseline_flows, "flowsPerSecond", z_threshold, window_count)
        else:
            baseline_bytes = self._sliding_baseline(bytes_series, window_count)
            baseline_packets = self._sliding_baseline(packet_series, window_count)
            baseline_flows = self._sliding_baseline(flow_series, window_count)
            stats_fn = self._rolling_stats_mad if algorithm == "mad" else self._rolling_stats
            byte_anomalies = self._detect_anomalies(times, bytes_series, baseline_bytes, "bytesPerSecond", z_threshold, window_count, stats_fn=stats_fn)
            packet_anomalies = self._detect_anomalies(times, packet_series, baseline_packets, "packetsPerSecond", z_threshold, window_count, stats_fn=stats_fn)
            flow_anomalies = self._detect_anomalies(times, flow_series, baseline_flows, "flowsPerSecond", z_threshold, window_count, stats_fn=stats_fn)

        tag_anomalies = self._detect_tag_anomalies(times, tag_metrics_list, window_count, z_threshold, algorithm)

        payload_summary: Dict[str, float] = {}
        if payload_enabled:
            payload_summary = self._summarize_payload(packets)

        anomalies = byte_anomalies + packet_anomalies + flow_anomalies + tag_anomalies
        clusters = self._build_clusters(anomalies)

        context.add_score(
            detector="legacy",
            score=1.0,
            label="baseline-analyzer",
            reasons=["legacy.detector.active"],
        )

        result = {
            "metrics": [
                {
                    "timestamp": _isoformat(ts),
                    "window": window,
                    "bytesPerSecond": bytes_val,
                    "packetsPerSecond": pkt_val,
                    "flowsPerSecond": flow_val,
                    "protocolHistogram": hist,
                    "tagMetrics": tag_metrics,
                }
                for ts, bytes_val, pkt_val, flow_val, window, hist, tag_metrics in zip(
                    times, bytes_series, packet_series, flow_series, windows, protocol_hists, tag_metrics_list
                )
            ],
            "baseline": [
                {
                    "timestamp": _isoformat(ts),
                    "window": window,
                    "bytesPerSecond": base_bytes,
                    "packetsPerSecond": base_packets,
                    "flowsPerSecond": base_flows,
                    "protocolHistogram": {},
                    "tagMetrics": {},
                }
                for ts, base_bytes, base_packets, base_flows, window in zip(
                    times, baseline_bytes, baseline_packets, baseline_flows, windows
                )
            ],
            "anomalies": anomalies,
            "summary": {
                "totalPackets": len(packets),
                "totalBytes": sum(max(0, float(pkt.get("length", 0))) for pkt in packets),
                "meanBytesPerSecond": sum(bytes_series) / len(bytes_series),
                "meanPacketsPerSecond": sum(packet_series) / len(packet_series),
                "meanFlowsPerSecond": sum(flow_series) / len(flow_series),
                "windowSeconds": int(window_seconds),
                "zThreshold": z_threshold,
            },
            "clusters": clusters,
            "settings": {
                "captureMode": capture_mode,
                "payloadInspectionEnabled": payload_enabled,
                "algorithm": algorithm,
                "ewmaAlpha": float(params.get("ewmaAlpha", 0.3)),
            },
        }

        if payload_summary:
            result["payloadSummary"] = payload_summary

        return result

    # ---- Detection helpers ---------------------------------------------------

    def _detect_anomalies(
        self,
        timestamps: List[float],
        series: List[float],
        baseline: List[float],
        metric_name: str,
        threshold: float,
        window_count: int,
        *,
        stats_fn,
    ) -> List[Dict[str, Any]]:
        anomalies: List[Dict[str, Any]] = []
        for idx, (ts, value, base) in enumerate(zip(timestamps, series, baseline)):
            start = max(0, idx - window_count)
            window_values = series[start:idx]
            if len(window_values) < 3:
                continue
            mean, std = stats_fn(window_values)
            if std <= 1e-9:
                continue
            z_score = (value - mean) / std
            if abs(z_score) >= threshold:
                anomalies.append(
                    {
                        "id": str(uuid.uuid4()),
                        "timestamp": _isoformat(ts),
                        "metric": metric_name,
                        "value": value,
                        "baseline": base,
                        "zScore": z_score,
                        "direction": "spike" if value >= mean else "drop",
                    }
                )
        return anomalies

    def _detect_anomalies_ewma(
        self,
        timestamps: List[float],
        series: List[float],
        baseline: List[float],
        metric_name: str,
        threshold: float,
        window_count: int,
    ) -> List[Dict[str, Any]]:
        anomalies: List[Dict[str, Any]] = []
        residuals: List[float] = []
        for idx, (ts, value, base) in enumerate(zip(timestamps, series, baseline)):
            residual = value - base
            residuals.append(residual)
            start = max(0, idx - window_count)
            window_values = residuals[start:idx]
            if len(window_values) < 3:
                continue
            mean, std = self._rolling_stats(window_values)
            if std <= 1e-9:
                continue
            score = abs(residual - mean) / std
            if score >= threshold:
                anomalies.append(
                    {
                        "id": str(uuid.uuid4()),
                        "timestamp": _isoformat(ts),
                        "metric": metric_name,
                        "value": value,
                        "baseline": base,
                        "zScore": score,
                        "direction": "spike" if residual >= 0 else "drop",
                    }
                )
        return anomalies

    def _detect_tag_anomalies(
        self,
        timestamps: List[float],
        tag_metrics_list: Iterable[MutableMapping[str, Any]],
        window_count: int,
        z_threshold: float,
        algorithm: str,
    ) -> List[Dict[str, Any]]:
        tag_history: Dict[tuple[str, str], List[float]] = {}
        tag_anomalies: List[Dict[str, Any]] = []
        stats_fn = self._rolling_stats_mad if algorithm == "mad" else self._rolling_stats
        for idx, ts in enumerate(timestamps):
            tag_metrics = tag_metrics_list[idx] if idx < len(tag_metrics_list) else {}
            for tag_type, entries in (tag_metrics or {}).items():
                if not isinstance(entries, MutableMapping):
                    continue
                for tag_value, stats in (entries or {}).items():
                    if not isinstance(stats, MutableMapping):
                        continue
                    try:
                        value = float(stats.get("bytes", 0.0))
                    except (TypeError, ValueError):
                        continue
                    key = (tag_type, tag_value)
                    history = tag_history.setdefault(key, [])
                    history.append(value)
                    max_history = max(window_count * 4, window_count + 1)
                    if len(history) > max_history:
                        del history[:-max_history]
                    if len(history) < window_count:
                        continue
                    window_values = history[-window_count:]
                    mean, std = stats_fn(window_values)
                    if std <= 1e-9:
                        continue
                    z_score = (value - mean) / std
                    if abs(z_score) >= z_threshold:
                        tag_anomalies.append(
                            {
                                "id": str(uuid.uuid4()),
                                "timestamp": _isoformat(ts),
                                "metric": f"bytesPerSecond[{tag_type}]",
                                "value": value,
                                "baseline": mean,
                                "zScore": z_score,
                                "direction": "spike" if z_score > 0 else "drop",
                                "tagType": tag_type,
                                "tagValue": tag_value,
                                "context": {
                                    "bytes": f"{value:.1f}",
                                    "baseline": f"{mean:.1f}",
                                },
                            }
                        )
        return tag_anomalies

    def _summarize_payload(self, packets: Iterable[MutableMapping[str, Any]]) -> Dict[str, float]:
        tls_client_hello = 0
        tls_server_hello = 0
        http_requests = 0
        total_payload_bytes = 0.0
        for pkt in packets:
            info = (pkt.get("info") or "").lower()
            try:
                total_payload_bytes += max(0.0, float(pkt.get("length", 0.0)))
            except (TypeError, ValueError):
                pass
            if "client hello" in info:
                tls_client_hello += 1
            if "server hello" in info:
                tls_server_hello += 1
            if "http" in info and ("get" in info or "post" in info or "put" in info or "head" in info):
                http_requests += 1
        payload_summary = {
            "tlsClientHello": float(tls_client_hello),
            "tlsServerHello": float(tls_server_hello),
            "httpRequests": float(http_requests),
            "observedPayloadBytes": total_payload_bytes,
        }
        return {key: value for key, value in payload_summary.items() if value > 0.0}

    def _build_clusters(self, anomalies: Iterable[MutableMapping[str, Any]]) -> List[Dict[str, Any]]:
        anomaly_list = list(anomalies)
        if not anomaly_list:
            return []

        buckets: Dict[tuple[str, str], List[Dict[str, Any]]] = defaultdict(list)
        for anomaly in anomaly_list:
            tag_type = anomaly.get("tagType")
            tag_value = anomaly.get("tagValue")
            metric = anomaly.get("metric", "unknown")
            key_type = tag_type or "metric"
            key_value = tag_value or metric
            buckets[(key_type, key_value)].append(anomaly)

        clusters: List[Dict[str, Any]] = []
        for (key_type, key_value), items in buckets.items():
            if not items:
                continue
            ordered = sorted(items, key=lambda entry: _parse_timestamp(entry["timestamp"]))
            start_ts = _parse_timestamp(ordered[0]["timestamp"])
            end_ts = _parse_timestamp(ordered[-1]["timestamp"])
            peak = max(ordered, key=lambda entry: abs(float(entry.get("zScore", 0.0))))
            peak_ts = _parse_timestamp(peak["timestamp"])
            peak_value = float(peak.get("value", 0.0))
            peak_z = abs(float(peak.get("zScore", 0.0)))
            bytes_values = [
                _safe_float((entry.get("context") or {}).get("bytes"))
                for entry in ordered
                if _safe_float((entry.get("context") or {}).get("bytes")) is not None
            ]
            total_bytes = sum(bytes_values) if bytes_values else None
            metric_name = peak.get("metric", key_value)
            actor = key_value if key_type != "metric" else metric_name
            direction = peak.get("direction", "spike")
            highlighted = _format_bytes(max(bytes_values)) if bytes_values else f"{peak_value:.1f}"
            narrative = f"{actor} experienced a {direction} peaking at {highlighted} ({peak_z:.1f}σ)"
            confidence = min(1.0, 0.35 + len(ordered) / 10.0 + peak_z / 6.0)

            cluster = {
                "id": str(uuid.uuid4()),
                "tagType": None if key_type == "metric" else key_type,
                "tagValue": None if key_type == "metric" else key_value,
                "metric": metric_name,
                "window": {
                    "lowerBound": _isoformat(start_ts),
                    "upperBound": _isoformat(end_ts),
                },
                "peakTimestamp": _isoformat(peak_ts),
                "peakValue": peak_value,
                "peakZScore": peak_z,
                "totalAnomalies": len(ordered),
                "totalBytes": total_bytes,
                "confidence": round(confidence, 3),
                "narrative": narrative,
                "anomalyIDs": [entry["id"] for entry in ordered],
            }
            clusters.append(cluster)

        clusters.sort(key=lambda entry: entry["peakZScore"], reverse=True)
        return clusters
