//
//  NetworkMappingView.swift
//  Aman
//
//  Presents discovered hosts and controls for the Network Mapping feature.
//

import SwiftUI
import UniformTypeIdentifiers

#if os(macOS)
import AppKit
#endif

struct NetworkMappingView: View {
    @Environment(\.openWindow) private var openWindow
    @ObservedObject var coordinator: NetworkMappingCoordinator
    let hosts: [DiscoveredHost]
    let lastDelta: NetworkDiscoveryDelta?
    let sampleError: String?
    @Binding var selectedHostID: DiscoveredHost.ID?
    let onDiscover: () -> Void
    let onRefreshTopology: () -> Void
    let onLoadSample: () -> Void
    @State private var exportAlert: ExportAlertItem?

    private var footerSummary: String {
        guard let delta = lastDelta else { return "Ready for discovery." }
        var components: [String] = []
        if !delta.added.isEmpty { components.append("\(delta.added.count) new") }
        if !delta.updated.isEmpty { components.append("\(delta.updated.count) updated") }
        if !delta.removed.isEmpty { components.append("\(delta.removed.count) offline") }
        return components.isEmpty ? "No changes detected." : components.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            controlRow
            hostList
            footer
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(coordinator.$topologySelectionIPAddress.compactMap { $0 }) { ip in
            if let host = hosts.first(where: { $0.ipAddress == ip }) {
                selectedHostID = host.id
            }
        }
        .onChange(of: selectedHostID) { newValue in
            if let id = newValue, let host = hosts.first(where: { $0.id == id }) {
                coordinator.highlightedHostIPAddress = host.ipAddress
            } else if newValue == nil {
                coordinator.highlightedHostIPAddress = nil
            }
        }
        .onChange(of: hosts) { updated in
            guard let id = selectedHostID else { return }
            if updated.first(where: { $0.id == id }) == nil {
                selectedHostID = nil
            }
        }
        .onChange(of: coordinator.exportStatus) { status in
            switch status {
            case .completed(let kind, let url, _):
                exportAlert = ExportAlertItem(
                    title: "Export Complete",
                    message: "\(kind.displayName) saved to \(url.path).",
                    url: url
                )
            case .failed(let kind, let message):
                exportAlert = ExportAlertItem(
                    title: "Export Failed",
                    message: "\(kind.displayName) export failed: \(message)",
                    url: nil
                )
            default:
                break
            }
        }
        .alert(item: $exportAlert) { item in
            if let url = item.url {
                return Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    primaryButton: .default(Text("Reveal in Finder")) {
#if os(macOS)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
#endif
                        coordinator.resetExportStatus()
                    },
                    secondaryButton: .cancel {
                        coordinator.resetExportStatus()
                    }
                )
            } else {
                return Alert(
                    title: Text(item.title),
                    message: Text(item.message),
                    dismissButton: .default(Text("OK")) {
                        coordinator.resetExportStatus()
                    }
                )
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Network Mapping")
                .font(.title2.bold())
            Text("Discover hosts, refresh topology, and explore your network graph.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var controlRow: some View {
        HStack(spacing: 12) {
            Button {
                onDiscover()
            } label: {
                Label("Discover Hosts", systemImage: "arrow.clockwise.circle.fill")
            }
            .buttonStyle(.borderedProminent)
            .disabled(coordinator.isDiscoveryRunning)

            Button {
                openWindow(id: AmanApp.WindowID.networkTopology.rawValue)
            } label: {
                Label("Topology", systemImage: "square.grid.3x3.fill")
            }
            .buttonStyle(.bordered)
            .disabled(hosts.isEmpty)

            Menu {
                ForEach(NetworkMappingExportKind.allCases, id: \.self) { kind in
                    Button(kind.displayName) {
                        handleExport(kind)
                    }
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(hosts.isEmpty)

            if coordinator.isDiscoveryRunning {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
            }
            if case .running = coordinator.exportStatus {
                ProgressView()
                    .progressViewStyle(.circular)
                    .scaleEffect(0.9)
            }
            Spacer()
            Text("\(hosts.count) hosts")
                .font(.callout.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var hostList: some View {
        List(selection: $selectedHostID) {
            ForEach(hosts) { host in
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.ipAddress)
                        .font(.headline)
                    if let name = host.hostName {
                        Text(name)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Text("Last seen \(host.lastSeen, style: .relative) ago")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.vertical, 6)
                .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
                .listRowBackground(Color.clear)
            }
        }
        .listStyle(.plain)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var footer: some View {
        HStack {
            if let error = sampleError {
                Text(error)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else {
                Text(footerSummary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

private extension NetworkMappingExportKind {
    var displayName: String {
        switch self {
        case .jsonSnapshot:
            return "Snapshot (JSON)"
        case .hostsCSV:
            return "Hosts & Services (CSV)"
        case .topologyDOT:
            return "Topology (DOT)"
        case .topologyMermaid:
            return "Topology (Mermaid)"
        }
    }

#if os(macOS)
    var allowedContentTypes: [UTType] {
        switch self {
        case .jsonSnapshot:
            return [.json]
        case .hostsCSV:
            if let csvType = UTType("public.comma-separated-values-text") {
                return [csvType, .plainText]
            }
            return [.plainText]
        case .topologyDOT, .topologyMermaid:
            return [.plainText]
        }
    }
#endif
}

private extension NetworkMappingView {
    struct ExportAlertItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String
        let url: URL?
    }

    func handleExport(_ kind: NetworkMappingExportKind) {
#if os(macOS)
        guard let destination = presentSavePanel(for: kind) else {
            return
        }
        coordinator.export(kind: kind, to: destination)
#endif
    }

#if os(macOS)
    func presentSavePanel(for kind: NetworkMappingExportKind) -> URL? {
        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = suggestedFileName(for: kind)
        panel.allowedContentTypes = kind.allowedContentTypes
        return panel.runModal() == .OK ? panel.url : nil
    }

    func suggestedFileName(for kind: NetworkMappingExportKind) -> String {
        let timestamp = ISO8601DateFormatter().string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let baseName: String
        switch kind {
        case .jsonSnapshot:
            baseName = "network-mapping-snapshot-\(timestamp)"
        case .hostsCSV:
            baseName = "network-mapping-hosts-\(timestamp)"
        case .topologyDOT:
            baseName = "network-topology-\(timestamp)"
        case .topologyMermaid:
            baseName = "network-topology-\(timestamp)"
        }
        let defaultExtension: String
        switch kind {
        case .jsonSnapshot:
            defaultExtension = "json"
        case .hostsCSV:
            defaultExtension = "csv"
        case .topologyDOT:
            defaultExtension = "dot"
        case .topologyMermaid:
            defaultExtension = "mmd"
        }
        return "\(baseName).\(defaultExtension)"
    }
#endif
}

// MARK: - Local SectionCard (scoped to this file)

private struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
