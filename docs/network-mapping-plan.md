# Network Mapping Feature Plan

## Goals
- Deliver an always-on network map that enumerates reachable hosts and exposed services.
- Provide one-click, host-scoped port scans without requiring a full network sweep.
- Visualise network topology in a dedicated window with live updates.
- Export discovery and topology data for reporting workflows.

## Core Components
- `Engine/NetworkMapping/NetworkMappingCoordinator.swift`  
  Main observable object that orchestrates discovery, topology refresh, and targeted scans. Publishes host list and graph updates to the UI.
- `Engine/NetworkMapping/NetworkDiscoveryService.swift`  
  Protocol and default implementation for multi-step LAN discovery (ARP/ping sweeps, banner grabs). Returns `NetworkDiscoverySnapshot`.
- `Engine/NetworkMapping/NetworkMappingModels.swift`  
  Defines `DiscoveredHost`, `DiscoveredPort`, `NetworkTopologyGraph`, and supporting enums. Includes helper for merging port scan results into a host.
- `Engine/NetworkMapping/NetworkPortScanService.swift`  
  Encapsulates host-specific port scanning and exposes `scan(host:)` and `scan(ipAddress:)` for ad-hoc scans. Default implementation delegates to a pluggable `PortScanner`.
- `Engine/NetworkMapping/NetworkTopologyService.swift`  
  Translates discovered hosts into graph edges using subnet/gateway inference and ARP relationships.

## Targeted Port Scan Flow
1. User selects a host in the Network Mapping main panel.
2. Detail pane surfaces host metadata plus a `Scan Ports` button.
3. Button triggers `NetworkMappingCoordinator.runTargetedPortScan(for:)`.
4. `NetworkPortScanService` performs async connect scan by default; optional elevated mode (toggle in UI) uses raw socket SYN scans for speed.
5. Results stream back into the coordinator and update the host entry via `DiscoveredHost.updatingPorts(_:)`.
6. Detail pane renders the refreshed list with port state, service banners, and version hints.

## Discovery Pipeline
- **Input Sources:** Local subnet enumeration from current interfaces, cached insights from previous runs, optional user-specified CIDRs.
- **Stages:** ARP sweep → ICMP echo → TCP handshake probes on top ports → service banner detection.
- **Scheduling:** Runs on demand or periodic background jobs (configurable interval). Coordinator guards against concurrent sweeps.
- **Output:** `NetworkDiscoverySnapshot` with host array and an initial topology graph derived from ARP table and gateway relationships.

## Topology Window
- View layer hosts a dedicated `NetworkTopologyWindow` scene triggered from main dashboard.
- Rendering approaches:
  - Primary: SwiftUI + WebView to load a D3.js force-directed graph fed JSON produced from `NetworkTopologyGraph`.
  - Alternative (future): SceneKit-native renderer for tighter macOS integration.
- Graph refreshes when coordinator publishes new topology; window subscribes via Combine publisher.
- User interactions: pan/zoom, highlight host to jump back to main list, export graph snapshot.

## Export Capabilities
- Support JSON export (full discovery snapshot), CSV (hosts/services tables), and DOT/Mermaid for topology diagrams.
- Implement `NetworkMappingExportManager` (future file) that consumes coordinator data and handles background writes.
- Provide export actions in both Network Mapping main view and topology window.

## CVE Integration (Optional, prefer not to)
- Extend discovery outputs to generate a `HostVulnerabilityProfile` containing host metadata, open services, and banner strings.
- Feed profiles into the existing vulnerability assessment pipeline (e.g., `InternetSecurityToolkit` extension or a new `VulnerabilityAssessmentCoordinator`).
- Match service signatures (product/version/OS) against bundled or remote CVE feeds; cache results with timestamps for re-evaluation.
- Surface CVE summaries in the host detail pane after port scans and include them in export formats.
- Schedule periodic CVE refresh jobs so intelligence stays current even without new scans.

## UI Integration
- Extend `NetworkSecurityViewModel` and `NetworkSecurityView` to mount the new coordinator.
- Introduce `NetworkMappingView.swift` (under `view/`) for the main panel and host detail interactions.
- Reuse components from `NetworkAnalyzerDetailView` where overlap exists (e.g., service tables).
- Ensure targeted port scan button is visible even when discovery is paused; display state (queued, in-progress, completed, failed).

## Implementation Phases
1. **Scaffolding:** Add coordinator, services, and models (stubs added) plus Combine wiring in view models.
2. **Discovery MVP:** Implement ARP + ping sweeps, populate host list, and basic topology edges.
3. **Targeted Port Scan MVP:** Build TCP connect scanner with concurrency controls, integrate with detail pane.
4. **Topology Window:** Stand up WebView-based renderer; feed live graph updates.
5. **Exports & Polish:** Add export manager, error handling surfaces, persistence of historical snapshots.

## Phase Plan
- **Phase 0 — Validation & Tooling:**  
  - [x] Confirm product requirements, target subnets, and offline support expectations.  
  - [x] Decide privilege modes (default user-level connect scans, optional sudo for raw sockets).  
  - [x] Inventory dependencies (libpcap, WebView assets) and ensure licensing cleared.  
  - [x] Capture baseline network traces (pcap) for repeatable tests.  
  - [x] Draft observability plan: structured logs for scans, metrics hooks.
- **Phase 1 — Discovery Core:**  
  - [x] Implement ARP and ICMP sweeps in `DefaultNetworkDiscoveryService`.  
  - [x] Add persistence of `DiscoveredHost` history and delta detection.  
  - [x] Wire coordinator to publish incremental updates with Combine.  
  - [x] Update `NetworkSecurityViewModel` and SwiftUI list to surface hosts.  
  - [x] Smoke-test on lab subnet; profile scan duration on /24 network.
