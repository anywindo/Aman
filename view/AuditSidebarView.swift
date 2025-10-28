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

    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @State private var showLandingConfirmation = false
    @State private var hoverSwitch = false

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
            Section {
                Button {
                    showLandingConfirmation = true
                } label: {
                    AmanBranding()
                        .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 14, leading: 8, bottom: 10, trailing: 8))
                .listRowBackground(Color.clear)
            }

            // Liquid Glass Switcher
            Section {
                // Short, simple copy
                switchWorkspaceCard(
                    title: "Network Security",
                    subtitle: "Switch workspace",
                    icon: "network",
                    tint: .green
                ) {
                    openWindow(id: AmanApp.WindowID.networkSecurity.rawValue)
                    DispatchQueue.main.async {
                        WindowManager.closeWindows(with: AmanApp.WindowID.osSecurity.rawValue)
                        dismiss()
                    }
                }
            }

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
        .alert("Return to landing?", isPresented: $showLandingConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Switch", role: .destructive) {
                openWindow(id: AmanApp.WindowID.landing.rawValue)
                dispatchCloseAuditWindow()
            }
        } message: {
            Text("Your current OS Security window will close. Continue?")
        }
    }

    private func dispatchCloseAuditWindow() {
        DispatchQueue.main.async {
            dismiss()
        }
    }

    // MARK: - Liquid Glass Switcher

    @ViewBuilder
    private func switchWorkspaceCard(title: String, subtitle: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.25))
                        .frame(width: 32, height: 32)
                        .overlay(
                            Circle()
                                .stroke(tint.opacity(0.35), lineWidth: 1)
                        )
                        .shadow(color: tint.opacity(0.05), radius: 3, x: 0, y: 0)
                    Image(systemName: icon)
                        .foregroundStyle(tint)
                        .imageScale(.small)
                        .offset(x: hoverSwitch ? 1.2 : 0, y: hoverSwitch ? 0.8 : 0)
                        .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hoverSwitch)
                }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                Spacer(minLength: 6)
                Image(systemName: "arrow.left.arrow.right.circle.fill")
                    .foregroundStyle(.secondary)
                    .imageScale(.medium)
                    .opacity(hoverSwitch ? 1.0 : 0.65)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 10)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(tint.opacity(0.18)) // Green-tinted background
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.25).blendMode(.overlay), lineWidth: 0.8)
                    )
                    .shadow(color: .black.opacity(hoverSwitch ? 0.05 : 0.01), radius: hoverSwitch ? 5 : 2, x: 0, y: hoverSwitch ? 3 : 1)
            )
            .padding(.vertical, 10)
            .padding(.horizontal, 0)
            .scaleEffect(hoverSwitch ? 1.02 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: hoverSwitch)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                hoverSwitch = hovering
            }
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 8, bottom: 6, trailing: 8))
        .listRowBackground(Color.clear)
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
            Image(systemName: "magnifyingglass")
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
