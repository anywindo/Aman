# Aman ML/Analytics Pipeline

This document captures the Python-only analytics pipeline that powers network anomaly detection and related signals surfaced in the Aman macOS app.

## Overview
- Entry point: `Support/analyzer.py` reads JSON from stdin, builds the pipeline using `Support/analyzer_pipeline.yaml`, executes enabled detectors in sequence, and writes JSON to stdout.
- Pipeline orchestrator: `Support/analyzer_core/pipeline.py` loads the manifest (YAML or JSON), instantiates detector classes, applies control settings (disable/override), merges partial outputs, and emits `advancedDetection` plus normalized metrics/summaries.
- Detectors live under `Support/analyzer_core/detectors/` and conform to a simple `.process(request, context)` contract. Each detector can add scores, diagnostics, and payload fragments to the shared `PipelineContext`.

## Data Contract: Request (stdin JSON)
- Top-level keys:
  - `metrics`: list of per-window telemetry samples sorted by timestamp. Expected fields:
    - `timestamp` (ISO8601 or epoch), `window` (e.g., `perSecond`), `bytesPerSecond`, `packetsPerSecond`, `flowsPerSecond`
    - `protocolHistogram`: mapping protocol -> count (optional)
    - `tagMetrics`: nested tags (e.g., `destination` / `process` / `port`) each mapping identifier -> `{bytes, packets}` (optional)
  - `packets`: optional packet-level entries (used for payload summaries) with `length` and `info` strings.
  - `params`: overrides for detector parameters (z-thresholds, windows, etc.).
  - `controls`: optional runtime controls:
    - `disableDetectors`: list of detector ids to skip.
    - `detectorParams`: map of detector id -> parameter overrides merged into detector settings.
    - `alerts`: config for alerting (`scoreThreshold`, `destinations`).
  - `alerts`: legacy location for alert config (same shape as above).
  - `payloadConfig`: flags such as `captureMode` and `payloadInspectionEnabled` (consumed by `legacy` detector).

## Pipeline Execution
- Manifest: `Support/analyzer_pipeline.yaml` specifies detector order and default configs. Default stages (all enabled):
  1) `legacy` (`LegacyAnomalyDetector`): sliding/ewma baselines with z-score or MAD options; detects anomalies in bytes/packets/flows and tagMetrics; optional payload summary; clusters anomalies into narratives.
  2) `seasonality` (`SeasonalityDetector`): picks a repeating period from candidates, builds baseline bands (lower/upper) per metric, and estimates explained variance as confidence.
  3) `changepoint` (`ChangePointDetector`): detects mean shifts using paired rolling windows with std-dev scoring and minimum gap enforcement; returns change points plus diagnostics.
  4) `multivariate` (`MultivariateDetector`): joint anomaly score using L2 norm of feature z-scores across bytes/packets/flows; surfaces per-feature contributions.
  5) `newtalker` (`NewTalkerDetector`): finds first-seen tags (destination/process/port) within a recent window, computes entropy deltas, and returns top results.
- Controls: detectors marked `enabled: false` in the manifest are skipped; runtime `controls.disableDetectors` also bypasses stages. Parameter overrides cascade from request to detector settings when keys match.
- Error handling: individual detector exceptions add a scored failure entry with reason codes; pipeline continues with remaining detectors.

## Outputs (stdout JSON)
- Normalized base fields (backfilled if missing):
  - `metrics`, `baseline`, `anomalies`, `clusters`, `summary`, `settings`, `payloadSummary`
  - Optional: `seasonality`, `changePoints`, `changePointDiagnostics`, `multivariateScores`, `multivariateDiagnostics`, `newTalkers`, `newTalkerDiagnostics`, `alerts`
- `advancedDetection`: aggregated structure containing:
  - `phase`: pipeline version marker.
  - `scores`: list of `{detector, score, label?, weight?, reasonCodes?}` entries.
  - `reasonCodes`: deduplicated reasons accumulated across detectors.
  - `seasonalityConfidence`, `changePoints`, `multivariate` (scores + diagnostics), `newTalkers`, `alerts`, and per-detector diagnostics when available.
- Alerts: generated when any component score exceeds `alerts.scoreThreshold` (default 0.9); emitted with ids, timestamps, severities, and destinations.

## Detector Notes & Config Defaults
- `legacy`: defaults `algorithm=zscore`, `windowSeconds=60`, `zThreshold=3.0`, optional `ewmaAlpha`, `payloadInspectionEnabled` respected when provided.
- `seasonality`: defaults `periodCandidates=[60,300,900,3600]`, `minCycles=2`, `minSamples=60`, `bandStdDevs=2.0`; low sample counts yield zero scores and diagnostics only.
- `changepoint`: defaults `windowSeconds=60`, `thresholdStdDevs=2.0`, `minSamples=180`, `minGapSeconds=45`; outputs confidence-weighted change points per metric.
- `multivariate`: defaults `windowSeconds=60`, `threshold=3.0`, `minSamples=180`, `minFeatures=2`; scores are normalized against threshold.
- `newtalker`: defaults `recentWindowSeconds=180`, `minBytes=2048`, `maxEntries=10`; uses entropy deltas to rank novel tags.

## Running & Testing
- Run locally:
  ```bash
  cd Support
  python3 analyzer.py < sample_request.json
  ```
- Unit tests:
  ```bash
  cd Support
  python3 -m unittest discover -v
  ```
- Manifest tweaks: edit `Support/analyzer_pipeline.yaml` to reorder/enable/disable detectors or tune parameters; JSON is also accepted as valid YAML.

## Integration in the App
- The Swift-side `PythonProcessRunner` (Engine) invokes `analyzer.py`, sets `PYTHONPATH` to `Support/`, feeds request JSON from Swift network analyzer inputs, and decodes the returned structure. Decode failures persist the raw response to `~/Library/Logs/Aman/analyzer-last.json` for debugging.
