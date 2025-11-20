# Aman User Pipeline

This guide summarizes how a typical user moves through Aman to audit macOS security, explore network exposure, and export results.

## 1) Launch & Navigation
- Open Aman (macOS 26+/Xcode-built app). The landing selector offers OS Security, Network Security, Network Topology, and About.
- Windows can be reopened via Window menu or toolbar buttons.

## 2) Run OS Security Audit
- Open **OS Security**. Click **Run Audit** to execute all checks (EFI/FileVault/SIP, Gatekeeper, updates, sharing, Bluetooth/AirDrop/AirPlay, password/Smartcard, etc.).
- Findings appear in the list; use search, filters by domain, sort (Status/Severity/Name), and select a row to view details, rationale, remediation, and references.
- Export results via the HTML export button; choose a destination in the save panel.

## 3) Network Security Suite
- Open **Network Security**. The sidebar provides:
  - **Toolkit**: Run all or individual internet checks (DNS leak, IP exposure, IPv6 leak, firewall, proxy/VPN). Results include status, details, and notes.
  - **Certificate Lookup**: Query crt.sh transparency logs (requires internet) for a domain; inspect issuance timelines.
  - **Hash Generator**: Hash files or text with SHA, BLAKE3, Whirlpool, etc.; copy digests.
  - **Network Analyzer**: Ingest packet/metric samples (consent-driven) and surface anomaly findings from the Python pipeline.
  - **Network Mapping**: Discover hosts, run targeted port scans (connect/SYN), view services.
  - **Network Profile**: Snapshot of local/public IP, gateway, DNS, VPN/proxy indicators.
- Consent: certain features (packet analysis, intranet scans, mapping) prompt for workspace consent before running.

## 4) Network Mapping & Topology
- Start discovery to enumerate hosts and services; view deltas as devices appear or disappear.
- Run targeted port scans from hosts; monitor progress, errors, and history. SYN mode may require elevated privileges.
- Open the **Network Topology** window to visualize connections; refresh topology or load the bundled sample dataset for demo purposes.
- Export mapping/topology via the export action (JSON/graph formats depending on manager).

## 5) Analyzer (ML) Flow
- Network Analyzer sends captured metrics/packets to the Python pipeline (`analyzer.py`) for legacy, seasonality, changepoint, multivariate, and new-talker analysis.
- Results are reflected in advanced detection views (scores, reason codes, diagnostics). Alerts surface when scores exceed thresholds.

## 6) Reporting & Troubleshooting
- OS audit: use HTML export; remediation guidance is shown per finding.
- Analyzer issues: errors/decoding problems are saved to `~/Library/Logs/Aman/analyzer-last.json`.
- If Python 3 is missing, the app prompts; install or ensure `/usr/bin/python3` is available.
- Network features: ensure user grants network permissions; crt.sh lookups require internet.
