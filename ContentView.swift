// 
//  [ContentView].swift 
//  Aman - [Aman] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import SwiftUI
import AppKit
import UniformTypeIdentifiers

private enum SortKey: String, CaseIterable, Identifiable {
    case verdict
    case severity
    case title

    var id: String { rawValue }

    var label: String {
        switch self {
        case .verdict: return "Status"
        case .severity: return "Severity"
        case .title: return "Name"
        }
    }
}

struct ContentView: View {
    @StateObject private var coordinator = AuditCoordinator()
    @State private var selectedDomain: AuditDomain = .all
    @State private var selection: UUID?
    @State private var searchText: String = ""
    @State private var sortKey: SortKey = .verdict
    @State private var ascending: Bool = true

    @State private var pendingAutoSelection = false

    private var displayedFindings: [AuditFinding] {
        let base: [AuditFinding]
        if selectedDomain == .all {
            base = coordinator.findings
        } else {
            base = coordinator.findings.filter { $0.categories.contains(selectedDomain.title) }
        }

        let searched = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        let filtered: [AuditFinding]
        if searched.isEmpty {
            filtered = base
        } else {
            filtered = base.filter { finding in
                let haystack = """
                \(finding.title) \(finding.categoryDisplay) \(finding.synopsis) \
                \(finding.statusSummary ?? "") \(finding.remediation) \
                \(finding.rationale)
                """.lowercased()
                return haystack.contains(searched.lowercased())
            }
        }

        let sorted = applySorting(to: filtered)
        return sorted
    }

    private var selectedFinding: AuditFinding? {
        guard let selection else { return nil }
        return coordinator.findings.first { $0.id == selection }
    }

    var body: some View {
        NavigationSplitView {
            AuditSidebarView(
                coordinator: coordinator,
                selectedDomain: $selectedDomain,
                startAudit: runAudit,
                resetAudit: resetAudit,
                exportAction: exportFindings
            )
        } content: {
            FindingListView(
                findings: displayedFindings,
                selection: $selection,
                selectedDomain: selectedDomain
            )
            .frame(minWidth: 360)
        } detail: {
            if let selectedFinding {
                FindingDetailView(finding: selectedFinding)
            } else if coordinator.findings.isEmpty && !coordinator.isRunning {
                LandingView(startAudit: runAudit)
            } else {
                FindingDetailPlaceholder(
                    isRunning: coordinator.isRunning,
                    hasResults: !coordinator.findings.isEmpty
                )
            }
        }
        .navigationSplitViewStyle(.balanced)
        .navigationSplitViewColumnWidth(min: 310, ideal: 380)
        .searchable(text: $searchText, placement: .toolbar, prompt: "Search findings")
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                HStack(spacing: 8) {
                    Picker("Sort by", selection: $sortKey) {
                        ForEach(SortKey.allCases) { key in
                            Text(key.label).tag(key)
                        }
                    }
                    .pickerStyle(.segmented)

                    Button {
                        ascending.toggle()
                    } label: {
                        Image(systemName: ascending ? "arrow.down.circle" : "arrow.up.circle")
                    }
                    .help(ascending ? "Ascending order" : "Descending order")
                }
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .onChange(of: selectedDomain) { scheduleSafeAutoSelection(clearFirst: true) }
        .onChange(of: coordinator.findings) { scheduleSafeAutoSelection(clearFirst: false) }
        .onChange(of: searchText) { scheduleSafeAutoSelection(clearFirst: true) }
        .onChange(of: sortKey) { scheduleSafeAutoSelection(clearFirst: false) }
        .onChange(of: ascending) { scheduleSafeAutoSelection(clearFirst: false) }
    }

    private func runAudit() {
        selection = nil
        if selectedDomain != .all {
            selectedDomain = .all
        }
        coordinator.start(domain: nil)
    }

    private func resetAudit() {
        selection = nil
        coordinator.reset()
    }

    private func scheduleSafeAutoSelection(clearFirst: Bool) {
        guard !coordinator.isRunning else { return }

        if clearFirst {
            selection = nil
        }

        guard !pendingAutoSelection else { return }
        pendingAutoSelection = true

        DispatchQueue.main.async {
            pendingAutoSelection = false
            safeAutoSelectFirstIfNeeded()
        }
    }

