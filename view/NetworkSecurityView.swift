//
//  NetworkSecurityView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI

struct NetworkSecurityView: View {
    @StateObject private var viewModel = NetworkSecurityViewModel()
    @StateObject private var certificateLookupViewModel = CertificateLookupViewModel()
    @StateObject private var hashGeneratorViewModel = HashGeneratorViewModel()
    @StateObject private var networkProfileViewModel = NetworkProfileViewModel()
    @StateObject private var networkAnalyzerViewModel = NetworkAnalyzerViewModel()
    @StateObject private var consentStore = NetworkWorkspaceConsentStore()
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss

    @State private var selectedItem: SidebarItem? = .utilitiesNetworkProfile
    @State private var selectedInternetCheck: InternetSecurityCheckResult.Kind? = .dnsLeak
    @State private var selectedCertificateID: CertificateEntry.ID?
    @State private var selectedMappingHostID: DiscoveredHost.ID?
    @State private var showLandingConfirmation = false
    @State private var hoverSwitch = false
    @State private var lastConfirmedItem: SidebarItem = .utilitiesNetworkProfile
    @State private var pendingConsentFeature: NetworkConsentFeature?
    @State private var pendingSidebarItem: SidebarItem?
    @State private var showConsentSheet = false

    private enum SidebarCategory: String, CaseIterable, Identifiable {
        case internetSecurity = "Internet Security"
        case utilities = "Utilities"
        case profile = ""

        var id: String { rawValue }
    }

    private enum SidebarItem: String, CaseIterable, Identifiable {
        case internetToolkit
        case utilitiesCertificateLookup
        case utilitiesHashGenerator
        case utilitiesNetworkAnalyzer
        case utilitiesNetworkMapping
        case utilitiesNetworkProfile

        var id: String { rawValue }

        var category: SidebarCategory {
            switch self {
            case .internetToolkit,
                 .utilitiesNetworkProfile:
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
            case .utilitiesNetworkProfile:
                return "Network Profile"
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
            case .utilitiesNetworkProfile:
                return "person.badge.key"
            }
        }

        var overviewTitle: String {
            switch self {
            case .internetToolkit:
                return "Internet Security Toolkit"
            case .utilitiesCertificateLookup,
                 .utilitiesHashGenerator,
                 .utilitiesNetworkAnalyzer,
                 .utilitiesNetworkMapping,
                 .utilitiesNetworkProfile:
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
            case .utilitiesNetworkProfile:
                return "See a compact snapshot of your current network connection."
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
            case .utilitiesNetworkProfile:
                return [
                    "Public IP and ISP/ASN",
                    "Local IP, gateway, DNS",
                    "Security flags (VPN, IPv6, HTTPS)"
                ]
            }
        }

