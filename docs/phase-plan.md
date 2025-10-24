## Aman Expansion Roadmap (2025 Cycle)

### Phase 0 – Baseline Stabilisation ✅
- [x] Restore a lightweight SwiftUI shell (navigation, scan trigger, result list) to keep the app usable during the redesign.
- [x] Confirm the inherited security modules compile and run cleanly post-migration (see `docs/smoke-tests.md`).
- [x] Capture a manual smoke-test checklist for future regression passes.

### Phase 1 – Compliance Engine Enhancements
- Refresh disabled or fragile CIS checks:
  <!-- - [ ] XProtect/MRT/XPR status -- replace the brittle xattr probe with pkg/launchctl signals before re-enabling.
  - [ ] AirPlay receiver -- broaden preference lookups (control center, AirPlay domains, per-host plists) to avoid Ventura/Sonoma false positives.
  - [ ] Time Machine encryption -- harden `tmutil` parsing for multiple destinations, localization, and snapshot-only configs. -->
- Implement new CIS 2024/2025 items:
  - [x] Lockdown Mode audit (Level 2).
  - [x] Continuity/iPhone Mirroring audit (informational or Level 1 depending on CIS guidance).
  - [x] Admin-authenticated settings verification where applicable.
-  [x] Introduce port exposure scanning:
  - Add a non-destructive scanner leveraging `lsof`/`netstat` for listening ports.
  - Map discovered services to risk guidance and remediation steps.
  - Provide “Fix It” quick links (e.g., open Firewall pane, launch sharing preferences, or surface terminal snippets).
- Expand unit-style checks where feasible (lightweight command mocks) to guard against parsing regressions.

Must‑Have Additions (CIS 2024/2025)

Lockdown Mode Status (CIS 14 v2 level 2)
Query each account to ensure the new Lockdown flag is surfaced.
Continuity Feature Audit (CIS 15 draft)
Detect Continuity Camera, iPhone Mirroring, Universal Clipboard state, then flag if disabled/enabled per policy.
Admin‑Gate Controls
Ensure System Settings prompts for admin auth (“Require admin password to access secure settings”).
Rapid Security Response Coverage
Confirm “Install Security Responses and System Files” is enabled and report current RSR version.
Credential Flows
Verify Touch ID / Apple Watch unlock policies align with benchmark guidance.
Legacy Gaps (High Priority)

Time Machine Volume Encryption
Finish the previously disabled TimeMachineVolumesEncryptedCheck.
AirPlay Receiver Status
Reinstate a working AirPlay module so Continuity isn’t left unchecked.
Firmware Protections
Add explicit T2/Secure Enclave validation plus bootstrap verification.
XProtect / MRT / XProtectRemediator
Provide a reliable non-root health check for built-in anti-malware tools.
Temporary Guest Sessions
Track temporarySession guest mode introduced for device enrollment policies.
Networking & Ports

Listening Port Inventory
Implement the requested user-space port scanner with remediation pointers (launchctl URLs, system settings).
Firewall/Stealth Remediation Hints
Surface actionable shortcuts (System Settings deep-links or open URLs).
SSH Hardening
Check for non-default sshd_config that might override our RemoteLoginDisabled status.
Sharing & Continuity

AirDrop Restrictions per interface (Wi-Fi/Everyone/Contacts-only).
Apple TV/AirPlay 2 detections, Screen Sharing fallback.
Bluetooth Sharing granular warnings (file transfer vs audio devices).
Accounts & Access

Password Policy auditing (length, complexity, history) via pwpolicy.
LoginWindow controls (auto-login disabled, banner text, screensaver, etc.).
SecureToken / FileVault key escrow validation (token status per admin users).
Privacy & Analytics

Sensitive log auditing (Unified Logging filters for privacy-critical domains).
App Tracking Transparency enforcement (per-user check).
Diagnostics submission double-check (already present but confirm new defaults after Sonoma/Sequoia).
Update & Compliance Extras

Notarization / Gatekeeper auto-update status.
Software Update deferral windows (for MDM-managed machines).
BridgeOS / iOS companion updates for Continuity.


Software Update deferral windows – Missing: no existing check inspects deferral profiles.
BridgeOS / iOS companion updates – Missing: no code path monitors companion updates.
Sensitive log auditing – Missing: no module filters Unified Logging for privacy domains yet.
Credential Flows – Missing: no current module audits Touch ID or Apple Watch unlock policies.


// NEW not implemented

CMMC Level 2

auth_pam_su_smartcard_enforce – Enforce MFA for the su command
auth_pam_sudo_smartcard_enforce – Enforce MFA for privilege escalation via sudo
auth_smartcard_allow – Allow Smartcard Authentication
auth_smartcard_enforce – Enforce Smartcard Authentication
pwpolicy_alpha_numeric_enforce – Require numeric characters in passwords
pwpolicy_custom_regex_enforce – Require passwords to match custom regex
pwpolicy_simple_sequence_disable – Disallow repeating/ascending/descending sequences
pwpolicy_special_character_enforce – Require special characters in passwords
system_settings_external_intelligence_disable – Disable External Intelligence Integrations
system_settings_external_intelligence_sign_in_disable – Disable External Intelligence Integration Sign In
system_settings_hot_corners_disable – Disable Hot Corners


### Phase 2 – User Experience Modernisation
- Rebuild the SwiftUI interface with:
  - [x] NavigationSplitView-based layout with categories, progress, and detail panes.
  - [x] Real-time progress summaries and severity filters.
  - [x] Toolbar search and sorting controls for the results list.
  - [ ] Results detail cards featuring remediation shortcuts (System Settings deep links, AppleScript, or shell snippets for manual fixes).
- [x] Refresh sidebar summary visuals with the new Aman color palette.
- Add an optional “Quick Fix” modal that aggregates the most urgent remediation steps for user convenience.
- [x] Improve report exports (HTML/JSON) to highlight new checks, ports scanner findings, and fix instructions.

### Phase 3 – Documentation & Maintainability
- Update README and create /docs/ guides covering:
  - Rebrand context (Mergen ➝ Aman) and supported macOS/CIS versions.
  - Usage instructions for the ports scanner and remediation shortcuts.
  - Contribution guidelines for adding future checks.
- Document configuration patterns (per-OS applicability, feature flags) and set up a changelog template.
- Prepare release checklist (version bump, notarisation reminders, manual regression checklist).

### Phase 4 – Quality & Release Preparation (Optional Stretch)
- Automate basic regression runs via CLI scripts (headless scan, export validation).
- Evaluate packaging strategy (signed DMG or distribute via GitHub Releases).
- Collect feedback cycle items for post-release backlog (MDM integration, localisation, scheduling).
