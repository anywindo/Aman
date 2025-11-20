# Aman Project Blueprint

## Purpose
- macOS SwiftUI app that runs local audits across OS security posture, network exposure, and utility workflows (hashing, cert lookup, topology exploration). Python analytics backs the network anomaly detector; everything executes on-device.

## Repository Layout
- `AmanApp.swift`, `ContentView.swift`: SwiftUI entry points and window routing.
- `view/`: UI for OS audit results, network security, mapping, analyzer, certificate/hash utilities, consent flows, landing/about screens.
- `Engine/`: Core logic (audit engine, network mapping, internet toolkit, python bridge, utilities, dependencies).
- `Modules/`: Concrete `SystemCheck` subclasses implementing individual OS/CIS/security checks.
- `Support/`: Python analyzer pipeline (`analyzer.py`, `analyzer_core/`), manifest (`analyzer_pipeline.yaml`), bridging header, tests.
- `Tests/`: Swift unit tests (e.g., networking check parsing).
- `Assets/`, `Aman.icon/`: App images and icon definition.
- `Aman.xcodeproj`, `*.xcworkspace`: Xcode project files.

## Application Architecture
- **SwiftUI Shell**: `AmanApp` opens windows for landing selection, OS Security, Network Security, Network Topology, and About. `ContentView` hosts OS security auditing with searchable/sortable findings and HTML export.
- **Data Flow**: UI binds to ObservableObject view models (`AuditCoordinator`, `NetworkSecurityViewModel`, `NetworkMappingCoordinator`, etc.) that orchestrate async tasks. Findings are represented by immutable `AuditFinding` models built from mutable checks.

### Audit Engine (Swift)
- **Check Model**: `SystemCheck` (Engine/SystemCheck.swift) defines per-check metadata (title, remediation, severity, references) and mutable status fields. `AuditFinding` wraps results with normalized verdict/severity labels.
- **Coordinator**: `AuditCoordinator` registers all checks, applies category/benchmark tags, enforces a timeout (default 15s), and streams progress/findings to the UI. `AuditExecutor` runs checks on a background queue with timeout handling.
- **Registry Coverage**: Checks are grouped under Security, Accounts, Privacy, and Network domains with CMMC benchmark tags where applicable.
- **Output/Export**: `ContentView` can export current findings to HTML with category, verdict, severity, status, and remediation columns.

### OS Security Modules (Modules/)
- ~70 Swift checks covering EFI/FileVault/SIP, Gatekeeper, SecureToken, password complexity, smartcard enforcement, login/window policies, software updates, Rapid Security Response, firewall/stealth, remote access (SSH/ARD/screen/file/printer sharing), internet sharing/content caching/NFS/Apache, Bluetooth/AirDrop/AirPlay, Location/Diagnostics/Ads/App Tracking, Lockdown Mode/Continuity/Universal Control, Time Machine/time sync, hot corners/screensaver, guest access, and XProtect/MRT/Safari safety.
- Each subclass sets `checkstatus` (Green/Yellow/Red) and `status` description; many call out remediation links and doc IDs for mapping to benchmarks.

### Internet Security Toolkit & Utilities
- **Toolkit**: `InternetSecurityToolkit` runs DNS leak, IP/GeoIP exposure, IPv6 leak, firewall posture, and proxy/VPN checks using shell commands and lightweight HTTP queries (via `URLSession` and `SystemConfiguration`). Results are surfaced as `InternetSecurityCheckResult` objects with per-check details/notes.
- **NetworkSecurityViewModel**: Orchestrates toolkit execution, per-check concurrency, progress state, and hooks into network mapping for host/port actions.
- **Utilities**: Certificate lookup via crt.sh client (`Engine/Utilities/CRTShClient.swift`), hash generator powered by CryptoSwift plus custom Whirlpool and BLAKE3 implementations, endian helpers, duplex utilities, and command execution abstraction (`ShellCommandRunner`).

