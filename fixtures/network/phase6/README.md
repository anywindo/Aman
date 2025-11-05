# Phase 6 Fixtures

This directory stores deterministic PCAP slices and expected outputs for the Phase 6 analyzer pipeline.

- `baseline/` will include captures used to verify seasonality and change-point behaviour.
- `multivariate/` will capture correlated metric spikes for ensemble scoring.
- `new_talkers/` will contain synthetic flows introducing unseen tags for entropy validation.

The Phase 6.1 implementation only seeds the structure; fixtures land as the detectors mature.