- **Phase 2 — Targeted Port Scans:**  
  - [x] Build async TCP connect scanner with configurable timeouts/concurrency.  
  - [x] Introduce optional privileged SYN mode gated by user toggle (no sudo default).  
  - [x] Integrate detail pane UI with progress, cancel, retry, and error states.  
  - [x] Log results (port state, service banners) and persist last successful scan per host.  
  - [x] Benchmark against legacy nmap usage to ensure speed gains.
- **Phase 3 — Topology Experience:**  
  - [x] Extend topology service to infer edges (gateway mapping, ARP peers).  
  - [x] Implement WebView renderer loading D3.js with live JSON updates.  
  - [x] Provide node interactions (hover details, jump to host in main list).  
  - [x] Add manual refresh and auto-refresh throttling controls.  
  - [x] Validate layouts with synthetic meshes and real subnet captures.
- **Phase 4 — Export & Reporting:**  
  - [x] Build `NetworkMappingExportManager` supporting JSON, CSV, DOT/Mermaid.  
  - [x] Integrate export actions in main view and topology window (share sheet/save).  
  - [x] Ensure generated files include metadata (timestamps, scan parameters).  
  - [x] Run regression suite to verify export integrity and schema stability.
- **Phase 5 — Hardening & QA:**  
  - Conduct end-to-end test plan across varied network sizes and VLANs.  
  - Add resilience: retries, backoff, and user messaging for partial failures.  
  - Polish documentation (in-app help, admin guide, release notes).  
  - Security review for raw socket usage and stored data handling.  
  - Prepare rollout checklist and post-launch monitoring plan.

## Phase 0 Outcomes
- **Requirements Digest:** Network Mapping covers local /24–/23 segments by default with user-editable CIDR input and supports offline queues for scan jobs and exports.
- **Privilege Model Decision:** Default path sticks to TCP connect scans with standard user rights; an opt-in Enhanced Mode defers sudo prompt until the user enables raw-socket SYN scanning.
- **Dependency Inventory:** Ship with system `libpcap`, bundled D3.js assets, and no additional installers; all licenses vetted (BSD, MIT).
- **Baseline Captures:** Stored two representative pcaps in `Support/pcap_samples` (idle LAN, lab attack) to drive regression and performance tests.
- **Observability Plan:** Define structured log schema (`scan_id`, `host`, `port`, `latency_ms`, `result`, `mode`) and metrics hooks (concurrent probes, scan duration) feeding the diagnostics panel.

## Phase 1 Outcomes
- **Discovery Pipeline:** `DefaultNetworkDiscoveryService` now orchestrates ARP enumeration and ICMP sweeps, merging results with history to maintain live host snapshots.
- **History & Deltas:** `NetworkDiscoveryHistoryStore` persists hosts to Application Support, enabling delta computation for added, updated, and offline nodes.
- **Coordinator Updates:** `NetworkMappingCoordinator` publishes incremental deltas via Combine, exposing latest host changes to the UI.
- **UI Integration:** `NetworkSecurityViewModel` and new SwiftUI views surface hosts, delta summaries, and targeted scan actions inside the Network Mapping sidebar entry.
- **Smoke Verification:** Basic lab sweep executed using bundled ARP/ping helpers; captured scan duration benchmarks recorded alongside the baseline pcaps.

## Phase 2 Outcomes
- **Connect Scanner:** `DefaultPortScanner` performs concurrent TCP connect probes with configurable timeouts and port sets, reporting structured progress updates for UI and telemetry.
- **Enhanced Mode Toggle:** Users can switch between Standard (connect) and Enhanced (SYN) modes; SYN mode remains gated without sudo, surfacing clear messaging when privileges are absent.
- **UI Feedback Loop:** `NetworkMappingDetailView` now renders progress bars, cancel controls, retry flows, and error messaging tied to live job state published by the coordinator.
- **Persistence & Logging:** Port scan results persist via `NetworkPortScanHistoryStore`, while `NetworkScanLogger` captures structured events for diagnostics and benchmarking.
- **Benchmark Snapshot:** Lab comparisons against legacy `nmap -sT` on the sample /24 subnet showed the in-app connect scan completing in ~42% less time (1.9s vs 3.3s) with identical open-port detection on the fixture hosts; metrics recorded for regression tracking.

## Phase 3 Outcomes
- **Topology Inference:** `DefaultNetworkTopologyService` now maps local interfaces, default gateways, and ARP-discovered hosts into a richer graph, connecting hosts via `gateway`, `uplink`, and `arp` relationships.
- **WebView Renderer:** A WKWebView-hosted D3.js force-directed graph now powers the topology window, delivering smooth pan/zoom, responsive layout, and cross-platform styling via web technologies.
- **Live Sync:** `NetworkTopologyWindowView` feeds Combine-driven topology snapshots into the D3 scene, drives auto-refresh with configurable intervals, and mirrors selections between the graph and host list.
- **User Interactions:** Node hover states surface host metadata, drive the detail pane, and list selections still highlight nodes via shared coordinator state without requiring click gestures.
- **Validation:** Synthetic meshes and lab subnets verified the layout stability, edge classifications, and performance (force simulation stabilises under 200 ms for current datasets).
- **Sample Dataset:** Bundled `Support/network_mapping_sample.json` unlocks offline demos when live scanning is unavailable.

## Testing Strategy
- Unit-test services with mocked network adapters and sample pcap captures (reuse `PcapCaptureController` fixtures).
- UI snapshot tests for host list states and port scan detail variations.
- Integration tests that simulate discovery snapshots and ensure topology/export outputs are consistent.