### Network Mapping & Port Scanning
- **Coordinator**: `NetworkMappingCoordinator` centralizes discovery, topology generation, consent, port scanning, history, and export. Publishes hosts, topology graphs, deltas, job states, and export status.
- **Services**: `NetworkDiscoveryService`, `NetworkTopologyService`, `NetworkPortScanService`, `NetworkWorkspaceConsentStore`, with history logging (`NetworkPortScanHistoryStore`) and export handling (`NetworkMappingExportManager`) to JSON/graph formats. Supports sample dataset loading and targeted scans with connect/SYN modes (privilege-gated).
- **Models**: `DiscoveredHost`, `DiscoveredPort`, `NetworkTopologyGraph`, `PortScanJobState`, and related data structs in `Engine/NetworkMapping`.

### Intranet & Network Analyzer
- **Intranet Security**: `IntranetSecurityScanner` and `IntranetSecurityPortScanCheck` perform consent-gated internal port scans leveraging `NetworkWorkspaceConsentStore`.
- **Python Bridge**: `PythonProcessRunner` runs `Support/analyzer.py` (with PYTHONPATH primed to `Support/`) and decodes JSON results; errors are surfaced to the UI and mirrored to `~/Library/Logs/Aman/analyzer-last.json` on decode failure.
- **Analyzer Pipeline**: Defined by `Support/analyzer_pipeline.yaml`. Stages: `legacy` heuristic detector, `seasonality` baseline banding, `changepoint` detection, `multivariate` correlation, and `newtalker` detection. `analyzer_core/pipeline.py` loads manifest, executes enabled detectors sequentially, merges partial outputs, builds `advancedDetection` (scores, reason codes, diagnostics), and raises alerts when component scores cross configured thresholds.
- **Detectors**: Implemented in `Support/analyzer_core/detectors/*.py` with reusable base abstractions and vectorized operations for traffic metrics.

### UI Layer (view/)
- **OS Audit**: `AuditSidebarView`, `FindingListView`, `FindingDetailView`, `LandingView`, and placeholders manage navigation, statuses, and remediation content.
- **Network Security**: `NetworkSecurityView` hosts sidebar for internet toolkit, certificate lookup, hash generator, network analyzer, mapping, and profile cards. Dedicated detail views (`NetworkAnalyzerView`, `NetworkMappingView`, `NetworkProfileView`, etc.) handle rendering and consent prompts.
- **Topology Window**: `NetworkTopologyWindowView` renders graphs and reacts to coordinator selection/highlighting. Export and sample-data flows are surfaced via view models and sheets.
- **Misc**: About dialog, TTL cache, enrichment services, packet lists, and preferences sheet for analyzer behavior.

## Support Assets
- Branding images in `Assets/` for landing/about views; vector icon set in `Aman.icon/`.
- Bridge header `Support/Aman-Bridging-Header.h` for any Objective-C/C interop (crypto C implementations).

## Build & Run
- Requirements: macOS Tahoe (26) or newer, Xcode 16, Python 3.9+, local CRT.sh reachability for certificate lookup, and network permission for toolkit/analyzer features.
- Build: `open Aman.xcodeproj` in Xcode; run the Aman target. SwiftUI previews rely on macOS 14+.
- Python analyzer tests/manual run:
  - `cd Support`
  - `python3 -m unittest discover -v`
  - `python3 analyzer.py < request.json` (stdin JSON) to exercise the pipeline.
- Swift tests: run the `Tests/TestPlan.xctestplan` in Xcode or `xcodebuild test -scheme Aman -testPlan Tests/TestPlan.xctestplan`.

## Operational Notes
- Security checks default to 15s timeout; timeouts are reported as Yellow with descriptive messages.
- Port scan SYN mode requires elevated privileges; failures are captured in `PortScanJobState`.
- Network analyzer and internet toolkit actions are consent-driven; UI stores consent via `NetworkWorkspaceConsentStore`.
- HTML exports for audit findings are generated from `ContentView` and saved via `NSSavePanel`.
