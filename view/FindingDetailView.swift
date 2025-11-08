//
//  FindingDetailView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI
import AppKit

struct FindingDetailView: View {
    let finding: AuditFinding
    @State private var toastMessage: String?

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 16) {
                header
                metadata
                Divider()
                detailSection(title: "Current Status", systemImage: "info.circle") {
                    Text(finding.statusSummary ?? "Status information not available.")
                }
                if !finding.remediation.isEmpty {
                    detailSection(title: "Recommended Action", systemImage: "hammer") {
                        Text(finding.remediation)
                    }
                }
                if !shortcuts.isEmpty {
                    detailSection(title: "Quick Actions", systemImage: "bolt.fill") {
                        VStack(alignment: .leading, spacing: 12) {
                            ForEach(shortcuts, id: \.self) { shortcut in
                                ShortcutRow(
                                    shortcut: shortcut,
                                    triggerSettings: openSystemSettings(url:),
                                    copyText: copyTextToClipboard(_:),
                                    runScript: runAppleScript(_:)
                                )
                            }
                        }
                    }
                }
                if !finding.rationale.isEmpty {
                    detailSection(title: "Why it Matters", systemImage: "lightbulb") {
                        Text(finding.rationale)
                    }
                }
                if let url = finding.referenceURL {
                    detailSection(title: "Further Reading", systemImage: "link") {
                        Link("Open documentation", destination: url)
                    }
                }
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(.thinMaterial)
        .textSelection(.enabled)
        .navigationTitle(finding.title)
        .overlay(alignment: .bottom) {
            if let toastMessage {
                Text(toastMessage)
                    .font(.footnote)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 20)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(finding.title)
                .font(.title2)
                .fontWeight(.semibold)
            Label(finding.categoryDisplay, systemImage: "square.stack.3d.up")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    private var metadata: some View {
        Grid(alignment: .leading, verticalSpacing: 12) {
            GridRow {
                Text("Severity")
                    .foregroundStyle(.secondary)
                Text(finding.severityDisplay)
                    .fontWeight(.medium)
            }
            if !finding.benchmarks.isEmpty {
                GridRow(alignment: .top) {
                    Text("Benchmarks")
                        .foregroundStyle(.secondary)
                    Text(finding.benchmarks.joined(separator: ", "))
                        .foregroundStyle(.primary)
                }
            }
            GridRow {
                Text("Status")
                    .foregroundStyle(.secondary)
                verdictBadge(for: finding.verdict)
            }
            GridRow {
                Text("Document ID")
                    .foregroundStyle(.secondary)
                Text("#\(finding.docReference)")
            }
            if let error = finding.runtimeError {
                GridRow {
                    Text("Errors")
                        .foregroundStyle(.secondary)
                    Text(error)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .font(.subheadline)
    }

    private var shortcuts: [RemediationShortcut] {
        RemediationCatalog.shortcuts(for: finding)
    }

    private func openSystemSettings(url: URL) {
        NSWorkspace.shared.open(url)
    }

    private func copyTextToClipboard(_ value: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(value, forType: .string)
        presentToast("Copied to clipboard.")
    }

    private func runAppleScript(_ source: String) {
        guard let script = NSAppleScript(source: source) else {
            presentToast("Unable to compile AppleScript.")
            return
        }

        var errorDictionary: NSDictionary?
        script.executeAndReturnError(&errorDictionary)

        if let errorDictionary,
           let message = errorDictionary[NSAppleScript.errorMessage] as? String {
            presentToast("AppleScript error: \(message)")
        } else {
            presentToast("AppleScript executed.")
        }
    }

    private func presentToast(_ message: String) {
        withAnimation {
            toastMessage = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                if toastMessage == message {
                    toastMessage = nil
                }
            }
        }
    }

    private func detailSection(title: String, systemImage: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.headline)
            content()
                .font(.body)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .shadow(color: .black.opacity(0.05), radius: 8, x: 0, y: 4)
        )
    }

    private func verdictBadge(for verdict: AuditFinding.Verdict) -> some View {
        let info = badgeInfo(for: verdict)
        return Label(info.label, systemImage: info.icon)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(info.tint.opacity(0.15), in: Capsule())
            .foregroundColor(info.tint)
            .labelStyle(.titleAndIcon)
    }

    private func badgeInfo(for verdict: AuditFinding.Verdict) -> (label: String, icon: String, tint: Color) {
        switch verdict {
        case .pass:
            return ("Pass", "checkmark.circle.fill", .green)
        case .investigate:
            return ("Review", "exclamationmark.triangle.fill", .orange)
        case .actionRequired:
            return ("Action Needed", "xmark.octagon.fill", .red)
        case .unknown:
            return ("Unknown", "questionmark.circle.fill", .gray)
        }
    }
}

struct FindingDetailPlaceholder: View {
    let isRunning: Bool
    let hasResults: Bool

    var body: some View {
        ContentUnavailableView {
            Label(title, systemImage: isRunning ? "arrow.triangle.2.circlepath" : "doc.text")
        } description: {
            Text(message)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var title: String {
        if isRunning { return "Audit in progress" }
        if hasResults { return "Select a finding" }
        return "No results yet"
    }

    private var message: String {
        if isRunning {
            return "Hang tight while Aman reviews your security posture."
        }
        if hasResults {
            return "Pick a finding from the middle column to view details and remediation steps."
        }
        return "Start an audit to populate this pane with results."
    }
}

private struct ShortcutRow: View {
    let shortcut: RemediationShortcut
    let triggerSettings: (URL) -> Void
    let copyText: (String) -> Void
    let runScript: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            switch shortcut.kind {
            case .systemSettings(let url):
                Button {
                    triggerSettings(url)
                } label: {
                    Label(shortcut.title, systemImage: "gearshape")
                        .font(.body.weight(.semibold))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)
                if let subtitle = shortcut.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

            case .command(let command):
                Text(shortcut.title)
                    .font(.body.weight(.semibold))
                if let subtitle = shortcut.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(command)
                        .font(.system(.body, design: .monospaced))
                        .textSelection(.enabled)
                    Spacer()
                    Button {
                        copyText(command)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            case .appleScript(let script):
                Text(shortcut.title)
                    .font(.body.weight(.semibold))
                if let subtitle = shortcut.subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(script)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .padding(12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(nsColor: .controlBackgroundColor))
                    )
                HStack(spacing: 12) {
                    Button {
                        runScript(script)
                    } label: {
                        Label("Run", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    Button {
                        copyText(script)
                    } label: {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor).opacity(0.6))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.black.opacity(0.05))
        )
    }
}
