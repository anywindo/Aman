//
//  AuditSidebarView.swift
//  Aman
//
//  Reauthored by Codex.
//

import SwiftUI

struct AuditSidebarView: View {
    @ObservedObject var coordinator: AuditCoordinator
    @Binding var selectedDomain: AuditDomain
    let startAudit: () -> Void
    let resetAudit: () -> Void
    let exportAction: () -> Void

    private var distribution: (pass: Int, review: Int, action: Int) {
        coordinator.findings.reduce(into: (0, 0, 0)) { counts, finding in
            switch finding.verdict {
            case .pass:
                counts.pass += 1
            case .investigate:
                counts.review += 1
            case .actionRequired:
                counts.action += 1
            case .unknown:
                break
            }
        }
    }

    var body: some View {
        List(selection: $selectedDomain) {
            AmanBranding()
            Section("Audit Controls") {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        startAudit()
                    } label: {
                        Label(coordinator.isRunning ? "Auditing…" : "Start Audit", systemImage: "play.fill")
                            .fontWeight(.semibold)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 4)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.green)
                    .controlSize(.large)
                    .disabled(coordinator.isRunning)

                    HStack(spacing: 12) {
                        Button(role: .cancel) {
                            resetAudit()
                        } label: {
                            Label("Clear", systemImage: "xmark.circle")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .disabled(coordinator.findings.isEmpty && !coordinator.isRunning)

                        Button {
                            exportAction()
                        } label: {
                            Label("Export", systemImage: "square.and.arrow.down")
                                .frame(maxWidth: .infinity, alignment: .center)
                        }
                        .disabled(coordinator.findings.isEmpty)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.regular)
                }
                .padding(8)
            }

            Section("Domains") {
                ForEach(AuditDomain.allCases) { domain in
                    Label(domain.title, systemImage: domain.iconName)
                        .tag(domain)
                }
            }

            Section("Summary") {
                if coordinator.isRunning {
                    ProgressView(value: coordinator.progress) {
                        Text("Running checks…")
                    }
                    .progressViewStyle(.linear)
                } else if coordinator.findings.isEmpty {
                    Text("Run an audit to populate results.")
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.leading)
                } else {
                    SummaryCard(
                        title: "Pass",
                        subtitle: "Secure checks",
                        count: distribution.pass,
                        icon: "checkmark.seal.fill",
                        tint: SidebarPalette.pass
                    )
                    SummaryCard(
                        title: "Review",
                        subtitle: "Needs attention",
                        count: distribution.review,
                        icon: "exclamationmark.bubble.fill",
                        tint: SidebarPalette.review
                    )
                    SummaryCard(
                        title: "Action",
                        subtitle: "Fix required",
                        count: distribution.action,
                        icon: "xmark.octagon.fill",
                        tint: SidebarPalette.action
                    )
                }
            }
        }
        .textSelection(.enabled)
        .listStyle(.sidebar)
        .frame(minWidth: 280, idealWidth: 320)
        .navigationTitle("Overview")
        .overlay(alignment: .bottom) {
            Text("\(coordinator.availableModuleCount) checks available")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
                .frame(maxWidth: .infinity)
                .allowsHitTesting(false)
        }
    }
}

private struct SummaryCard: View {
    let title: String
    let subtitle: String
    let count: Int
    let icon: String
    let tint: SidebarPalette.Shade

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundStyle(tint.icon)
                .imageScale(.large)
                .frame(width: 34, height: 34)
                .background(tint.background, in: Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("\(count) checks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }
}

private struct AmanBranding: View {
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "shield.fill")
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(Color.accentColor)
                .font(.system(size: 28, weight: .semibold))
            VStack(alignment: .leading, spacing: 2) {
                Text("Aman")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Network & Security Auditor")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.bottom, 8)
        .padding(.horizontal, 4)
    }
}

private enum SidebarPalette {
    struct Shade {
        let background: Color
        let icon: Color
    }

    static let pass = Shade(background: Color.green.opacity(0.15), icon: .green)
    static let review = Shade(background: Color.orange.opacity(0.15), icon: .orange)
    static let action = Shade(background: Color.red.opacity(0.15), icon: .red)
}
