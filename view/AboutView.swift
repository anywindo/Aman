//
//  AboutView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI
import AppKit

struct AboutView: View {
    @State private var showLicenses = false
    @State private var copyToast: String?

    private var appDisplayName: String {
        let bundle = Bundle.main
        return bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
            ?? bundle.object(forInfoDictionaryKey: "CFBundleName") as? String
            ?? "Aman"
    }

    private var appVersion: String {
        let bundle = Bundle.main
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0.0"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "\(version) (\(build))"
    }

    private var macOSVersionString: String {
        ProcessInfo.processInfo.operatingSystemVersionString
    }

    private var deviceModel: String {
        // Try machine model (e.g., Mac14,3)
        var size: Int = 0
        sysctlbyname("hw.model", nil, &size, nil, 0)
        var model = [CChar](repeating: 0, count: size > 0 ? size : 128)
        sysctlbyname("hw.model", &model, &size, nil, 0)
        let modelString = String(cString: model).trimmingCharacters(in: .whitespacesAndNewlines)
        if !modelString.isEmpty { return modelString }

        // Fallback to localized name
        return Host.current().localizedName ?? "Mac"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                Divider()

                taglineAndDescription

                urlsSection

                featureButtons

                transparencyPrivacy

                creditsSection

                supportSection

                systemInfoSection

                footerLegal
            }
            .padding(24)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(
            WindowAccessor(callback: { window in
                window?.identifier = NSUserInterfaceItemIdentifier(AmanApp.WindowID.about.rawValue)
            })
        )
        .sheet(isPresented: $showLicenses) {
            LicensesSheet()
        }
        .overlay(alignment: .bottom) {
            if let copyToast {
                Text(copyToast)
                    .font(.footnote)
                    .padding(.vertical, 6)
                    .padding(.horizontal, 12)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 16) {
            appIcon
                .frame(width: 64, height: 64)
                .cornerRadius(14)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)

            VStack(alignment: .leading, spacing: 4) {
                Text(appDisplayName)
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                Text("Version \(appVersion)")
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var appIcon: some View {
        if let nsImage = NSImage(named: NSImage.applicationIconName) {
            Image(nsImage: nsImage)
                .resizable()
                .interpolation(.high)
        } else {
            Image(systemName: "shield.lefthalf.filled")
                .font(.system(size: 40))
                .foregroundStyle(Color.accentColor)
        }
    }

    private var taglineAndDescription: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Secure with Aman")
                .font(.headline)
            Text("Aman helps you understand and improve your Mac’s security posture with practical audits and lightweight network insights, all under your control.")
                .foregroundStyle(.secondary)
        }
    }

