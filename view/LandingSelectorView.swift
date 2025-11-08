//
//  LandingSelectorView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI

struct LandingSelectorView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 32) {
            VStack(spacing: 12) {
                Text("Welcome to Aman")
                    .font(.system(size: 34, weight: .bold))
                Text("Choose a security workspace to continue.")
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 24) {
                LandingTile(
                    title: "OS Security",
                    subtitle: "Audit local macOS hardening controls, compliance, and remediation hints.",
                    icon: "macwindow.on.rectangle",
                    tint: .blue
                ) {
                    openWorkspace(.osSecurity)
                }

                LandingTile(
                    title: "Network Security",
                    subtitle: "Scan authorized networks, fingerprint services, and map exposures to known CVEs.",
                    icon: "network",
                    tint: .green
                ) {
                    openWorkspace(.networkSecurity)
                }
            }
            .frame(maxWidth: 820)

            Spacer()
        }
        .padding(40)
        .frame(minWidth: 700, minHeight: 440)
        .background(
            WindowAccessor { window in
                window?.identifier = NSUserInterfaceItemIdentifier(AmanApp.WindowID.landing.rawValue)
            }
        )
    }

    private func openWorkspace(_ id: AmanApp.WindowID) {
        print("[Landing] Opening workspace: \(id.rawValue)")
        openWindow(id: id.rawValue)
        DispatchQueue.main.async {
            WindowManager.closeWindows(with: AmanApp.WindowID.landing.rawValue)
            dismiss()
        }
    }
}

private struct LandingTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.largeTitle)
                    .foregroundStyle(tint)
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Spacer()
                HStack(spacing: 6) {
                    Text("Open")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "arrow.right")
                        .font(.subheadline.weight(.semibold))
                }
            }
            .padding(24)
            .frame(height: 220)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(nsColor: .controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(isHovering ? tint.opacity(0.4) : Color.clear, lineWidth: 2)
                    )
                    .shadow(color: .black.opacity(isHovering ? 0.2 : 0.08), radius: isHovering ? 12 : 6, x: 0, y: 6)
            )
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }
}
