Network Analyzer Workplan
Here’s a pragmatic, low-risk phased plan to add a Wireshark-style Network Analyzer to your macOS app, pairing Swift for capture/visualization with Python for anomaly scoring. Each phase is shippable and builds toward live, richer analysis.

Phase 1 — Capture & Bridge Foundations ✅
• Goal: Prove the Swift ⇄ Python bridge and deliver a usable UI with replayable captures.
• Swift
   • Add NetworkAnalyzerViewModel (interface inventory, live capture controller, PCAP ingestion, analyzer streaming state).
   • Add NetworkAnalyzerView (Wireshark-inspired layout: interface picker, start/stop, BPF filter, sample/import buttons, packet table, packet inspector).
   • Add NetworkAnalyzerDetailView (capture summary, timeline charts via Swift Charts if macOS 13+, anomalies panel fallback otherwise).
   • Add PythonProcessRunner (Process-based JSON bridge; reuse /usr/bin/python3 pattern from HashingService).
   • Add NetworkAnalyzerModels (PacketSample, MetricPoint, BaselinePoint, Anomaly, AnalyzerSummary, AnalyzerResult).
   • Wire into NetworkSecurityView when “Network Analyzer” is selected.
• Python
   • analyzer.py (bundled resource): accepts stdin JSON batches (metrics + packets metadata), returns JSON (summary/series/baseline/anomalies).
   • Seed with offline replay: ingest synthetic captures or bundled PCAP snippets, compute rolling baselines, flag outliers (z-score or MAD).
• Data
   • Bundle real PCAP/PCAPNG captures (pcap1.pcapng, pcap2.pcap) for deterministic replay and analysis.
• Deliverables
   • Visual timeline with anomaly markers, anomalies table, summary stats.
   • Clear messaging if Python 3 missing or bridge fails.

Phase 2 — Streaming Metrics & Rolling Detection ✅
• Goal: Turn live packet capture into real-time metrics and anomaly updates without root requirements.
• Inputs
   • libpcap/tcpdump subprocess with user-granted permissions, or replay mode targeting existing captures.
   • Lightweight system tools (netstat/lsof) as fallback for environments without libpcap access.
• Swift
   • Capture controller with start/stop, permission checks, and a ring buffer for PacketSample.
   • MetricAggregator that bins packets into per-second/per-minute aggregates (bytes/sec, flows/min, protocol counts).
   • Stream metric batches to PythonProcessRunner on a background queue; throttle UI updates on the main thread.
• Python
   • Incremental analyzer that maintains rolling baselines per metric, supports sliding window updates, and emits anomalies incrementally.
   • Handle NaNs, missing timestamps, and resampling.
• Deliverables
   • Live metric graphs with anomaly badges arriving within a few seconds of capture.
   • Replay mode proves parity between live and offline runs.

Phase 3 — Deep Dive Views & Context ✅
• Goal: Make anomalies actionable with packet and entity-level drill downs.
• Swift
   • Extend models with tags: process/executable (when available), destination IP/ASN/Geo, port, protocol.
   • UI filters and faceting (by tag, time range); detail pane overlays for per-tag timelines and top talkers.
   • Packet detail inspector mirroring key Wireshark panes for anomalies.
• Python
   • Per-tag baselines (process, destination, port) and relative anomaly scores.
   • Tag-aware clustering to highlight “who/where” behind spikes.
• Deliverables
   • Filtered charts, top-k summaries, anomaly explanations (“process X exceeded baseline 3.5σ on port 443”).

Phase 4 — Narrative Overlay & Correlation
• Goal: Layer richer context onto live and replayed captures without new capture inputs by narrating spikes and correlating the actors behind them.
• Swift
   • Extend existing timeline view model to emit annotation structs derived from anomaly + tag arrays; render annotation bands/badges while throttling density for large capture windows.
   • Add scrubber and zoom controls that respect active filters; selection updates filter state while filters clamp annotation visibility without re-querying Python.
   • Build a correlation side panel that groups spikes by shared destination/port/protocol tags; show burst metrics (peak bytes, affected flows) and narrative callouts per cluster.
   • Surface correlated cluster context inside the packet inspector to explain who/where/what for the selected anomaly; add debug overlay toggle for QA insight.
• Python
   • Introduce tag-cohesion scorer that ingests recent anomaly windows, computes overlap across tag tuples (destination, port, process), and emits clusters with confidence scores.
   • Stream incremental cluster updates through the existing JSON bridge alongside anomalies; version payloads and include reason codes for sparse-tag fallbacks.
   • Maintain rolling caches so clusters update as anomalies age out; add regression tests ensuring deterministic clustering and backward compatibility.
