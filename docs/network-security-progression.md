## Network Security Feature Checkup – Progression Plan

### Focus Shift
- [x] Freeze new OS Security feature work; maintain critical fixes only.
- [x] Spin up dedicated Network Security window alongside the existing OS Security window.
- [x] Add a landing selector that routes users to either `OS Security` or `Network Security`.

### UX & Navigation Baseline
- [x] Build a dashboard-style Network Security shell (toolbar status, summary tiles, findings list).
- [x] Establish shared view models for scan orchestration (reuse where possible, isolate network-specific logic).
- [x] Validate window management (two independent SwiftUI windows + landing chooser).

### Stage 1 – Guardrails & Consent (Gatekeeper Stage)
- [x] Display legal/ethical consent dialog before any network probing.
- [x] Implement configurable rate limiting + “Test mode” that simulates scans without packets on the wire.
- [x] Log every initiated scan with timestamp, initiator identity, scope, and mode.
- [x] Enforce authorized target list (CIDR/IP allowlist, manual confirmation dialog).

### Stage 2 – Network Scanner (Initial Focus)
- [x] Nmap integration (`-sS -sV -O --script=banner`) with safe defaults (respecting stage 1 guardrails).
- [x] Parse results into structured models (host ➝ services ➝ banners ➝ OS fingerprint).
- [x] Render live progress and results in the dashboard (hosts list, open ports, service versions).
- [x] Capture scan artifacts to disk for later reporting.
- [x] Provide remediation hints per finding (basic severity, recommended actions).

### Stage 3 – Network & Privacy Toolkit
- [x] DNS leak detection (compare resolver IPs vs VPN expectations).
- [x] IP/GeoIP exposure check (external IP lookup, geolocation diff).
- [x] IPv6 leak test (detect IPv6 routes when VPN tunnel is IPv4-only).
- [x] Firewall audit (open listening ports, stealth mode status).
- [ ] WebRTC leak detection (browser-facing check flow).
- [x] Proxy/VPN configuration validation (system proxies, tun/tap interfaces).
- [x] Integrate toolkit cards into the dashboard with “Run test” controls and status badges.

### Stage 4 – Intranet Security & CVE Mapping
- [x] Discovery: implement ARP sweep, ICMP ping, mDNS, and NetBIOS enumeration (opt-in modules).
- [x] Scan orchestration: execute `nmap -sS -sV -O --script=banner` with per-host throttling.
- [x] Fingerprinting: extract product/version from banners & nmap fingerprints.
- [x] CVE mapping: query NVD/OSV/Vulners (respect API quotas, cache responses).
- [x] Replace legacy plaintext parser with nmap XML (`-oX -`) processing to surface vulners results reliably in the CVE Scan UI.
- [x] Split intranet scanner into a fast service sweep and optional CVE enrichment pass so the UI stays responsive even when deep scans are slow.
- [x] Safe verification: restrict NSE scripts to non-intrusive sets; document defaults.
- [x] Risk scoring: combine CVSS base score + exposure context + exploit maturity signals.
- [x] Reporting: generate structured CVE summaries with remediation guidance (log + in-app summary; JSON export TBD).

### Stage 5 – Platform Integration & Polish
- [ ] Hook scan orchestration into existing Engine modules (background tasks, notifications).
- [ ] Add scheduling and history timeline (per scan type).
- [ ] Surface top risks on landing page (quick glance cards).
- [ ] Ensure theming aligns with existing Aman palette and accessibility standards.

### Technical & Compliance Notes
- Explore Swift + Rust (or Go) interop for heavy scanners; keep SwiftUI front-end responsive.
- Cache GeoIP/ASN metadata locally to minimize repeated network lookups.
- Centralize configuration (`Engine/Config/NetworkSecurity.plist` or similar) for tuning scan limits.
- Update documentation (`docs/`) once Stage 2 ships; add user guide covering consent and safe usage.
- Plan automated smoke tests for scanner pipelines (mock nmap output, API fixtures).