    private func safeAutoSelectFirstIfNeeded() {
        guard !displayedFindings.isEmpty else {
            selection = nil
            return
        }

        if let sel = selection, displayedFindings.contains(where: { $0.id == sel }) {
            return
        }

        selection = displayedFindings.first?.id
    }

    private func applySorting(to findings: [AuditFinding]) -> [AuditFinding] {
        let sorted: [AuditFinding]
        switch sortKey {
        case .verdict:
            let priority: [AuditFinding.Verdict: Int] = [
                .actionRequired: 0,
                .investigate: 1,
                .pass: 2,
                .unknown: 3
            ]
            sorted = findings.sorted { lhs, rhs in
                let lp = priority[lhs.verdict, default: 3]
                let rp = priority[rhs.verdict, default: 3]
                if lp == rp { return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending }
                return lp < rp
            }
        case .severity:
            let priority: [AuditFinding.Severity: Int] = [
                .critical: 0,
                .high: 1,
                .medium: 2,
                .low: 3,
                .informational: 4,
                .unknown: 5
            ]
            sorted = findings.sorted { lhs, rhs in
                let lp = priority[lhs.severity, default: 5]
                let rp = priority[rhs.severity, default: 5]
                if lp == rp { return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending }
                return lp < rp
            }
        case .title:
            sorted = findings.sorted {
                $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        }
        return ascending ? sorted : Array(sorted.reversed())
    }

    private func exportFindings() {
        let savePanel = NSSavePanel()
        if #available(macOS 12.0, *) {
            savePanel.allowedContentTypes = [.html]
        } else {
            savePanel.allowedFileTypes = ["html"]
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        savePanel.nameFieldStringValue = "Aman-Audit-\(timestamp).html"

        savePanel.begin { response in
            guard response == .OK, let url = savePanel.url else { return }
            do {
                let html = buildHTMLReport()
                try html.write(to: url, atomically: true, encoding: .utf8)
            } catch {
                NSSound.beep()
                NSLog("HTML export failed: \(error.localizedDescription)")
            }
        }
    }

    private func buildHTMLReport() -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let generated = dateFormatter.string(from: Date())
        let rows = coordinator.findings.map { finding -> String in
            """
            <tr>
                <td>\(htmlEscape(finding.categoryDisplay))</td>
                <td>\(htmlEscape(finding.title))</td>
                <td>\(htmlEscape(finding.verdict.displayLabel))</td>
                <td>\(htmlEscape(finding.severityDisplay))</td>
                <td>\(htmlEscape(finding.statusSummary ?? ""))</td>
                <td>\(htmlEscape(finding.remediation))</td>
            </tr>
            """
        }.joined(separator: "\n")
        return """
        <!DOCTYPE html>
        <html lang=\"en\">
        <head>
            <meta charset=\"utf-8\">
            <title>Aman Security Report</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif; background-color: #f5f5f7; color: #111; margin: 24px; }
                h1 { font-size: 28px; margin-bottom: 4px; }
                h2 { font-size: 16px; font-weight: 500; color: #666; margin-top: 0; }
                table { width: 100%; border-collapse: collapse; margin-top: 24px; }
                th, td { padding: 12px; border: 1px solid rgba(0,0,0,0.1); text-align: left; vertical-align: top; }
                th { background-color: rgba(0,0,0,0.04); font-weight: 600; }
                tr:nth-child(even) { background-color: rgba(0,0,0,0.02); }
            </style>
        </head>
        <body>
            <h1>Aman Security Report</h1>
            <h2>Generated on \(htmlEscape(generated)) · Total checks: \(coordinator.findings.count)</h2>
            <table>
                <thead>
                    <tr>
                        <th>Category</th>
                        <th>Check</th>
                        <th>Status</th>
                        <th>Severity</th>
                        <th>Current State</th>
                        <th>Recommended Action</th>
                    </tr>
                </thead>
                <tbody>
                    \(rows)
                </tbody>
            </table>
        </body>
        </html>
        """
    }

    private func htmlEscape(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
    }
}

#Preview {
    ContentView()
        .frame(width: 1100, height: 620)
}
