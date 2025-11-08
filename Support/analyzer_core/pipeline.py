from __future__ import annotations

import json
import time
from dataclasses import dataclass, field
from datetime import datetime, timezone
from importlib import import_module
from pathlib import Path
import uuid
from typing import Any, Dict, Iterable, List, MutableMapping, Optional


def _default_manifest_path(base_path: Optional[Path]) -> Path:
    root = base_path or Path(__file__).resolve().parent.parent
    return root / "analyzer_pipeline.yaml"


def load_manifest(base_path: Optional[Path] = None) -> Dict[str, Any]:
    """Load the pipeline manifest (YAML or JSON).

    Falls back to JSON parsing if PyYAML is unavailable. JSON is valid YAML, so
    the manifest can be written using familiar braces while remaining YAML-compatible.
    """

    path = _default_manifest_path(base_path)
    if not path.exists():
        return {"version": "0", "detectors": []}

    text = path.read_text()
    try:
        import yaml  # type: ignore
    except Exception:
        return json.loads(text or "{}")
    else:
        data = yaml.safe_load(text) or {}
        if not isinstance(data, dict):
            raise ValueError("Pipeline manifest must decode to a mapping")
        return data


@dataclass
class DetectorConfig:
    identifier: str
    module: str
    cls: str
    enabled: bool = True
    config: Dict[str, Any] = field(default_factory=dict)


