# Aman UI Redesign (macOS 26 Style)

## Goals
- Adopt the modern macOS split-view pattern so scanning, browsing, and remediation happen without leaving the main window.
- Keep the interface operational during future feature work (ports scanner, quick fixes) by modularizing panes.
- Provide clear progression from audit launch → categorised results → detailed remediation guidance.

## Architecture Overview

```
NavigationSplitView
├─ AuditSidebarView              // audit controls, category filter, live summary
├─ FindingListView          // filtered vulnerability list with status chips
└─ FindingDetailView  // rich detail pane with remediation + links
```

### Sidebar
- Quick actions: **Start Audit**, **Clear Results**, toolbar refresh shortcut.
- Category picker driven by `AuditDomain` enum (`All`, `CIS Benchmark`, `Privacy`, `Security`).
- Live summary section: pass/review/action counts or a progress bar during an active audit.

### Results Column
- Uses `List(selection:)` to integrate with the system split-view navigation style.
- Status badges with SF Symbols and color-coded capsules (Pass/Review/Action).
- Empty-state presentation (`ContentUnavailableView`) guiding first-time users to run an audit.

### Detail Pane
- Rich header with severity, status, category chip, and document ID.
- Sections for current status, recommended actions, rationale, and documentation links.
- Placeholder component when no item is selected or an audit is running.

## Interaction Flow
1. Tap **Start Audit** (sidebar or toolbar).
2. Progress bar appears; results populate in the middle column.
3. Selecting a row reveals remediation detail and documentation in the inspector.
4. Users can export the current run via the sidebar’s **Export HTML** control, which produces a portable table-based report.

## Implementation Notes
- `ContentView` orchestrates state (`AuditCoordinator`, category selection, detail selection) and wires dependencies into each pane.
- Dedicated SwiftUI views live under `Aman/view/` to keep the layout componentized.
- `AuditDomain` enum centralizes iconography and display text for category filters.
- JSON export uses an ISO8601 timestamp (colon-stripped) to produce filename-safe artefacts.

## Next Steps
- Integrate quick-fix shortcuts (System Settings deep links / scripts) into `FindingDetailView`.
- Surface HTML export in the toolbar to complement JSON.
- Add accessibility audits (VoiceOver-friendly labels + focus order) once the redesign stabilizes.
