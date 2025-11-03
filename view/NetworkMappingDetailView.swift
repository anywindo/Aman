//
//  NetworkMappingDetailView.swift
//  Aman
//
//  Detail pane for selected host within Network Mapping.
//

import SwiftUI

struct NetworkMappingDetailView: View {
    let host: DiscoveredHost?
    let scanState: PortScanJobState?
    let mode: PortScanMode
    let onModeChange: (PortScanMode) -> Void
    let onScan: (DiscoveredHost) -> Void
    let onCancel: (DiscoveredHost) -> Void
    let onRetry: (DiscoveredHost) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let host {
                header(for: host)
                Divider()
                scanStatus(for: host)
                Divider()
                servicesList(for: host)
            } else {
                Text("Select a Host")
                    .font(.title2.weight(.semibold))
                Text("Awaiting selection")
                    .font(.headline)
                    .foregroundStyle(.secondary)
                Text("Choose a host from the list to review resolved services, run targeted port scans, and export details.")
                    .font(.body)
            }
            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func header(for host: DiscoveredHost) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.ipAddress)
                        .font(.title2.weight(.semibold))
                    if let hostName = host.hostName {
                        Text(hostName)
                            .font(.headline)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
                Button {
                    onScan(host)
                } label: {
                    Label("Scan Ports", systemImage: "waveform.path.ecg")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isScanning)
            }
            Text("Last seen \(host.lastSeen, style: .relative) ago")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Picker("Mode", selection: Binding(
                get: { mode },
                set: { onModeChange($0) }
            )) {
                ForEach(PortScanMode.allCases, id: \.self) { scanMode in
                    Text(scanMode.displayName).tag(scanMode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.top, 6)
            if mode.requiresPrivileges {
                Text("Enhanced SYN mode requires elevated privileges and raw socket access. Aman will not prompt for sudo automatically.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var isScanning: Bool {
        if case .running = scanState?.status {
            return true
        }
        return false
    }

    @ViewBuilder
    private func scanStatus(for host: DiscoveredHost) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Scan Status")
                .font(.headline)

            switch scanState?.status ?? .idle {
            case .idle:
                if let lastRun = scanState?.lastRunAt {
                    Text("Last scan \(lastRun.formattedRelative()) using \(scanState?.mode.displayName ?? mode.displayName).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    Text("No targeted scan yet. Run a scan to populate service details.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                actionButtons(host: host, showRetry: false)
            case .running(let update):
                VStack(alignment: .leading, spacing: 6) {
                    ProgressView(value: update.progress)
                        .progressViewStyle(.linear)
                    HStack {
                        Text("Scanning ports… \(update.completed)/\(update.total)")
                            .font(.subheadline)
                        if let current = update.currentPort {
                            Text("current: \(current)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                actionButtons(host: host, showRetry: false, showCancel: true)
            case .completed(let date):
                VStack(alignment: .leading, spacing: 4) {
                    Text("Completed \(date.formattedRelative()) using \(scanState?.mode.displayName ?? mode.displayName).")
                        .font(.subheadline)
                    if let ports = scanState?.lastPorts, ports.isEmpty {
                        Text("No open ports detected across the scanned set.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else if let ports = scanState?.lastPorts {
                        Text("\(ports.count) open ports detected.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                actionButtons(host: host, showRetry: true)
            case .failed(let message):
                VStack(alignment: .leading, spacing: 6) {
                    Label(message, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                        .font(.subheadline)
                    if mode.requiresPrivileges {
                        Text("Switch back to Standard mode or run Aman with elevated permissions for SYN scans.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                actionButtons(host: host, showRetry: true)
            case .cancelled:
                Text("Scan cancelled.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                actionButtons(host: host, showRetry: true)
            }
        }
    }

    @ViewBuilder
    private func actionButtons(host: DiscoveredHost, showRetry: Bool, showCancel: Bool = false) -> some View {
//        HStack(spacing: 12) {
//            if showCancel {
//                Button(role: .cancel) {
//                    onCancel(host)
//                } label: {
//                    Label("Cancel", systemImage: "xmark.circle")
//                }
//                .buttonStyle(.bordered)
//            }
//            if showRetry {
//                Button {
//                    onRetry(host)
//                } label: {
//                    Label("Retry Scan", systemImage: "arrow.clockwise.circle")
//                }
//                .buttonStyle(.borderedProminent)
//                .tint(.accentColor)
//            } else if !showCancel {
//                Button {
//                    onScan(host)
//                } label: {
//                    Label("Scan Ports", systemImage: "waveform.path.ecg")
//                }
//                .buttonStyle(.borderedProminent)
//            }
//        }
    }

    private func servicesList(for host: DiscoveredHost) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Detected Services")
                .font(.headline)

            if host.services.isEmpty {
                Text("No service fingerprints yet. Run a targeted scan to populate this list.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(host.services, id: \.self) { service in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(service.protocolName.uppercased()) \(service.port)")
                                .font(.body.weight(.semibold))
                            if let product = service.product {
                                Text(serviceDescription(for: service))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(10)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.secondary.opacity(0.08))
                    )
                }
            }
        }
    }

    private func serviceDescription(for service: DiscoveredHost.ServiceSummary) -> String {
        if let version = service.version, let product = service.product {
            return "\(product) \(version)"
        } else if let product = service.product {
            return product
        } else if let version = service.version {
            return version
        }
        return "Service fingerprint pending"
    }
}

private extension Date {
    func formattedRelative() -> String {
        if #available(macOS 13.0, *) {
            return formatted(.relative(presentation: .named))
        } else {
            let formatter = RelativeDateTimeFormatter()
            formatter.unitsStyle = .full
            return formatter.localizedString(for: self, relativeTo: Date())
        }
    }
}