        var detailSubtitle: String {
            switch self {
            case .internetToolkit:
                return "Live suite"
            case .utilitiesNetworkProfile:
                return "Live snapshot"
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
                return "Hash Generator lets you compare digests from modern and legacy algorithms in one place."
            case .utilitiesNetworkAnalyzer:
                return "Network Analyzer will crunch telemetry streams to surface anomalies, graph insights, and trends."
            case .utilitiesNetworkMapping:
                return "Network Mapping will unify host discovery, port scans, and topology exploration for faster reconnaissance."
            case .utilitiesNetworkProfile:
                return "Network Profile shows a compact card with your public IP, ISP/ASN, local addressing, DNS, gateway, and security indicators."
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

    private var selectedMappingHost: DiscoveredHost? {
        guard let id = selectedMappingHostID else { return nil }
        return viewModel.networkMappingHosts.first(where: { $0.id == id })
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
                handleSelectionChange(for: item)
            }
            .onChange(of: certificateLookupViewModel.results) { results in
                guard let currentID = selectedCertificateID else { return }
                if !results.contains(where: { $0.id == currentID }) {
                    selectedCertificateID = nil
                }
            }
            .sheet(isPresented: $showConsentSheet, onDismiss: {
                pendingConsentFeature = nil
                pendingSidebarItem = nil
            }) {
                if let feature = pendingConsentFeature {
                    NetworkConsentView(
                        feature: feature,
                        onDecline: { concludeConsent(granted: false) },
                        onAccept: { concludeConsent(granted: true) }
                    )
                } else {
                    EmptyView()
                }
            }
            .onAppear {
                let current = selectedItem ?? .utilitiesNetworkProfile
                lastConfirmedItem = current
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

            // Liquid Glass Switcher (to OS Security)
            Section {
                Button {
                    openWindow(id: AmanApp.WindowID.osSecurity.rawValue)
                    DispatchQueue.main.async {
                        WindowManager.closeWindows(with: AmanApp.WindowID.networkSecurity.rawValue)
                        dismiss()
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.25))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Circle()
                                        .stroke(Color.blue.opacity(0.35), lineWidth: 1)
                                )
                                .shadow(color: Color.blue.opacity(0.05), radius: 3, x: 0, y: 0)
                            Image(systemName: "shield.fill")
                                .foregroundStyle(.blue)
                                .imageScale(.small)
                                .offset(x: hoverSwitch ? 1.2 : 0, y: hoverSwitch ? 0.8 : 0)
                                .animation(.spring(response: 0.35, dampingFraction: 0.7), value: hoverSwitch)
                        }
                        VStack(alignment: .leading, spacing: 1) {
                            Text("OS Security")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .lineLimit(1)
                                .truncationMode(.tail)
                            Text("Switch workspace")
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
                            .fill(Color.blue.opacity(0.18))
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

    private func handleSelectionChange(for item: SidebarItem) {
        if let feature = consentFeature(for: item), !consentStore.hasConsent(for: feature) {
            pendingConsentFeature = feature
            pendingSidebarItem = item
            DispatchQueue.main.async {
                selectedItem = lastConfirmedItem
            }
            showConsentSheet = true
            return
        }

        lastConfirmedItem = item

        if item == .internetToolkit, selectedInternetCheck == nil {
            selectedInternetCheck = .dnsLeak
        }
        if item != .internetToolkit {
            selectedInternetCheck = nil
        }
        if item != .utilitiesCertificateLookup {
            selectedCertificateID = nil
        }
        if item != .utilitiesNetworkMapping {
            selectedMappingHostID = nil
        }
    }

    private func consentFeature(for item: SidebarItem) -> NetworkConsentFeature? {
        switch item {
        case .utilitiesNetworkAnalyzer:
            return .analyzer
        case .utilitiesNetworkMapping:
            return .mapping
        default:
            return nil
        }
    }

    private func concludeConsent(granted: Bool) {
        guard let feature = pendingConsentFeature else {
            showConsentSheet = false
            return
        }

        if granted {
            consentStore.recordConsent(true, for: feature)
            if let item = pendingSidebarItem {
                DispatchQueue.main.async {
                    selectedItem = item
                }
            }
        }

        pendingConsentFeature = nil
        pendingSidebarItem = nil
        showConsentSheet = false
    }

    @ViewBuilder
    private var contentPane: some View {
        switch selectedItem ?? .utilitiesNetworkProfile {
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
        case .utilitiesHashGenerator:
            ScrollView {
                HashGeneratorView(viewModel: hashGeneratorViewModel)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(Color.clear)
        case .utilitiesNetworkProfile:
            NetworkProfileView(viewModel: networkProfileViewModel)
        case .utilitiesNetworkAnalyzer:
            NetworkAnalyzerView(viewModel: networkAnalyzerViewModel)
        case .utilitiesNetworkMapping:
            NetworkMappingView(
                coordinator: viewModel.coordinatorForNetworkMapping(),
                hosts: viewModel.networkMappingHosts,
                lastDelta: viewModel.lastNetworkDiscoveryDelta,
                sampleError: viewModel.networkMappingSampleError,
                selectedHostID: $selectedMappingHostID,
                onDiscover: { viewModel.startNetworkDiscovery() },
                onRefreshTopology: { viewModel.refreshNetworkTopology() },
                onLoadSample: { viewModel.loadSampleNetworkData() }
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
        switch selectedItem ?? .utilitiesNetworkProfile {
        case .internetToolkit:
            internetDetailView()
        case .utilitiesCertificateLookup:
            CertificateLookupDetailView(entry: selectedCertificateEntry)
        case .utilitiesHashGenerator:
            HashGeneratorDetailView(viewModel: hashGeneratorViewModel)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        case .utilitiesNetworkProfile:
            NetworkProfileDetailView(viewModel: networkProfileViewModel)
        case .utilitiesNetworkAnalyzer:
            NetworkAnalyzerDetailView(viewModel: networkAnalyzerViewModel)
        case .utilitiesNetworkMapping:
            NetworkMappingDetailView(
                host: selectedMappingHost,
                scanState: viewModel.portScanState(for: selectedMappingHost),
                mode: viewModel.currentPortScanMode,
                onModeChange: { viewModel.setPortScanMode($0) },
                onScan: { viewModel.runPortScan(for: $0) },
                onCancel: { viewModel.cancelPortScan(for: $0) },
                onRetry: { viewModel.runPortScan(for: $0) }
            )
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
            .sorted { lhs, rhs in
                // Ensure Utilities appears above Network Profile
                let order: [SidebarCategory] = [.internetSecurity, .utilities, .profile]
                return (order.firstIndex(of: lhs) ?? 0) < (order.firstIndex(of: rhs) ?? 0)
            }
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
            case .utilitiesHashGenerator:
                HashGeneratorDetailView(viewModel: hashGeneratorViewModel)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            case .utilitiesNetworkAnalyzer:
                NetworkAnalyzerDetailView(viewModel: networkAnalyzerViewModel)
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
