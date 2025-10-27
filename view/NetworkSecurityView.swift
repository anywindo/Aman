//
//  NetworkSecurityView.swift
//  Aman
//
//  Dashboard entry point for Network Security tooling.
//

import SwiftUI

struct NetworkSecurityView: View {
    @StateObject private var viewModel = NetworkSecurityViewModel()
    @StateObject private var certificateLookupViewModel = CertificateLookupViewModel()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: SidebarItem? = .internetToolkit
    @State private var selectedInternetCheck: InternetSecurityCheckResult.Kind? = .dnsLeak
    @State private var selectedCertificateID: CertificateEntry.ID?
    @State private var showLandingConfirmation = false

    private enum SidebarCategory: String, CaseIterable, Identifiable {
        case internetSecurity = "Internet Security"
        case utilities = "Utilities"

        var id: String { rawValue }
    }

    private enum SidebarItem: String, CaseIterable, Identifiable {
        case internetToolkit
        case utilitiesCertificateLookup
        case utilitiesHashGenerator
        case utilitiesNetworkAnalyzer
        case utilitiesNetworkMapping

        var id: String { rawValue }

        var category: SidebarCategory {
            switch self {
            case .internetToolkit:
                return .internetSecurity
            case .utilitiesCertificateLookup,
                 .utilitiesHashGenerator,
                 .utilitiesNetworkAnalyzer,
                 .utilitiesNetworkMapping:
                return .utilities
            }
        }

        var title: String {
            switch self {
            case .internetToolkit:
                return "Toolkit"
            case .utilitiesCertificateLookup:
                return "Certificate Lookup"
            case .utilitiesHashGenerator:
                return "Hash Generator"
            case .utilitiesNetworkAnalyzer:
                return "Network Analyzer"
            case .utilitiesNetworkMapping:
                return "Network Mapping"
            }
        }

        var icon: String {
            switch self {
            case .internetToolkit:
                return "shield.lefthalf.filled"
            case .utilitiesCertificateLookup:
                return "doc.text.magnifyingglass"
            case .utilitiesHashGenerator:
                return "number.square"
            case .utilitiesNetworkAnalyzer:
                return "waveform.path.ecg"
            case .utilitiesNetworkMapping:
                return "map.fill"
            }
        }

        var overviewTitle: String {
            switch self {
            case .internetToolkit:
                return "Internet Security Toolkit"
            case .utilitiesCertificateLookup,
                 .utilitiesHashGenerator,
                 .utilitiesNetworkAnalyzer,
                 .utilitiesNetworkMapping:
                return title
            }
        }

        var overviewMessage: String {
            switch self {
            case .internetToolkit:
                return "Run and monitor the integrated Internet Security suite."
            case .utilitiesCertificateLookup:
                return "Plan certificate transparency searches backed by crt.sh."
            case .utilitiesHashGenerator:
                return "Prepare flexible hashing workflows for files and ad-hoc text."
            case .utilitiesNetworkAnalyzer:
                return "Draft anomaly detection tooling with graph-first insights."
            case .utilitiesNetworkMapping:
                return "Sketch comprehensive hosts, ports, and topology mapping."
            }
        }

        var plannedHighlights: [String] {
            switch self {
            case .internetToolkit:
                return [
                    "Launch DNS, TLS, and HTTP posture checks",
                    "Correlate findings with remediation context"
                ]
            case .utilitiesCertificateLookup:
                return [
                    "Query crt.sh transparency logs",
                    "Surface certificate issuance timelines",
                    "Requires active internet connectivity"
                ]
            case .utilitiesHashGenerator:
                return [
                    "Select from common algorithms (SHA-256, BLAKE3, more)",
                    "Hash files or inline snippets",
                    "Copy results in one tap"
                ]
            case .utilitiesNetworkAnalyzer:
                return [
                    "Baseline traffic behaviour",
                    "Flag anomalies with visual graphs",
                    "Overlay alerts from existing telemetry"
                ]
            case .utilitiesNetworkMapping:
                return [
                    "Enumerate hosts and exposed services",
                    "Perform targeted port discovery",
                    "Visualise network topology live"
                ]
            }
        }

        var detailSubtitle: String {
            switch self {
            case .internetToolkit:
                return "Live suite"
            default:
                return "Coming soon"
            }
        }

        var detailDescription: String {
            switch self {
            case .internetToolkit:
                return "Use the toolkit to orchestrate end-to-end internet exposure checks without leaving Aman."
            case .utilitiesCertificateLookup:
                return "Certificate discovery will tap into crt.sh to spotlight unexpected issuance and misconfigurations."
            case .utilitiesHashGenerator:
                return "Hash Generator will streamline checksum workflows with multi-algorithm support tailored to security triage."
            case .utilitiesNetworkAnalyzer:
                return "Network Analyzer will crunch telemetry streams to surface anomalies, graph insights, and trends."
            case .utilitiesNetworkMapping:
                return "Network Mapping will unify host discovery, port scans, and topology exploration for faster reconnaissance."
            }
        }
    }

    private var selectedInternetResult: InternetSecurityCheckResult? {
        guard selectedItem == .internetToolkit, let selectedInternetCheck else { return nil }
        return viewModel.internetResult(for: selectedInternetCheck)
    }

