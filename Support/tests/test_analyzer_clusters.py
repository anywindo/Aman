import json
import subprocess
import sys
import unittest
import uuid
from datetime import datetime, timezone
from pathlib import Path

SUPPORT_ROOT = Path(__file__).resolve().parents[1]
if str(SUPPORT_ROOT) not in sys.path:
    sys.path.append(str(SUPPORT_ROOT))

from analyzer_core.detectors.legacy import LegacyAnomalyDetector, _isoformat


LEGACY = LegacyAnomalyDetector(config={}, base_path=SUPPORT_ROOT)


def _ts(offset_seconds: int) -> str:
    base = datetime(2024, 1, 1, 12, 0, 0, tzinfo=timezone.utc)
    return _isoformat(base.timestamp() + offset_seconds)


class ClusterBuilderTests(unittest.TestCase):
    def test_clusters_group_by_tag(self):
        anomalies = []
        for idx, offset in enumerate([0, 3, 6]):
            ts = _ts(offset)
            anomalies.append(
                {
                    "id": str(uuid.uuid4()),
                    "timestamp": ts,
                    "metric": "bytesPerSecond[protocol]",
                    "value": 2048 + (idx * 512),
                    "baseline": 512,
                    "zScore": 3.5 + idx,
                    "direction": "spike",
                    "tagType": "protocol",
                    "tagValue": "https",
                    "context": {"bytes": str(4096 + idx * 1024)},
                }
            )

        clusters = LEGACY._build_clusters(anomalies)
        self.assertEqual(len(clusters), 1)
        cluster = clusters[0]
        self.assertEqual(cluster["tagType"], "protocol")
        self.assertEqual(cluster["tagValue"], "https")
        self.assertEqual(cluster["totalAnomalies"], 3)
        self.assertEqual(set(cluster["anomalyIDs"]), {entry["id"] for entry in anomalies})
        self.assertGreater(cluster["peakZScore"], 3.0)
        self.assertIn("https", cluster["narrative"])
        self.assertIn("spike", cluster["narrative"])
        self.assertLessEqual(cluster["confidence"], 1.0)

    def test_metric_fallback_cluster(self):
        ts1 = _isoformat(datetime(2024, 1, 1, 15, 0, 0, tzinfo=timezone.utc).timestamp())
        ts2 = _isoformat(datetime(2024, 1, 1, 15, 0, 5, tzinfo=timezone.utc).timestamp())
        anomalies = [
            {
                "id": "metric-1",
                "timestamp": ts1,
                "metric": "bytesPerSecond",
                "value": 1200.0,
                "baseline": 600.0,
                "zScore": 4.2,
                "direction": "spike",
            },
            {
                "id": "metric-2",
                "timestamp": ts2,
                "metric": "bytesPerSecond",
                "value": 900.0,
                "baseline": 600.0,
                "zScore": 3.0,
                "direction": "spike",
            },
        ]

        clusters = LEGACY._build_clusters(anomalies)
        self.assertEqual(len(clusters), 1)
        cluster = clusters[0]
        self.assertIsNone(cluster["tagType"])
        self.assertIsNone(cluster["tagValue"])
        self.assertEqual(cluster["metric"], "bytesPerSecond")
        self.assertEqual(cluster["totalAnomalies"], 2)
        self.assertIn("bytesPerSecond", cluster["narrative"])

    def test_script_handles_small_metric_set(self):
        payload = {
            "metrics": [
                {
                    "timestamp": "2024-01-01T00:00:00Z",
                    "bytesPerSecond": 10.0,
                    "packetsPerSecond": 1.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                },
                {
                    "timestamp": "2024-01-01T00:00:01Z",
                    "bytesPerSecond": 12.0,
                    "packetsPerSecond": 1.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                },
            ],
            "packets": [],
            "params": {"windowSeconds": 60, "zThreshold": 3.0},
        }

        result = subprocess.run(
            [sys.executable, str(SUPPORT_ROOT / "analyzer.py")],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        output = json.loads(result.stdout or "{}")
        self.assertEqual(len(output.get("metrics", [])), 2)
        self.assertEqual(len(output.get("baseline", [])), 2)
        self.assertEqual(output.get("anomalies", []), [])
        self.assertIn("advancedDetection", output)

    def test_payload_summary_emitted_when_enabled(self):
        payload = {
            "metrics": [
                {
                    "timestamp": "2024-01-01T00:00:00Z",
                    "bytesPerSecond": 10.0,
                    "packetsPerSecond": 1.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                },
                {
                    "timestamp": "2024-01-01T00:00:01Z",
                    "bytesPerSecond": 12.0,
                    "packetsPerSecond": 1.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                },
                {
                    "timestamp": "2024-01-01T00:00:02Z",
                    "bytesPerSecond": 15.0,
                    "packetsPerSecond": 1.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                },
            ],
            "packets": [
                {"info": "TLSv1.2 Client Hello", "length": 512},
                {"info": "TLSv1.2 Server Hello", "length": 420},
                {"info": "HTTP GET /index.html", "length": 900},
            ],
            "params": {"windowSeconds": 60, "zThreshold": 3.0, "algorithm": "zscore", "ewmaAlpha": 0.3},
            "payloadConfig": {"captureMode": "privileged", "payloadInspectionEnabled": True},
        }

        result = subprocess.run(
            [sys.executable, str(SUPPORT_ROOT / "analyzer.py")],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        output = json.loads(result.stdout or "{}")
        summary = output.get("payloadSummary") or {}
        self.assertGreater(summary.get("tlsClientHello", 0), 0)
        self.assertGreater(summary.get("tlsServerHello", 0), 0)
        self.assertGreater(summary.get("httpRequests", 0), 0)
        self.assertIn("advancedDetection", output)
        settings = output.get("settings") or {}
        self.assertTrue(settings.get("payloadInspectionEnabled"))
        self.assertEqual(settings.get("algorithm"), "zscore")

    def test_algorithm_setting_applied(self):
        payload = {
            "metrics": [
                {
                    "timestamp": "2024-01-01T00:00:00Z",
                    "bytesPerSecond": 10.0,
                    "packetsPerSecond": 1.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                },
                {
                    "timestamp": "2024-01-01T00:00:01Z",
                    "bytesPerSecond": 12.0,
                    "packetsPerSecond": 1.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                },
                {
                    "timestamp": "2024-01-01T00:00:02Z",
                    "bytesPerSecond": 20.0,
                    "packetsPerSecond": 1.0,
                    "flowsPerSecond": 1.0,
                    "window": "perSecond",
                    "protocolHistogram": {},
                    "tagMetrics": {},
                },
            ],
            "packets": [],
            "params": {"windowSeconds": 60, "zThreshold": 2.5, "algorithm": "ewma", "ewmaAlpha": 0.4},
        }

        result = subprocess.run(
            [sys.executable, str(SUPPORT_ROOT / "analyzer.py")],
            input=json.dumps(payload),
            text=True,
            capture_output=True,
        )
        self.assertEqual(result.returncode, 0, msg=result.stderr)
        output = json.loads(result.stdout or "{}")
        settings = output.get("settings") or {}
        self.assertEqual(settings.get("algorithm"), "ewma")
        self.assertAlmostEqual(float(settings.get("ewmaAlpha", 0.0)), 0.4, places=2)


if __name__ == "__main__":
    unittest.main()
