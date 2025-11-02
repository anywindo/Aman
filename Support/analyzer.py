#!/usr/bin/env python3
"""
Simple anomaly analyzer for Aman Network Analyzer Phase 1.

Input (stdin JSON):
{
  "packets": [
    {"timestamp": "...", "source": "...", "destination": "...", "transport": "...", "bytes": 128}
  ],
  "metrics": [
    {"timestamp": "...", "bytesPerSecond": 1024.0, "packetsPerSecond": 3.0}
  ],
  "params": {"windowSeconds": 60, "zThreshold": 3.0}
}
"""

import json
import statistics
import sys
import uuid
from collections import defaultdict
from datetime import datetime, timezone
from typing import List, Tuple


def parse_timestamp(value: str) -> float:
    if isinstance(value, (int, float)):
        return float(value)
    if not isinstance(value, str):
        raise ValueError(f"Unsupported timestamp type: {type(value)}")
    try:
        # Handle ISO8601 with Z suffix
        if value.endswith("Z"):
            value = value[:-1]
        return datetime.fromisoformat(value).replace(tzinfo=timezone.utc).timestamp()
    except Exception:
        return float(value)


def isoformat(ts: float) -> str:
    return datetime.fromtimestamp(ts, tz=timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")


def sliding_baseline(values: List[float], window: int) -> List[float]:
    baseline = []
    for idx in range(len(values)):
        start = max(0, idx - window + 1)
        window_values = values[start: idx + 1]
        if window_values:
            baseline.append(sum(window_values) / len(window_values))
        else:
            baseline.append(values[idx])
    return baseline


def rolling_stats(values: List[float]) -> Tuple[float, float]:
    if len(values) < 2:
        return values[0], 0.0
    mean = sum(values) / len(values)
    try:
        std = statistics.pstdev(values)
    except statistics.StatisticsError:
        std = 0.0
    if std == 0.0:
        # Fallback to MAD scaled to approximate std dev.
        med = statistics.median(values)
        deviations = [abs(v - med) for v in values]
        mad = statistics.median(deviations) if deviations else 0.0
        std = 1.4826 * mad
    return mean, std


def detect_anomalies(timestamps, series, baseline, metric_name, threshold, window_count, stats_fn=rolling_stats):
    anomalies = []
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
                    "timestamp": isoformat(ts),
                    "metric": metric_name,
                    "value": value,
                    "baseline": base,
                    "zScore": z_score,
                    "direction": "spike" if value >= mean else "drop",
                }
            )
    return anomalies


def rolling_stats_mad(values: list[float]) -> tuple[float, float]:
    median = statistics.median(values)
    deviations = [abs(v - median) for v in values]
    mad = statistics.median(deviations) if deviations else 0.0
    if mad <= 1e-9:
        return median, 0.0
    return median, 1.4826 * mad


def ewma_baseline(values: list[float], alpha: float) -> list[float]:
    if not values:
        return []
    baseline = [values[0]]
    estimate = values[0]
    for value in values[1:]:
        estimate = alpha * value + (1.0 - alpha) * estimate
        baseline.append(estimate)
    return baseline


def detect_anomalies_ewma(timestamps, series, baseline, metric_name, threshold, window_count):
    anomalies = []
    residuals: list[float] = []
    for idx, (ts, value, base) in enumerate(zip(timestamps, series, baseline)):
        residual = value - base
        residuals.append(residual)
        start = max(0, idx - window_count)
        window_values = residuals[start:idx]
        if len(window_values) < 3:
            continue
        mean, std = rolling_stats(window_values)
        if std <= 1e-9:
            continue
        score = abs(residual - mean) / std
        if score >= threshold:
            anomalies.append(
                {
                    "id": str(uuid.uuid4()),
                    "timestamp": isoformat(ts),
                    "metric": metric_name,
                    "value": value,
                    "baseline": base,
                    "zScore": score,
                    "direction": "spike" if residual >= 0 else "drop",
                }
            )
    return anomalies


def safe_float(value):
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


def format_bytes(value: float) -> str:
    units = ["B", "KB", "MB", "GB", "TB"]
    if value <= 0:
        return "0 B"
    idx = 0
    while value >= 1024 and idx < len(units) - 1:
        value /= 1024
        idx += 1
    return f"{value:.1f} {units[idx]}"