• Data & Tooling
   • Create fixture captures exercising multi-tag spikes to validate clustering heuristics and UI render density.
   • Update developer documentation describing new JSON fields and Swift model changes; provide profiling hooks to measure annotation rendering cost.
• Validation
   • Add Swift unit tests for annotation grouping/filter interaction; Python unit tests for cluster scoring; integration test that pipes sample anomalies through the bridge.
   • Manual QA matrix covering live capture, replay, filtered views, scrubber interaction, and accessibility (VoiceOver, contrast).
• Deliverables
   • Analysts can replay or monitor a spike and immediately see the actors involved, with correlated narratives and annotations, all without importing new data.

Phase 5 — Persistence & Sharing
• Goal: Let teams pause, resume, and share investigations safely.
• Swift
   • Session save/load using enriched PCAP bundles (capture + tags + anomalies) and quick-restore UI.
   • Export filtered metrics/anomalies to CSV/JSON and provide shareable top-talker summaries.
   • Preferences for default filters, streaming window, and alert thresholds.
• Python
   • Deterministic re-analysis so saved sessions regenerate the same anomaly IDs and narratives.
• Deliverables
   • Investigations survive restarts, while exports stay lightweight (CSV/JSON) and raw data remains PCAP.

Phase 6 — Advanced Detection (Optional)
• Goal: Raise detection quality for complex environments by layering ML-driven scoring, richer narratives, and configurable analyst controls without compromising responsiveness.
• Python Engine
   • Modularize analyzer into detector stages (seasonality, change-point, multivariate, entropy) orchestrated by a pipeline manifest (YAML/JSON) so features can be toggled without code changes.
   • Seasonality module: apply STL decomposition or Holt-Winters fallback per metric, cache seasonal components, and emit baseline bands plus `seasonalityConfidence` for UI shading.
   • Change-point module: integrate ruptures or Bayesian online change-point detection; return onset/offset timestamps, magnitude, and supporting metrics.
   • Multivariate module: fuse bytes/sec, flows/min, retransmits, drop/error ratios, and latency into a joint score (Mahalanobis + isolation forest ensemble) with feature importance weighting for explanations.
   • New-talker/entropy module: maintain rolling sketches of tag tuples (destination/process/port) to score first-seen entities and entropy spikes; surface `reasonCodes` describing unseen actors.
   • Runtime control: accept `config` commands via stdin to reload pipeline thresholds, detector toggles, and notification settings; respond with acknowledgements and validation errors.
• ML Lifecycle & Diagnostics
   • Create calibration scripts that replay labeled PCAP fixtures, compute precision/recall per detector, and persist tuned thresholds back into the pipeline manifest.
   • Add drift monitors logging score distributions and detector health; trigger `calibrationNeeded` warnings when variance exceeds bounds.
   • Profile processing cost (cProfile) under live capture, emit `processingLatencyMs`, and enforce backpressure if latency exceeds 100 ms batch budget.
   • Extend tests: per-module unit tests, deterministic integration harness covering seasonal variation, correlated spikes, and unseen talkers.
• Swift Experience
   • Expand models (`AdvancedDetectionResult`, `DetectionComponentBreakdown`, `SeasonalityBandPoint`, `AdvancedSeasonalityPayload`, `ChangePointEvent`, `MultivariateScore`, `FeatureContribution`, `NewTalker`, `AlertEvent`, `ConfigurableDetector`) to mirror new JSON schema fields.
   • Timeline overlays: render seasonal bands, change-point markers, and confidence badges; highlight multivariate spikes with stackable annotations.
   • Inspector panels: show contributing metrics ranked by importance, “New Talkers” list with entropy deltas, and narrative sentences synthesizing `reasonCodes` (“Throughput + flows exceeded band; new destination 203.0.113.5 observed.”).
   • Tuning sheet: expose detector toggles, threshold sliders, and preview graphs; persist selections to user defaults and sync with Python via config commands.
   • Alerting: allow analysts to opt into banner/system notifications or webhooks when confidence crosses defined levels; include compact reason summaries.
• Ops & Documentation
   • Enhance `PythonProcessRunner` to support config sync requests, structured logging (model version, config hash, calibration timestamp), and graceful downgrade if a detector fails.
   • Document pipeline manifest format, calibration workflow, troubleshooting steps, and rollback procedure for detector regressions.
• Deliverables
   • ML-enhanced detection that surfaces actionable, explainable spikes with adjustable sensitivity, maintains deterministic behavior, and fits within live-capture latency budgets.
