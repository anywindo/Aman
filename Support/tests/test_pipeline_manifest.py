import json
import math
import unittest
from datetime import datetime, timezone, timedelta
from pathlib import Path
from typing import Dict

from analyzer_core import AnalyzerPipeline, load_manifest


FIXTURE_DIR = Path(__file__).resolve().parent.parent


def _iso(ts: datetime) -> str:
    return ts.replace(tzinfo=timezone.utc).isoformat(timespec="seconds") + "Z"


class PipelineManifestTests(unittest.TestCase):
    def test_manifest_loads_default_pipeline(self):
        manifest = load_manifest(base_path=FIXTURE_DIR)
        self.assertTrue(manifest.get("detectors"))

        pipeline = AnalyzerPipeline(manifest, base_path=FIXTURE_DIR)
        self.assertTrue(pipeline.detectors)

    def test_legacy_pipeline_round_trip(self):
        pipeline = AnalyzerPipeline(load_manifest(base_path=FIXTURE_DIR), base_path=FIXTURE_DIR)

        payload = {
            "metrics": [
                {
                    "timestamp": "2024-01-01T00:00:00Z",
                    "bytesPerSecond": 10.0,
                    "packetsPerSecond": 5.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {"tcp": 5},
                    "tagMetrics": {},
                },
                {
                    "timestamp": "2024-01-01T00:00:01Z",
                    "bytesPerSecond": 12.0,
                    "packetsPerSecond": 4.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {"tcp": 4},
                    "tagMetrics": {},
                },
            ],
            "packets": [],
        }

        result = pipeline.process(payload)

        self.assertIn("metrics", result)
        self.assertIn("baseline", result)
        self.assertIn("advancedDetection", result)
        advanced = result["advancedDetection"]
        self.assertEqual(advanced.get("phase"), "phase6.6")
        self.assertGreaterEqual(advanced.get("processingLatencyMs", 0), 0)
        self.assertIn("scores", advanced)

    def test_seasonality_detector_emits_band(self):
        pipeline = AnalyzerPipeline(load_manifest(base_path=FIXTURE_DIR), base_path=FIXTURE_DIR)

        start = datetime(2024, 1, 1, 0, 0, 0)
        metrics = []
        period = 60
        for idx in range(180):
            ts = start + timedelta(seconds=idx)
            seasonal_component = 50 + 10 * math.sin(2 * math.pi * ((idx % period) / period))
            metrics.append(
                {
                    "timestamp": _iso(ts),
                    "bytesPerSecond": seasonal_component,
                    "packetsPerSecond": seasonal_component / 10,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                }
            )

        result = pipeline.process({"metrics": metrics, "packets": []})
        advanced = result.get("advancedDetection") or {}
        self.assertEqual(advanced.get("phase"), "phase6.6")
        seasonality = advanced.get("seasonality") or {}
        self.assertIsNotNone(seasonality)
        metrics_payload = seasonality.get("metrics") or {}
        bytes_payload = metrics_payload.get("bytesPerSecond") or {}
        band = bytes_payload.get("band") or []
        self.assertGreater(len(band), 0)
        confidence = bytes_payload.get("confidence", 0)
        self.assertGreater(confidence, 0.2)
        self.assertGreater(advanced.get("seasonalityConfidence", 0), 0.2)

    def test_change_point_detector_flags_shift(self):
        pipeline = AnalyzerPipeline(load_manifest(base_path=FIXTURE_DIR), base_path=FIXTURE_DIR)

        start = datetime(2024, 1, 1, 0, 0, 0)
        metrics = []
        for idx in range(360):
            ts = start + timedelta(seconds=idx)
            base = 40.0 if idx < 180 else 160.0
            metrics.append(
                {
                    "timestamp": _iso(ts),
                    "bytesPerSecond": base,
                    "packetsPerSecond": base / 8,
                    "flowsPerSecond": 2.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                }
            )

        result = pipeline.process({"metrics": metrics, "packets": []})
        advanced = result.get("advancedDetection") or {}
        change_points = advanced.get("changePoints") or []
        self.assertGreater(len(change_points), 0)
        directions = {entry.get("direction") for entry in change_points}
        self.assertIn("increase", directions)
        diagnostics = advanced.get("changePointDiagnostics") or {}
        self.assertEqual(diagnostics.get("detected"), len(change_points))

    def test_multivariate_detector_explains_contributors(self):
        pipeline = AnalyzerPipeline(load_manifest(base_path=FIXTURE_DIR), base_path=FIXTURE_DIR)

        start = datetime(2024, 1, 1, 0, 0, 0)
        metrics = []
        for idx in range(360):
            ts = start + timedelta(seconds=idx)
            base = 50.0
            if 200 <= idx < 240:
                base = 150.0
            metrics.append(
                {
                    "timestamp": _iso(ts),
                    "bytesPerSecond": base,
                    "packetsPerSecond": base / 12,
                    "flowsPerSecond": 1.5,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                }
            )

        result = pipeline.process({"metrics": metrics, "packets": []})
        advanced = result.get("advancedDetection") or {}
        multivariate = advanced.get("multivariate") or {}
        scores = multivariate.get("scores") or []
        self.assertGreater(len(scores), 0)
        contributions = scores[0].get("contributions") or []
        self.assertGreater(len(contributions), 0)
        top_features = {entry.get("feature") for entry in contributions[:2]}
        self.assertIn("bytesPerSecond", top_features)

    def test_new_talker_detector_flags_recent_tags(self):
        pipeline = AnalyzerPipeline(load_manifest(base_path=FIXTURE_DIR), base_path=FIXTURE_DIR)

        start = datetime(2024, 1, 1, 0, 0, 0)
        metrics = []
        for idx in range(200):
            ts = start + timedelta(seconds=idx)
            tag_metrics: Dict[str, Dict[str, Dict[str, float]]] = {
                "destination": {
                    "10.0.0.1": {"bytes": 5000.0}
                }
            }
            if idx >= 150:
                tag_metrics["destination"][f"203.0.113.{idx}"] = {"bytes": 4096.0}
            metrics.append(
                {
                    "timestamp": _iso(ts),
                    "bytesPerSecond": 40.0,
                    "packetsPerSecond": 4.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": tag_metrics,
                }
            )

        result = pipeline.process({"metrics": metrics, "packets": []})
        advanced = result.get("advancedDetection") or {}
        new_talkers = advanced.get("newTalkers") or {}
        entries = new_talkers.get("entries") or []
        self.assertGreater(len(entries), 0)
        first = entries[0]
        self.assertEqual(first.get("tagType"), "destination")
        self.assertGreater(first.get("totalBytes", 0), 0)

    def test_controls_can_disable_detector_and_raise_alerts(self):
        pipeline = AnalyzerPipeline(load_manifest(base_path=FIXTURE_DIR), base_path=FIXTURE_DIR)

        metrics = [
            {
                "timestamp": "2024-01-01T00:00:00Z",
                "bytesPerSecond": 200.0,
                "packetsPerSecond": 30.0,
                "flowsPerSecond": 6.0,
                "window": "perSecond",
                "protocolHistogram": {"tcp": 30},
                "tagMetrics": {},
            },
            {
                "timestamp": "2024-01-01T00:00:01Z",
                "bytesPerSecond": 220.0,
                "packetsPerSecond": 32.0,
                "flowsPerSecond": 6.0,
                "window": "perSecond",
                "protocolHistogram": {"tcp": 28},
                "tagMetrics": {},
            },
        ]

        payload = {
            "metrics": metrics,
            "packets": [],
            "controls": {
                "disableDetectors": ["seasonality"],
                "alerts": {
                    "scoreThreshold": 0.5,
                    "notificationsEnabled": True,
                    "webhookEnabled": False,
                    "destinations": ["notification"],
                },
            },
        }

        result = pipeline.process(payload)
        advanced = result.get("advancedDetection") or {}
        self.assertEqual(advanced.get("phase"), "phase6.6")
        self.assertNotIn("seasonality", advanced)
        alerts = advanced.get("alerts") or {}
        events = alerts.get("events") or []
        self.assertGreater(len(events), 0)
        event = events[0]
        self.assertIn("detector", event)
        self.assertGreaterEqual(event.get("score", 0), 0.5)


if __name__ == "__main__":
    unittest.main()
