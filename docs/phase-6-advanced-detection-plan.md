Phase 6 Advanced Detection — Phased Delivery
===========================================

Overview
--------
Break Phase 6 into focused increments that de-risk ML-driven detection, surface explainable results, and maintain live capture responsiveness. Each phase ships a measurable outcome, feeds calibration data, and exposes guardrails for analysts.

Phase 6.1 — ML Foundation & Pipeline Skeleton
---------------------------------------------
**Objectives** establish modular analyzer pipeline, expand schema, prove deterministic behavior on fixtures.

- Python pipeline orchestrator loads `pipeline.yaml`, routes metrics through detector stages (seasonality, change-point, multivariate, entropy placeholders).
- JSON schema extended with `phase`, `scores`, `reasonCodes`, `seasonalityConfidence`, `processingLatencyMs` while keeping backward compatibility.
- Swift model layer updated with `AdvancedDetectionResult`, `DetectionComponentBreakdown`, and pass-through UI logging.
- Build labeled PCAP fixture set; add deterministic integration harness and CI wiring.

Phase 6.2 — Seasonality-Aware Baselines
---------------------------------------
**Objectives** introduce STL/Holt-Winters baselines, render seasonal bands, and calibrate thresholds.

- Implement Python seasonality detector with automatic cadence detection; emit baseline bands + confidence scores.
- Surface `advancedDetection.seasonality` payload (period, diagnostics, per-metric bands) for downstream consumers.
- Add calibration script replaying fixtures to tune thresholds, persist updates to manifest, and record ROC metrics.
- Swift timeline overlays seasonal bands and tooltips explaining baseline breaches.
- Add unit/integration tests for baseline accuracy; monitor processing time impact.

Phase 6.3 — Change-Point & Drift Monitoring
-------------------------------------------
**Objectives** integrate real-time change-point alerts and processing drift telemetry.

- Embed ruptures/Bayesian online change-point module producing onset/offset markers and magnitude data.
- Enhance pipeline logging with structured events (detector, score, latency) and emit `calibrationNeeded` warnings for score drift.
- Swift UI surfaces change-point annotations and a diagnostics drawer showing latency and drift indicators.
- Expand QA checklist to include long-running capture sessions validating stability.
- Surface `advancedDetection.changePoints` and `changePointDiagnostics` for downstream consumers and overlays.

Phase 6.4 — Multivariate Scoring & Explanations
-----------------------------------------------
**Objectives** compute joint anomaly scores and explain contributing metrics.

- Combine Mahalanobis distance with isolation forest ensemble across throughput, flows, retransmits, drops, latency; output score components and feature weights.
- Swift inspector panel ranks contributing metrics, visualizes weights, and narrates summary (“Flows + retransmits spiked beyond seasonal band”).
- Add performance profiling for high-dimensional scoring; enforce backpressure if >100 ms per batch.
- Update calibration harness to log confusion matrices per detector.
- Expose `advancedDetection.multivariate` payload (`scores`, `diagnostics`, per-feature contributions) for UI overlays and external export.

Phase 6.5 — Entropy & New Talker Detection
------------------------------------------
**Objectives** surface unseen actors and tag entropy spikes with actionable narratives.

- Implement rolling sketches/Bloom filters tracking tag tuples; emit entropy deltas and first-seen timestamps with reason codes.
- Swift “New Talkers” panel highlights actors, supports quick filtering, and cross-links to packet drill-down.
- Extend fixtures with synthetic unseen-talkers; add unit tests validating false positive bounds.

Phase 6.6 — Analyst Controls & Alerting
---------------------------------------
**Objectives** expose tuning controls, notifications, and manifest sync.

- Build Python config reload commands to adjust detector toggles/thresholds at runtime; validate config and respond with status.
- Swift tuning sheet presents sliders, toggles, preset profiles; persists preferences and syncs with Python via config channel.
- Integrate system notifications/webhooks for high-confidence anomalies with concise reason summaries.
- Document operational playbook (calibration workflow, config rollback, troubleshooting) and add accessibility review for new UI.
- Emit `alerts` payloads containing fired events plus config echo, and honor detector disable/override requests per analysis run.

Definition of Done for Phase 6
------------------------------
- All detector modules operate within latency budget (<100 ms/batch) under load testing.
- Calibration data, manifests, and fixtures live in version control with deterministic outcomes.
- Swift UI communicates detection confidence, contributing factors, and new talkers clearly with accessible affordances.
- Alerting and tuning controls validated in manual QA matrix covering live capture, replay, filtered views, and configuration changes.
