# Aman: macOS Network & Security Auditor

![Landing Page](Assets/LandingPage.png)

## Overview

Aman is a macOS Network & Security Auditor that merges a Swift-based audit engine with a Python-driven analytics layer. It performs system integrity checks, network exposure assessments, and behavior-based anomaly detection — all locally on-device. The auditor’s dual-layer design ensures detailed results without compromising privacy, making it a comprehensive tool for self-contained macOS security evaluation.

## Core Features

Aman combines structural system auditing with live network intelligence. It checks and validates configuration settings across **FileVault**, **SIP**, **Lockdown Mode**, **Gatekeeper**, and numerous other controls derived from CIS Benchmarks. The outcome of every scan is categorized under *Pass*, *Review*, or *Action*, accompanied by contextual explanations and one-click remediation references.

Beyond system auditing, Aman includes a real-time network module. It maps interfaces, discovers connected devices, and identifies exposed services through lightweight local probing. Network scans, topology exports, and consent-based intranet analysis form the backbone of its diagnostic capability. All actions operate under explicit user approval, ensuring compliance with privacy standards.

### Integrated Components

* **Configuration Auditing** - Performs comprehensive macOS configuration analysis, detecting deviations from security best practices.
* **Network Mapping** - Scans local interfaces, collects connection data, and generates visualized network topology exports.
* **Certificate and Hash Tools** - Built-in SSL certificate lookup and hash generator utilities powered by CryptoSwift.
* **Remediation Catalog** - Provides step-by-step mitigation guidance tied directly to detected issues.

## Advanced Detection Framework

![Network Security consent page](Assets/NetworkSecurity.png)

Aman’s advanced detection engine, located in `Support/analyzer_core`, operates as a modular pipeline defined by `analyzer_pipeline.yaml`. This framework combines multiple detection models into a sequential process, each contributing specialized insights to a shared context.

### Detection Phases

1. **Legacy Stage** – Baseline heuristic evaluation using rule-based filters.
2. **Seasonality Detector** – Analyzes traffic patterns over time to determine normal periodic behavior.
3. **Change-Point Detector** – Identifies abrupt statistical shifts in network flow or packet rate distributions.
4. **Multivariate Detector** – Correlates data across multiple dimensions (throughput, latency, packet entropy) to detect composite deviations.
5. **New-Talker Detector** – Recognizes first-seen hosts or services, measuring entropy deltas and novelty within recent activity.

Each stage writes diagnostic data — scores, reasons, and statistical metrics — into a shared memory context, forming a cohesive analytical model. This produces an aggregated structure labeled `advancedDetection`. By applying rolling windows and vectorized operations, Aman achieves efficiency suitable for continuous on-device operation.

```mermaid
graph TD
    A[Raw Analyzer Request] --> B[Legacy Stage]
    B --> C[Seasonality Detector]
    C --> D[Change-Point Detector]
    D --> E[Multivariate Detector]
    E --> F[New-Talker Detector]
    F --> G[Advanced Detection Output]

    subgraph Context
        H[Shared Context]
        I[Scores]
        J[Reasons]
        K[Diagnostics]
    end

    B --> H
    C --> H
    D --> H
    E --> H
    F --> H
    H --> G

    subgraph Runtime
        L[Manifest]
        M[Parameters]
        N[Controls]
    end

    L --> B
    L --> C
    L --> D
    L --> E
    L --> F

    subgraph Output
        O[Seasonality Bands]
        P[Change-Points]
        Q[Multivariate Weights]
        R[Entropy Deltas]
        S[Alerts]
    end

    G --> O
    G --> P
    G --> Q
    G --> R
    G --> S
```


## OS Security Check Modules

![OS Security](Assets/OSSecurity.png)

**System Integrity and Firmware**

* `EfiCheck.swift` – verifies EFI firmware integrity and bootloader validation
* `FirmwareSecurityCheck.swift` – audits Secure Enclave and T2 firmware protections
* `SIPCheck.swift` – confirms System Integrity Protection status
* `FileVaultCheck.swift` – checks full-disk encryption and SecureToken compliance
* `SecureTokenStatusCheck.swift` – inspects user-level token bindings for FileVault access

**Access Control and Authentication**

* `AdminPasswordForSecureSettingsCheck.swift` – enforces admin credentials for secure settings
* `LoginWindowPolicyCheck.swift` – validates login behavior (auto-login disabled, banner text)
* `PasswordPolicyCheck.swift` / `PasswordPolicyInspector.swift` – parses and evaluates local password policies
* `PasswordAlphanumericRequirementCheck.swift`, `PasswordSpecialCharacterRequirementCheck.swift`, `PasswordSimpleSequenceRestrictionCheck.swift`, `PasswordCustomRegexRequirementCheck.swift` – enforce password complexity and format rules
* `PasswordOnWakeCheck.swift` – ensures authentication is required after sleep
* `PamSuSmartcardEnforceCheck.swift`, `PamSudoSmartcardEnforceCheck.swift`, `SmartcardAllowCheck.swift`, `SmartcardEnforcementCheck.swift` – enforce smartcard authentication and MFA policies

**Network and Remote Access**

