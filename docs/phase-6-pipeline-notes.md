# Phase 6.6 Pipeline Notes

- **Manifest location** `Support/analyzer_pipeline.yaml` drives detector ordering. JSON syntax keeps it YAML-compatible without external dependencies.
- **Detector contract** each stage accepts the raw analyzer request and returns partial results that merge into the final payload. Shared context tracks component scores, reason codes, and detector diagnostics.
- **Advanced detection envelope** the pipeline emits `advancedDetection` with phase marker `phase6.6`, bundling seasonality payloads, change-point events, multivariate scores, new talker summaries, and alert events with configuration echoing.
- **Runtime pathing** the Python entry point resolves paths relative to `Support/` so packaged resources remain self-contained inside the app bundle.
- **Seasonality detector** runs after the legacy stage, derives dominant periods, and publishes baseline bands plus diagnostics for bytes/packets/flows.
- **Change-point detector** evaluates paired rolling windows to flag mean shifts, returning `changePoints` arrays and diagnostics (window, threshold, detected count) that feed UI overlays.
- **Multivariate detector** scores joint throughput deviations using rolling z-vectors, emitting contribution weights per feature for UI explanations.
- **New talker detector** keeps a sliding window of tag totals, reporting first-seen actors plus entropy deltas to explain emerging entities.
- **Controls & alerting** request payloads can disable detectors, override parameters, and configure alert thresholds/destinations; the pipeline returns `alerts.events` whenever component scores exceed configured thresholds.
- **Testing hooks** unit tests validate manifest wiring, detector fallbacks, and seasonality/change/multivariate/new-talker generation alongside alert firing; `fixtures/network/phase6` continues to host deterministic captures for advanced detectors.