    private var isSelectedInternetCheckRunning: Bool {
        guard selectedItem == .internetToolkit else { return false }
        guard let selectedInternetCheck else { return viewModel.isInternetSuiteRunning }
        return viewModel.internetRunningChecks.contains(selectedInternetCheck)
    }

    private var selectedCertificateEntry: CertificateEntry? {
        guard let selectedCertificateID else { return nil }
        return certificateLookupViewModel.results.first(where: { $0.id == selectedCertificateID })
    }

    var body: some View {
        splitLayout
            .navigationSplitViewStyle(.balanced)
            .navigationTitle("Network Security")
            .frame(minWidth: 900, minHeight: 600)
            .alert("Return to landing?", isPresented: $showLandingConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Switch", role: .destructive) {
                    openWindow(id: AmanApp.WindowID.landing.rawValue)
                    dispatchCloseNetworkWindow()
                }
            } message: {
                Text("Your current Network Security window will close. Continue?")
            }
            .onChange(of: selectedItem) { item in
                guard let item else { return }
                if item == .internetToolkit, selectedInternetCheck == nil {
                    selectedInternetCheck = .dnsLeak
                }
                if item != .internetToolkit {
                    selectedInternetCheck = nil
                }
                if item != .utilitiesCertificateLookup {
                    selectedCertificateID = nil
                }
            }
            .onChange(of: certificateLookupViewModel.results) { results in
                guard let currentID = selectedCertificateID else { return }
                if !results.contains(where: { $0.id == currentID }) {
                    selectedCertificateID = nil
                }
            }
    }

    // MARK: - Layout

    private var splitLayout: some View {
        NavigationSplitView {
            sidebarList
        } content: {
            contentPane
        } detail: {
            detailPane
        }
    }

    private var sidebarList: some View {
        List(selection: $selectedItem) {
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

            ForEach(sortedSidebarSections, id: \.category) { section in
                Section(section.category.rawValue) {
                    ForEach(section.items) { item in
                        Label(item.title, systemImage: item.icon)
                            .tag(item)
                    }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 260, idealWidth: 300)
    }

    @ViewBuilder
    private var contentPane: some View {
        switch selectedItem ?? .internetToolkit {
        case .internetToolkit:
            InternetSecurityToolkitView(
                selection: $selectedInternetCheck,
                results: viewModel.internetResults,
                runningChecks: viewModel.internetRunningChecks,
                isSuiteRunning: viewModel.isInternetSuiteRunning,
                lastError: viewModel.internetLastError,
                onRunSuite: { viewModel.runInternetSuite() },
                onRunCheck: { viewModel.runInternetCheck($0) }
            )
        case .utilitiesCertificateLookup:
            CertificateLookupView(
                viewModel: certificateLookupViewModel,
                selectedEntryID: $selectedCertificateID
            )
        default:
            if let item = selectedItem {
                placeholderContent(
                    title: item.overviewTitle,
                    message: item.overviewMessage,
                    items: item.plannedHighlights
                )
            } else {
                EmptyView()
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch selectedItem ?? .internetToolkit {
        case .internetToolkit:
            internetDetailView()
        case .utilitiesCertificateLookup:
            CertificateLookupDetailView(entry: selectedCertificateEntry)
        default:
            if let item = selectedItem {
                utilitiesDetailView(for: item)
            } else {
                EmptyView()
            }
        }
    }

    // MARK: - Detail helpers

    @ViewBuilder
    private func internetDetailView() -> some View {
        InternetSecurityDetailView(
            result: selectedInternetResult,
            isRunning: isSelectedInternetCheckRunning
        )
    }

    // MARK: - Helpers

    private func dispatchCloseNetworkWindow() {
        DispatchQueue.main.async {
            dismiss()
        }
    }

    private func placeholderContent(title: String, message: String, items: [String]) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(title)
                    .font(.title2.weight(.semibold))
                Text(message)
                    .foregroundStyle(.secondary)
                ForEach(items, id: \.self) { item in
                    Label(item, systemImage: "hammer.fill")
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 4)
                }
                Spacer()
            }
            .padding(32)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color(nsColor: .windowBackgroundColor))
    }
}

private extension NetworkSecurityView {
    private var sortedSidebarSections: [(category: SidebarCategory, items: [SidebarItem])] {
        SidebarCategory.allCases
            .sorted { $0.rawValue < $1.rawValue }
            .map { category in
                let items = SidebarItem.allCases
                    .filter { $0.category == category }
                    .sorted { $0.title < $1.title }
                return (category: category, items: items)
            }
    }

    @ViewBuilder
    private func utilitiesDetailView(for item: SidebarItem) -> some View {
        switch item {
        case .utilitiesCertificateLookup:
            CertificateLookupDetailView(entry: selectedCertificateEntry)
        default:
            PlaceholderDetailView(
                title: item.overviewTitle,
                subtitle: item.detailSubtitle,
                description: item.detailDescription
            )
        }
    }
}

// MARK: - Supporting Views

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

private struct PlaceholderDetailView: View {
    let title: String
    let subtitle: String
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(title)
                .font(.system(size: 28, weight: .semibold))
            Text(subtitle)
                .font(.headline)
                .foregroundStyle(.secondary)
            Text(description)
                .font(.body)
            Spacer()
        }
        .padding(40)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }
}