* `FirewallCheck.swift` / `FirewallStealthModeCheck.swift` – confirm firewall enablement and stealth mode
* `RemoteLoginDisabledCheck.swift` / `RemoteManagementCheck.swift` – disable or restrict SSH and ARD access
* `InternetSharingDisabledCheck.swift` / `FileSharingCheck.swift` / `PrinterSharingDisabledCheck.swift` – restrict network sharing services
* `WakeForNetworkAccessCheck.swift` – ensures wake-on-LAN is managed securely
* `PortListeningInventoryCheck.swift` / `PortScannerCheck.swift` – enumerates open network ports and associated services
* `IntranetSecurityPortScanCheck.swift` – internal port scanning audit for local network

**Software Update and Patch Management**

* `AppleSoftwareUpdateCheck.swift` / `AutomaticSoftwareUpdateCheck.swift` – confirm automatic updates and Apple security patching
* `CriticalUpdateInstallCheck.swift` / `SecurityUpdateCheck.swift` – validate mandatory update installation
* `RapidSecurityResponseCheck.swift` – checks macOS RSR (Rapid Security Response) version and enablement
* `SoftwareUpdateDeferralCheck.swift` / `BridgeOSCompanionUpdateCheck.swift` – monitor deferral policies and device companion updates

**System and Service Configuration**

* `GatekeeperAutoUpdateCheck.swift` / `GatekeeperBypassCheck.swift` – verify Gatekeeper enforcement and auto-update status
* `AppSandboxCheck.swift` – confirms sandbox compliance for installed apps
* `AppStoreUpdateCheck.swift` – validates automatic App Store update settings
* `ContinuityFeaturesCheck.swift` / `UniversalControlCheck.swift` – audits Continuity, Handoff, and Universal Control policies
* `LockdownModeCheck.swift` – validates Lockdown Mode status for high-security environments
* `LoginWindowPolicyCheck.swift` – enforces login security configuration

**Privacy and Telemetry**

* `DiagnosticDataCheck.swift` / `SensitiveLogAuditingCheck.swift` – reviews analytics and diagnostic submission policies
* `AppTrackingTransparencyCheck.swift` / `PersonalizedAds.swift` – ensures app tracking and ad personalization compliance
* `ExternalIntelligenceDisableCheck.swift` / `ExternalIntelligenceSignInDisableCheck.swift` – disables external intelligence integrations (e.g., Siri, AI sign-ins)
* `SiriStatusCheck.swift` – confirms Siri status per privacy policy

**Media and Peripheral Control**

* `AirDropDisabledCheck.swift` / `AirDropInterfacePolicyCheck.swift` – restricts AirDrop interfaces and visibility
* `AirPlayReceiverDisabledCheck.swift` / `AirPlayServiceCheck.swift` – controls AirPlay receiver/service activation
* `BluetoothMenuIconVisibleCheck.swift` / `BluetoothSharingDisabledCheck.swift` / `BluetoothSharingGranularCheck.swift` – manages Bluetooth sharing and icon policies
* `DVDOrCDSharingDisabledCheck.swift` – ensures removable media sharing is disabled
* `BonjourCheck.swift` – checks Bonjour advertising and discovery exposure

**Backup, Time, and Miscellaneous**

* `BackupAutomaticallyEnabledCheck.swift` / `CheckTimeMachineEnabled.swift` / `TimeMachineVolumesEncryptedCheck.swift` – ensure encrypted and automated backups
* `SetTimeAndDateAutomaticallyEnabledCheck.swift` / `TimeWithinLimitsCheck.swift` – confirm time sync and clock integrity
* `ContentCachingDisabledCheck.swift` / `ApacheHTTPCheck.swift` / `NfsServerCheck.swift` – ensure unneeded local services are disabled
* `HotCornersDisabledCheck.swift` – disables unsecure screen activation corners
* `ScreenSaverIntervalCheck.swift` / `ScreenSharingDisabledCheck.swift` – enforces screen lock and sharing policies
* `GuestLoginCheck.swift` / `GuestConnectCheck.swift` / `TemporaryGuestSessionCheck.swift` – manages guest account and session restrictions

**Malware and Threat Protection**

* `XProtectStatusCheck.swift` / `XProtectAndMRTCheck.swift` – ensures built-in malware defenses (XProtect, MRT) are active
* `SafariInternetPluginCheck.swift` / `SafariSafeFileChecks.swift` – checks Safari plugin safety and secure download behavior


## Architecture Overview

The Swift layer coordinates the entire workflow through key controllers such as `AuditCoordinator`, `NetworkMappingCoordinator`, and `PythonProcessRunner`. These components synchronize the macOS-side checks with the embedded Python analyzer, ensuring efficient communication between UI, logic, and analytics. The interface follows SwiftUI’s `NavigationSplitView` architecture, dividing the window into category navigation, audit results, and detailed remediation panels. Reports can be exported in both JSON and HTML formats for portability.


## Build and Execution

Aman supports macOS Tahoe (26) or newer, requiring Xcode 16 and Python 3.9. After cloning the repository:

```bash
git clone https://github.com/anywindo/Aman.git
open Aman.xcodeproj
```

Build and run within Xcode or launch analyzer tests manually:

```bash
cd Support
python3 -m unittest discover -v
```

## License

Aman Network & Security Auditor is distributed under the MIT License. See the LICENSE file for details.

## Citation

```
@software{Aman2025,
  title  = {Aman: macOS Network & Security Auditor},
  author = {Pratama, Arwindo Sendy and contributors},
  year   = {2025},
  url    = {https://github.com/anywindo/Aman}
}
```
