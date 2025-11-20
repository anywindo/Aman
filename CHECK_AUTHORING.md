# Aman Check Authoring Guide

This guide explains how to add a new macOS security check to Aman’s audit engine (Swift `SystemCheck` subclasses under `Modules/`).

## Quick Checklist
- Create a `SystemCheck` subclass in `Modules/`.
- Populate metadata in the initializer (title, description, remediation, severity, doc link/id, primary category).
- Implement `check()` to set `checkstatus` (`Green`/`Yellow`/`Red`) and `status` (human-readable result). Capture errors in `self.error`.
- Register the check in `Engine/AuditCoordinator.swift` inside the appropriate suite(s).
- Add targeted unit tests under `Tests/` for parser/logic.

## Anatomy of a Check
```swift
final class ExampleCheck: SystemCheck {
    init() {
        super.init(
            name: "Human-friendly title",
            description: "What is being validated.",
            category: "Security", // primary UX category (Security/Network/Accounts/Privacy/etc)
            remediation: "Clear, actionable remediation steps.",
            severity: "Medium",   // Low/Medium/High/Critical/Info
            documentation: "https://docs.example.com",
            mitigation: "Why this matters / rationale.",
            docID: 999            // unique numeric reference
        )
    }

    override func check() {
        do {
            // Perform work (prefer ShellCommandRunner or safe Process usage)
            checkstatus = "Green"
            status = "Everything looks good."
        } catch {
            checkstatus = "Yellow"
            status = "Unable to complete check."
            self.error = error
        }
    }
}
```

### Metadata Notes
- `category`: primary tag shown in UI; additional tags can be appended later (see Registry below).
- `severity`: string is mapped to `AuditFinding.Severity`; keep to `Low/Medium/High/Critical/Info`.
- `docID`: unique numeric id; used for references and mapping to benchmarks (CMMC tags in `AuditCoordinator`).
- `documentation`: URL string; omit or empty string if not applicable.
- `mitigation`: short rationale why the control matters.

### Runtime Behavior
- Checks run off the main thread with a default 15s timeout in `AuditCoordinator`. If your check may exceed this, optimize or break work into smaller calls.
- Always set `status` to a concise, user-facing sentence. If `status` stays nil, timeouts/errors will fill it with generic text.
- Use `checkstatus` for verdict: `Green` (pass), `Yellow` (review/warn), `Red` (action). If you leave it nil, it will be treated as Unknown.
- Capture recoverable failures with `self.error = error` so the UI can surface details.

### Registry & Categorization
- Add the new check to the appropriate suite in `Engine/AuditCoordinator.swift` (`securitySuite`, `accountSuite`, `privacySuite`, `networkingSuite`).
- The registry automatically tags checks with domain categories and CMMC benchmarks via `applyDomainCatalogs` / `applyBenchmarkCatalogs`. If you need extra category tags, call `appendCategories` inside `check()` or pass additional categories in the initializer.

### Shell & System Access
- Prefer `ShellCommandRunner` (testable abstraction) over raw `Process` when possible; it simplifies mocking in tests.
- Avoid privileged operations; if a command requires elevated permissions, guard with clear user messaging and fall back gracefully.
- Normalize command output parsing so tests can cover success, warning, and failure paths.

### Testing
- Add focused unit tests in `Tests/` (see `Tests/NetworkingCheckTests.swift` for patterns). Validate parsing, branching, and status/severity outcomes.
- Use stub executors/mocks instead of running real system commands in tests.

### UX Prompts & Privacy
- Do not initiate network scans or external calls without explicit user consent; intranet-sensitive checks should rely on `NetworkWorkspaceConsentStore` patterns.
- Keep remediation actionable and minimal; avoid vendor-specific steps unless necessary.

## Submitting
- After implementing the check and tests, run the Swift test plan or targeted cases:
  - `xcodebuild test -scheme Aman -testPlan Tests/TestPlan.xctestplan`
- Ensure the new check appears in the OS Security UI list after running the audit and that severity/status align with expectations.
