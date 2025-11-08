//
//  AboutView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI

struct AboutView: View {
    // Replace these URLs with your real destinations
    private let websiteURL = URL(string: "https://example.com")!
    private let privacyURL = URL(string: "https://example.com/privacy")!
    private let supportURL = URL(string: "https://example.com/support")!
    private let githubURL = URL(string: "https://github.com/example/aman")!

    private var appName: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleName") as? String ?? "Aman"
    }

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: kCFBundleVersionKey as String) as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        ZStack {
            // Subtle background to match your app’s use of materials
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.regularMaterial)

            VStack(spacing: 18) {
                // App icon
                Image("AppIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .shadow(color: .black.opacity(0.1), radius: 8, x: 0, y: 3)

                // Name and version
                VStack(spacing: 4) {
                    Text(appName)
                        .font(.title)
                        .fontWeight(.semibold)
                    Text(versionString)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Tagline and description
                VStack(spacing: 8) {
                    Text("Network & Security Auditor")
                        .font(.headline)
                    Text("Assess how your Mac aligns with modern security and privacy best practices. Run scans, review findings, and take action with clear guidance.")
                        .font(.subheadline)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                }
                .padding(.top, 4)

                // Action links
                HStack(spacing: 12) {
                    Link(destination: websiteURL) {
                        Label("Website", systemImage: "globe")
                    }
                    .buttonStyle(.bordered)

                    Link(destination: privacyURL) {
                        Label("Privacy", systemImage: "hand.raised.fill")
                    }
                    .buttonStyle(.bordered)

                    Link(destination: supportURL) {
                        Label("Support", systemImage: "lifepreserver")
                    }
                    .buttonStyle(.bordered)

                    Link(destination: githubURL) {
                        Label("GitHub", systemImage: "chevron.left.slash.chevron.right")
                    }
                    .buttonStyle(.bordered)
                }
                .controlSize(.regular)
                .padding(.top, 4)

                // Fine print
                Text("© \(Calendar.current.component(.year, from: Date())) Aman. All rights reserved.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
            }
            .padding(22)
            .frame(width: 460, height: 420)
        }
        .padding(12)
        .background(Color.clear)
    }
}

#Preview {
    AboutView()
        .frame(width: 484, height: 444)
        .padding()
}