def build_clusters(anomalies):
    if not anomalies:
        return []

    buckets: dict[tuple[str, str], list[dict]] = defaultdict(list)
    for anomaly in anomalies:
        tag_type = anomaly.get("tagType")
        tag_value = anomaly.get("tagValue")
        metric = anomaly.get("metric", "unknown")
        key_type = tag_type or "metric"
        key_value = tag_value or metric
        buckets[(key_type, key_value)].append(anomaly)

    clusters = []
    for (key_type, key_value), items in buckets.items():
        if not items:
            continue
        ordered = sorted(items, key=lambda entry: parse_timestamp(entry["timestamp"]))
        start_ts = parse_timestamp(ordered[0]["timestamp"])
        end_ts = parse_timestamp(ordered[-1]["timestamp"])
        peak = max(ordered, key=lambda entry: abs(float(entry.get("zScore", 0.0))))
        peak_ts = parse_timestamp(peak["timestamp"])
        peak_value = float(peak.get("value", 0.0))
        peak_z = abs(float(peak.get("zScore", 0.0)))
        bytes_values = [
            safe_float((entry.get("context") or {}).get("bytes"))
            for entry in ordered
            if safe_float((entry.get("context") or {}).get("bytes")) is not None
        ]
        total_bytes = sum(bytes_values) if bytes_values else None
        metric_name = peak.get("metric", key_value)
        actor = key_value if key_type != "metric" else metric_name
        direction = peak.get("direction", "spike")
        if bytes_values:
            highlighted = format_bytes(max(bytes_values))
        else:
            highlighted = f"{peak_value:.1f}"
        narrative = f"{actor} experienced a {direction} peaking at {highlighted} ({peak_z:.1f}σ)"
        confidence = min(1.0, 0.35 + len(ordered) / 10.0 + peak_z / 6.0)

        cluster = {
            "id": str(uuid.uuid4()),
            "tagType": None if key_type == "metric" else key_type,
            "tagValue": None if key_type == "metric" else key_value,
            "metric": metric_name,
            "window": {
                "lowerBound": isoformat(start_ts),
                "upperBound": isoformat(end_ts),
            },
            "peakTimestamp": isoformat(peak_ts),
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


def main() -> int:
    payload = sys.stdin.read()
    try:
        request = json.loads(payload or "{}")
    except json.JSONDecodeError as exc:
        sys.stderr.write(f"Invalid JSON: {exc}")
        return 1

    metrics = request.get("metrics") or []
    packets = request.get("packets") or []
    params = request.get("params") or {}
    payload_config = request.get("payloadConfig") or {}
    capture_mode = payload_config.get("captureMode", "standard")
    payload_enabled = bool(payload_config.get("payloadInspectionEnabled", False))
    algorithm = (params.get("algorithm") or "zscore").lower()
    ewma_alpha = float(params.get("ewmaAlpha", 0.3))

    if not metrics:
        sys.stderr.write("No metrics supplied.")
        return 1

    try:
        times = [parse_timestamp(m["timestamp"]) for m in metrics]
        bytes_series = [float(m.get("bytesPerSecond", 0.0)) for m in metrics]
        packet_series = [float(m.get("packetsPerSecond", 0.0)) for m in metrics]
        flow_series = [float(m.get("flowsPerSecond", 0.0)) for m in metrics]
        windows = [m.get("window", "perSecond") for m in metrics]
        protocol_hists = [m.get("protocolHistogram", {}) or {} for m in metrics]
        tag_metrics_list = [m.get("tagMetrics", {}) or {} for m in metrics]
    except (KeyError, ValueError, TypeError) as exc:
        sys.stderr.write(f"Invalid metric record: {exc}")
        return 1

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

    if algorithm == "ewma":
        baseline_bytes = ewma_baseline(bytes_series, ewma_alpha)
        baseline_packets = ewma_baseline(packet_series, ewma_alpha)
        baseline_flows = ewma_baseline(flow_series, ewma_alpha)
        byte_anomalies = detect_anomalies_ewma(times, bytes_series, baseline_bytes, "bytesPerSecond", z_threshold, window_count)
        packet_anomalies = detect_anomalies_ewma(times, packet_series, baseline_packets, "packetsPerSecond", z_threshold, window_count)
        flow_anomalies = detect_anomalies_ewma(times, flow_series, baseline_flows, "flowsPerSecond", z_threshold, window_count)
    else:
        baseline_bytes = sliding_baseline(bytes_series, window_count)
        baseline_packets = sliding_baseline(packet_series, window_count)
        baseline_flows = sliding_baseline(flow_series, window_count)
        stats_fn = rolling_stats_mad if algorithm == "mad" else rolling_stats
        byte_anomalies = detect_anomalies(times, bytes_series, baseline_bytes, "bytesPerSecond", z_threshold, window_count, stats_fn=stats_fn)
        packet_anomalies = detect_anomalies(times, packet_series, baseline_packets, "packetsPerSecond", z_threshold, window_count, stats_fn=stats_fn)
        flow_anomalies = detect_anomalies(times, flow_series, baseline_flows, "flowsPerSecond", z_threshold, window_count, stats_fn=stats_fn)

    tag_history: dict[tuple[str, str], list[float]] = {}
    tag_anomalies = []
    stats_fn = rolling_stats_mad if algorithm == "mad" else rolling_stats
    for idx, ts in enumerate(times):
        tag_metrics = tag_metrics_list[idx] if idx < len(tag_metrics_list) else {}
        for tag_type, entries in tag_metrics.items():
            if not isinstance(entries, dict):
                continue
            for tag_value, stats in entries.items():
                if not isinstance(stats, dict):
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
                    tag_anomalies.append({
                        "id": str(uuid.uuid4()),
                        "timestamp": isoformat(ts),
                        "metric": f"bytesPerSecond[{tag_type}]",
                        "value": value,
                        "baseline": mean,
                        "zScore": z_score,
                        "direction": "spike" if z_score > 0 else "drop",
                        "tagType": tag_type,
                        "tagValue": tag_value,
                        "context": {
                            "bytes": f"{value:.1f}",
                            "baseline": f"{mean:.1f}"
                        }
                    })

    payload_summary: dict[str, float] = {}
    if payload_enabled:
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
        payload_summary = {key: value for key, value in payload_summary.items() if value > 0.0}

    result = {
        "metrics": [
            {
                "timestamp": isoformat(ts),
                "window": window,
                "bytesPerSecond": bytes_val,
                "packetsPerSecond": pkt_val,
                "flowsPerSecond": flow_val,
                "protocolHistogram": hist,
                "tagMetrics": tag_metrics,
            }
            for ts, bytes_val, pkt_val, flow_val, window, hist, tag_metrics in zip(times, bytes_series, packet_series, flow_series, windows, protocol_hists, tag_metrics_list)
        ],
        "baseline": [
            {
                "timestamp": isoformat(ts),
                "window": window,
                "bytesPerSecond": base_bytes,
                "packetsPerSecond": base_packets,
                "flowsPerSecond": base_flows,
                "protocolHistogram": {},
                "tagMetrics": {},
            }
            for ts, base_bytes, base_packets, base_flows, window in zip(times, baseline_bytes, baseline_packets, baseline_flows, windows)
        ],
        "anomalies": byte_anomalies + packet_anomalies + flow_anomalies + tag_anomalies,
        "summary": {
            "totalPackets": len(packets),
            "totalBytes": sum(max(0, float(pkt.get("length", 0))) for pkt in packets),
            "meanBytesPerSecond": sum(bytes_series) / len(bytes_series),
            "meanPacketsPerSecond": sum(packet_series) / len(packet_series),
            "meanFlowsPerSecond": sum(flow_series) / len(flow_series),
            "windowSeconds": int(window_seconds),
            "zThreshold": z_threshold,
        },
        "clusters": build_clusters(byte_anomalies + packet_anomalies + flow_anomalies + tag_anomalies),
    }

    if payload_summary:
        result["payloadSummary"] = payload_summary
    result.setdefault("settings", {})
    result["settings"].update({
        "captureMode": capture_mode,
        "payloadInspectionEnabled": payload_enabled,
        "algorithm": algorithm,
        "ewmaAlpha": ewma_alpha,
    })

    sys.stdout.write(json.dumps(result))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
