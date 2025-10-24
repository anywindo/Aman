//
//  FindingListView.swift
//  Aman
//
//  Reauthored by Codex.
//

import SwiftUI

struct FindingListView: View {
    let findings: [AuditFinding]
    @Binding var selection: UUID?
    let selectedDomain: AuditDomain

    var body: some View {
        Group {
            if findings.isEmpty {
                ContentUnavailableView(
                    selectedDomain == .all ? "No results yet" : "No results in \(selectedDomain.title)",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Run an audit first.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                List(selection: $selection) {
                    ForEach(findings) { finding in
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text(finding.title)
                                    .font(.headline)
                                Spacer()
                                verdictBadge(for: finding.verdict)
                            }

                            HStack(spacing: 12) {
                                Label(finding.severityDisplay, systemImage: "shield.lefthalf.fill")
                                    .labelStyle(.titleAndIcon)
                                Label(finding.categoryDisplay, systemImage: "square.grid.2x2")
                                    .labelStyle(.titleOnly)
                            }
                            .font(.caption)
                            .foregroundStyle(.secondary)

                            Text(finding.synopsis)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            if let summary = finding.statusSummary, !summary.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(summary)
                                        .font(.footnote)
                                        .foregroundStyle(.tertiary)
                                    if !finding.benchmarks.isEmpty {
                                        HStack {
                                            Spacer()
                                            Label(finding.benchmarks.joined(separator: ", "), systemImage: "checkmark.shield")
                                                .font(.caption2)
                                                .foregroundStyle(.secondary)
                                                .labelStyle(.titleAndIcon)
                                        }
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 6)
                        .tag(finding.id)
                        .textSelection(.enabled)
                    }
                }
                .listStyle(.inset)
            }
        }
        .navigationTitle(selectedDomain.title)
        .textSelection(.enabled)
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
            return ("Review", "exclamationmark.circle.fill", .orange)
        case .actionRequired:
            return ("Action", "xmark.octagon.fill", .red)
        case .unknown:
            return ("Unknown", "questionmark.circle.fill", .gray)
        }
    }
}