class PipelineContext:
    """Shared context passed to pipeline detectors."""

    def __init__(self) -> None:
        self.result: Dict[str, Any] = {}
        self.component_scores: List[Dict[str, Any]] = []
        self.reason_codes: List[str] = []
        self.seasonality_confidence: Optional[float] = None
        self.seasonality_payload: Optional[Dict[str, Any]] = None
        self.change_points: List[Dict[str, Any]] = []
        self.change_point_diagnostics: Optional[Dict[str, Any]] = None
        self.multivariate_scores: List[Dict[str, Any]] = []
        self.multivariate_diagnostics: Optional[Dict[str, Any]] = None
        self.new_talkers: List[Dict[str, Any]] = []
        self.new_talker_diagnostics: Optional[Dict[str, Any]] = None
        self.alert_events: List[Dict[str, Any]] = []
        self.alert_config: Optional[Dict[str, Any]] = None

    def merge_partial(self, payload: MutableMapping[str, Any]) -> None:
        for key, value in payload.items():
            if key in {"metrics", "baseline", "anomalies", "clusters"}:
                existing = self.result.setdefault(key, [])
                if isinstance(existing, list) and isinstance(value, Iterable):
                    existing.extend(list(value))
                else:
                    self.result[key] = value
            elif key == "summary":
                # Later detectors may refine summary; prefer last non-empty value.
                self.result[key] = value
            elif key == "settings":
                settings = self.result.setdefault(key, {})
                if isinstance(settings, dict) and isinstance(value, MutableMapping):
                    settings.update(value)
                else:
                    self.result[key] = value
            elif key == "payloadSummary":
                payload_summary = self.result.setdefault(key, {})
                if isinstance(payload_summary, dict) and isinstance(value, MutableMapping):
                    payload_summary.update(value)
                else:
                    self.result[key] = value
            elif key == "seasonality":
                if isinstance(value, MutableMapping):
                    self.seasonality_payload = dict(value)
                self.result[key] = value
            elif key == "changePoints":
                if isinstance(value, Iterable):
                    self.change_points.extend(list(value))
                elif isinstance(value, MutableMapping):
                    self.change_points.append(dict(value))
                self.result[key] = self.change_points
            elif key == "changePointDiagnostics":
                if isinstance(value, MutableMapping):
                    self.change_point_diagnostics = dict(value)
                self.result[key] = value
            elif key == "multivariateScores":
                if isinstance(value, Iterable):
                    self.multivariate_scores.extend(list(value))
                elif isinstance(value, MutableMapping):
                    self.multivariate_scores.append(dict(value))
                self.result[key] = self.multivariate_scores
            elif key == "multivariateDiagnostics":
                if isinstance(value, MutableMapping):
                    self.multivariate_diagnostics = dict(value)
                self.result[key] = value
            elif key == "newTalkers":
                if isinstance(value, Iterable):
                    self.new_talkers.extend(list(value))
                elif isinstance(value, MutableMapping):
                    self.new_talkers.append(dict(value))
                self.result[key] = self.new_talkers
            elif key == "newTalkerDiagnostics":
                if isinstance(value, MutableMapping):
                    self.new_talker_diagnostics = dict(value)
                self.result[key] = value
            elif key == "alerts":
                if isinstance(value, MutableMapping):
                    events = value.get("events")
                    config = value.get("config")
                    if isinstance(events, Iterable):
                        self.alert_events.extend(list(events))
                    if isinstance(config, MutableMapping):
                        self.alert_config = dict(config)
                    self.result[key] = {
                        "events": self.alert_events,
                        "config": self.alert_config,
                    }
                else:
                    self.result[key] = value
            else:
                self.result[key] = value

    def add_score(self, *, detector: str, score: float, weight: Optional[float] = None, label: Optional[str] = None, reasons: Optional[List[str]] = None) -> None:
        entry: Dict[str, Any] = {"detector": detector, "score": float(score)}
        if weight is not None:
            entry["weight"] = float(weight)
        if label:
            entry["label"] = label
        if reasons:
            entry["reasonCodes"] = list(dict.fromkeys(reasons))
            self.reason_codes.extend(entry["reasonCodes"])
        self.component_scores.append(entry)

    def set_seasonality_confidence(self, value: Optional[float]) -> None:
        self.seasonality_confidence = value

    def update_seasonality(self, payload: Dict[str, Any]) -> None:
        self.seasonality_payload = dict(payload)

    def serialize(self, processing_latency_ms: float) -> Dict[str, Any]:
        result = dict(self.result)
        advanced_detection = {
            "phase": "phase6.6",
            "scores": self.component_scores,
            "reasonCodes": list(dict.fromkeys(self.reason_codes)),
            "seasonalityConfidence": self.seasonality_confidence,
            "processingLatencyMs": round(processing_latency_ms, 3),
        }
        if self.seasonality_payload:
            advanced_detection["seasonality"] = self.seasonality_payload
        if self.change_points:
            advanced_detection["changePoints"] = self.change_points
        if self.change_point_diagnostics:
            advanced_detection["changePointDiagnostics"] = self.change_point_diagnostics
        if self.change_points and "changePoints" not in result:
            result["changePoints"] = self.change_points
        if self.multivariate_scores:
            advanced_detection["multivariate"] = {
                "scores": self.multivariate_scores,
                "diagnostics": self.multivariate_diagnostics,
            }
            if "multivariateScores" not in result:
                result["multivariateScores"] = self.multivariate_scores
            if self.multivariate_diagnostics and "multivariateDiagnostics" not in result:
                result["multivariateDiagnostics"] = self.multivariate_diagnostics
        elif self.multivariate_diagnostics:
            advanced_detection["multivariate"] = {
                "scores": [],
                "diagnostics": self.multivariate_diagnostics,
            }
        if self.new_talkers:
            advanced_detection["newTalkers"] = {
                "entries": self.new_talkers,
                "diagnostics": self.new_talker_diagnostics,
            }
            if "newTalkers" not in result:
                result["newTalkers"] = self.new_talkers
            if self.new_talker_diagnostics and "newTalkerDiagnostics" not in result:
                result["newTalkerDiagnostics"] = self.new_talker_diagnostics
        elif self.new_talker_diagnostics:
            advanced_detection["newTalkers"] = {
                "entries": [],
                "diagnostics": self.new_talker_diagnostics,
            }
        if self.alert_events or self.alert_config:
            advanced_detection["alerts"] = {
                "events": self.alert_events,
                "config": self.alert_config,
            }
        result["advancedDetection"] = advanced_detection
        return result