    private var urlsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Links")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                // Only GitHub is provided; others are intentionally omitted per spec
                if let url = URL(string: "https://github.com/anywindo/Aman") {
                    // Use the explicit title/image initializer to avoid ambiguous Label overloads
                    Link("GitHub Repository", destination: url)
                        .font(.body)
                        .overlay(alignment: .leading) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left.slash.chevron.right")
                                Text("GitHub Repository")
                            }
                            .opacity(0) // Keep visual as default Link; remove if you want custom look
                        }
                    // If you want a custom visual with icon and text, comment the line above and use:
                    // HStack(spacing: 6) {
                    //     Image(systemName: "chevron.left.slash.chevron.right")
                    //     Link("GitHub Repository", destination: url)
                    // }
                }
            }
            .foregroundStyle(.primary)
        }
    }

    private var featureButtons: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Utilities")
                .font(.headline)
            HStack(spacing: 10) {
                Button {
                    showLicenses = true
                } label: {
                    Label("View Licenses", systemImage: "doc.text.magnifyingglass")
                }
                .buttonStyle(.bordered)

                Button {
                    copyVersionInfoToClipboard()
                } label: {
                    Label("Copy Version Info", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private var transparencyPrivacy: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Transparency & Privacy")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                infoRow("Data Collection", value: "None")
                infoRow("Data Export/Delete Method", value: "Locally")
                infoRow("Log Storage", value: "None")
            }
            .font(.subheadline)
        }
    }

    private var creditsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Credits & Acknowledgments")
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Contributors")
                    .font(.subheadline.weight(.semibold))
                Text("DustInTheWind/anywindo, auraxia, Bluesyw, Lia, ZackDoingAnything, UAJY (Institution)")
                    .foregroundStyle(.secondary)
                Divider().padding(.vertical, 6)
                Text("Third‑Party Libraries")
                    .font(.subheadline.weight(.semibold))
                Text("(unspecified)")
                    .foregroundStyle(.secondary)
                Divider().padding(.vertical, 6)
                Text("Icon/Design Credits")
                    .font(.subheadline.weight(.semibold))
                Text("DustInTheWind/anywindo")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    private var supportSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Support")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                infoRow("Support Email/Contact", value: "None")
                infoRow("Issue Tracker", value: "None")
                infoRow("FAQ", value: "None")
            }
            .font(.subheadline)
        }
    }

    private var systemInfoSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("System Info")
                .font(.headline)
            VStack(alignment: .leading, spacing: 6) {
                infoRow("macOS Version", value: macOSVersionString)
                infoRow("Device Model", value: deviceModel)
            }
            .font(.subheadline)
        }
    }

    private var footerLegal: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Legal")
                .font(.headline)
            VStack(alignment: .leading, spacing: 4) {
                Text("Copyright")
                    .font(.subheadline.weight(.semibold))
                Text("None")
                    .foregroundStyle(.secondary)
                Divider().padding(.vertical, 6)
                Text("Trademark Notices")
                    .font(.subheadline.weight(.semibold))
                Text("None")
                    .foregroundStyle(.secondary)
                Divider().padding(.vertical, 6)
                Text("EULA/Terms")
                    .font(.subheadline.weight(.semibold))
                Text("None")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private func infoRow(_ title: String, value: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .foregroundStyle(.secondary)
                .frame(width: 180, alignment: .leading)
            Text(value)
            Spacer(minLength: 0)
        }
    }

    private func copyVersionInfoToClipboard() {
        let info = """
        \(appDisplayName) \(appVersion)
        macOS: \(macOSVersionString)
        Device: \(deviceModel)
        """
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(info, forType: .string)
        presentToast("Version info copied.")
    }

    private func presentToast(_ message: String) {
        withAnimation {
            copyToast = message
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            withAnimation {
                if copyToast == message {
                    copyToast = nil
                }
            }
        }
    }
}

// MARK: - Licenses Sheet

private struct LicensesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var licenseText: String = ""
    @State private var loadError: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Licenses")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.thinMaterial)

            Divider()

            if let loadError {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 28))
                        .foregroundStyle(.orange)
                    Text(loadError)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding()
            } else {
                ScrollView {
                    Text(licenseText.isEmpty ? defaultMITNotice : licenseText)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding()
                }
            }
        }
        .frame(minWidth: 520, minHeight: 420)
        .onAppear(perform: loadLicense)
    }

    private func loadLicense() {
        // Try to load LICENSE from bundle resources
        if let url = Bundle.main.url(forResource: "LICENSE", withExtension: nil),
           let text = try? String(contentsOf: url, encoding: .utf8) {
            licenseText = text
            return
        }
        // If not found, present default MIT notice as a fallback
        licenseText = defaultMITNotice
    }

    private var defaultMITNotice: String {
        """
        MIT License

        Permission is hereby granted, free of charge, to any person obtaining a copy
        of this software and associated documentation files (the “Software”), to deal
        in the Software without restriction, including without limitation the rights
        to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
        copies of the Software, and to permit persons to whom the Software is
        furnished to do so, subject to the following conditions:

        The above copyright notice and this permission notice shall be included in
        all copies or substantial portions of the Software.

        THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
        IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
        FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
        AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
        LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
        OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
        THE SOFTWARE.
        """
    }
}

#Preview {
    AboutView()
        .frame(width: 484, height: 560)
        .padding()
}