class AnalyzerPipeline:
    """Configurable analyzer pipeline that executes detector stages sequentially."""

    def __init__(self, manifest: Dict[str, Any], *, base_path: Optional[Path] = None) -> None:
        self.base_path = base_path or Path(__file__).resolve().parent.parent
        self.manifest = manifest
        self.detectors: List[tuple[DetectorConfig, Any]] = []
        for entry in manifest.get("detectors", []) or []:
            if not isinstance(entry, MutableMapping):
                continue
            config = DetectorConfig(
                identifier=str(entry.get("id") or entry.get("identifier") or "detector"),
                module=str(entry.get("module") or ""),
                cls=str(entry.get("class") or entry.get("cls") or ""),
                enabled=bool(entry.get("enabled", True)),
                config=dict(entry.get("config") or {}),
            )
            if not config.enabled:
                continue
            detector = self._load_detector(config)
            if detector is None:
                continue
            self.detectors.append((config, detector))

    def _load_detector(self, config: DetectorConfig) -> Optional[Any]:
        if not config.module or not config.cls:
            return None
        module = import_module(config.module)
        detector_cls = getattr(module, config.cls, None)
        if detector_cls is None:
            return None
        return detector_cls(config=config.config, base_path=self.base_path)

    def process(self, request: Dict[str, Any]) -> Dict[str, Any]:
        start = time.perf_counter()
        context = PipelineContext()

        controls = request.get("controls") or {}
        disabled_detectors = {str(identifier) for identifier in controls.get("disableDetectors", []) if isinstance(identifier, str)}
        param_overrides: Dict[str, Dict[str, Any]] = {
            str(key): value for key, value in (controls.get("detectorParams") or {}).items() if isinstance(value, MutableMapping)
        }
        alerts_config = controls.get("alerts") or request.get("alerts") or {}
        if isinstance(alerts_config, MutableMapping):
            context.alert_config = dict(alerts_config)
        else:
            alerts_config = {}

        for config, detector in self.detectors:
            identifier = config.identifier
            if identifier in disabled_detectors:
                continue
            override = param_overrides.get(identifier)
            if override and hasattr(detector, "settings") and isinstance(getattr(detector, "settings"), dict):
                detector.settings.update({key: override[key] for key in override.keys()})
            try:
                partial = detector.process(request, context)
            except Exception as exc:  # pragma: no cover - defensive logging hook
                context.add_score(
                    detector=config.identifier,
                    score=0.0,
                    label="detector-failure",
                    reasons=[f"error:{config.identifier}"]
                )
                context.merge_partial({
                    "settings": {
                        f"detector:{config.identifier}": "error",
                        f"detector:{config.identifier}:message": str(exc),
                    }
                })
                continue
            if partial:
                context.merge_partial(partial)

        self._ensure_summary(context, request)
        self._evaluate_alerts(context, alerts_config)
        latency_ms = (time.perf_counter() - start) * 1000.0
        return context.serialize(processing_latency_ms=latency_ms)

    @staticmethod
    def _evaluate_alerts(context: PipelineContext, alerts_config: MutableMapping[str, Any]) -> None:
        if not isinstance(alerts_config, MutableMapping):
            alerts_config = {}
        threshold = float(alerts_config.get("scoreThreshold", 0.9))
        destinations = alerts_config.get("destinations")
        if not isinstance(destinations, list):
            destinations = []

        events: List[Dict[str, Any]] = []
        for entry in context.component_scores:
            score = float(entry.get("score", 0.0))
            if score < threshold:
                continue
            detector = entry.get("detector", "detector")
            severity = "critical" if score >= threshold + 0.2 else "warning"
            events.append(
                {
                    "id": str(uuid.uuid4()),
                    "timestamp": datetime.now(tz=timezone.utc).isoformat(timespec="milliseconds"),
                    "detector": detector,
                    "score": score,
                    "severity": severity,
                    "destinations": destinations,
                    "message": f"Detector {detector} score {score:.2f} exceeded threshold {threshold:.2f}",
                }
            )

        if events:
            context.alert_events.extend(events)

    @staticmethod
    def _ensure_summary(context: PipelineContext, request: Dict[str, Any]) -> None:
        """Backfill summary and minimal metrics so the UI can render partial results."""

        def _coerce_float(value: Any) -> float:
            try:
                return float(value)
            except (TypeError, ValueError):
                return 0.0

        def _normalize_timestamp(value: Any) -> str:
            if isinstance(value, str):
                return value
            if isinstance(value, (int, float)):
                return datetime.fromtimestamp(float(value), tz=timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
            if isinstance(value, datetime):
                return value.astimezone(timezone.utc).isoformat(timespec="milliseconds").replace("+00:00", "Z")
            return str(value)

        metrics_payload = request.get("metrics") or []
        packets_payload = request.get("packets") or []

        metrics: List[MutableMapping[str, Any]] = [entry for entry in metrics_payload if isinstance(entry, MutableMapping)]
        packets: List[MutableMapping[str, Any]] = [entry for entry in packets_payload if isinstance(entry, MutableMapping)]

        sanitized_metrics: List[Dict[str, Any]] = []
        bytes_series: List[float] = []
        packets_series: List[float] = []
        flows_series: List[float] = []

        for metric in metrics:
            bytes_value = _coerce_float(metric.get("bytesPerSecond", 0.0) or 0.0)
            packets_value = _coerce_float(metric.get("packetsPerSecond", 0.0) or 0.0)
            flows_value = _coerce_float(metric.get("flowsPerSecond", 0.0) or 0.0)

            hist_payload = metric.get("protocolHistogram") or {}
            histogram: Dict[str, int] = {}
            if isinstance(hist_payload, MutableMapping):
                for key, value in hist_payload.items():
                    try:
                        histogram[str(key)] = int(value)
                    except (TypeError, ValueError):
                        continue

            tags_payload = metric.get("tagMetrics") or {}
            tag_metrics: Dict[str, Dict[str, Dict[str, float]]] = {}
            if isinstance(tags_payload, MutableMapping):
                for tag_type, entries in tags_payload.items():
                    if not isinstance(entries, MutableMapping):
                        continue
                    sanitized_entries: Dict[str, Dict[str, float]] = {}
                    for tag_value, stats in entries.items():
                        if not isinstance(stats, MutableMapping):
                            continue
                        sanitized_entries[str(tag_value)] = {
                            "bytes": _coerce_float(stats.get("bytes", 0.0)),
                            "packets": _coerce_float(stats.get("packets", 0.0)),
                        }
                    if sanitized_entries:
                        tag_metrics[str(tag_type)] = sanitized_entries

            sanitized_metrics.append(
                {
                    "timestamp": _normalize_timestamp(metric.get("timestamp")),
                    "window": str(metric.get("window", "perSecond")),
                    "bytesPerSecond": bytes_value,
                    "packetsPerSecond": packets_value,
                    "flowsPerSecond": flows_value,
                    "protocolHistogram": histogram,
                    "tagMetrics": tag_metrics,
                }
            )

            bytes_series.append(bytes_value)
            packets_series.append(packets_value)
            flows_series.append(flows_value)

        if sanitized_metrics and "metrics" not in context.result:
            context.merge_partial({"metrics": sanitized_metrics})

        if sanitized_metrics and "baseline" not in context.result:
            baseline = [
                {
                    "timestamp": entry.get("timestamp"),
                    "window": entry.get("window", "perSecond"),
                    "bytesPerSecond": entry.get("bytesPerSecond", 0.0),
                    "packetsPerSecond": entry.get("packetsPerSecond", 0.0),
                    "flowsPerSecond": entry.get("flowsPerSecond", 0.0),
                    "protocolHistogram": {},
                    "tagMetrics": {},
                }
                for entry in sanitized_metrics
            ]
            context.merge_partial({"baseline": baseline})

        if "anomalies" not in context.result:
            context.merge_partial({"anomalies": []})

        if "clusters" not in context.result:
            context.merge_partial({"clusters": []})

        raw_params = request.get("params")
        params = raw_params if isinstance(raw_params, MutableMapping) else {}
        window_seconds = params.get("windowSeconds", 60)
        try:
            window_seconds = int(float(window_seconds))
        except (TypeError, ValueError):
            window_seconds = 60

        z_threshold = params.get("zThreshold", 3.0)
        try:
            z_threshold = float(z_threshold)
        except (TypeError, ValueError):
            z_threshold = 3.0

        total_packets = len(packets)
        total_bytes = 0.0
        for packet in packets:
            try:
                total_bytes += max(0.0, float(packet.get("length", 0.0) or 0.0))
            except (TypeError, ValueError):
                continue

        def _average(series: List[float]) -> float:
            if not series:
                return 0.0
            return float(sum(series) / len(series))

        if "summary" not in context.result:
            summary = {
                "totalPackets": total_packets,
                "totalBytes": total_bytes,
                "meanBytesPerSecond": _average(bytes_series),
                "meanPacketsPerSecond": _average(packets_series),
                "meanFlowsPerSecond": _average(flows_series),
                "windowSeconds": window_seconds,
                "zThreshold": z_threshold,
            }

            context.merge_partial({"summary": summary})
