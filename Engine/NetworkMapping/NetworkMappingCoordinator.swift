//
//  NetworkMappingCoordinator.swift
//  Aman
//
//  Coordinates discovery, topology, and port scan tasks for the Network Mapping feature.
//

import Combine
import Foundation

@MainActor
final class NetworkMappingCoordinator: ObservableObject {
    @Published private(set) var hosts: [DiscoveredHost] = []
    @Published private(set) var topology: NetworkTopologyGraph = .empty
    @Published private(set) var isDiscoveryRunning = false
    @Published private(set) var lastDiscoveryDelta: NetworkDiscoveryDelta?
    @Published private(set) var portScanJobs: [String: PortScanJobState] = [:]
    @Published var portScanMode: PortScanMode = .connect
    @Published private(set) var topologySelectionIPAddress: String?
    @Published var highlightedHostIPAddress: String?
    @Published private(set) var sampleLoadError: String?
    @Published private(set) var isSampleDatasetActive = false
    @Published private(set) var exportStatus: NetworkMappingExportStatus = .idle

    let discoveryDeltaPublisher: AnyPublisher<NetworkDiscoveryDelta, Never>

    private let discoveryService: NetworkDiscoveryService
    private let topologyService: NetworkTopologyService
    private let portScanService: NetworkPortScanService
    private let portScanHistoryStore: NetworkPortScanHistoryManaging
    private let portScanLogger = NetworkScanLogger.shared
    private let portScanConfiguration: PortScannerConfiguration
    private var portScanTasks: [String: Task<Void, Never>] = [:]
    private let exportManager: NetworkMappingExportManaging
    private var exportTask: Task<Void, Never>?
    private let deltaSubject = PassthroughSubject<NetworkDiscoveryDelta, Never>()

    nonisolated init(
        discoveryService: NetworkDiscoveryService = DefaultNetworkDiscoveryService(),
        topologyService: NetworkTopologyService = DefaultNetworkTopologyService(),
        portScanService: NetworkPortScanService = DefaultNetworkPortScanService(),
        portScanHistoryStore: NetworkPortScanHistoryManaging = NetworkPortScanHistoryStore(),
        portScanConfiguration: PortScannerConfiguration = .default,
        exportManager: NetworkMappingExportManaging = NetworkMappingExportManager()
    ) {
        self.discoveryService = discoveryService
        self.topologyService = topologyService
        self.portScanService = portScanService
        self.portScanHistoryStore = portScanHistoryStore
        self.portScanConfiguration = portScanConfiguration
        self.exportManager = exportManager
        discoveryDeltaPublisher = deltaSubject.eraseToAnyPublisher()
    }

    func startDiscovery() {
        guard !isDiscoveryRunning else { return }
        isDiscoveryRunning = true
        isSampleDatasetActive = false

        Task {
            do {
                let snapshot = try await discoveryService.enumerateNetwork()
                await update(with: snapshot)
            } catch {
                // TODO: surface error to the UI once we have a place to show it.
            }
            isDiscoveryRunning = false
        }
    }

    func refreshTopology() {
        guard !isSampleDatasetActive else { return }
        Task {
            let latestGraph = topologyService.generateTopology(from: hosts)
            topology = latestGraph
        }
    }

    func runTargetedPortScan(for host: DiscoveredHost) {
        let ipAddress = host.ipAddress
        portScanTasks[ipAddress]?.cancel()

        let mode = portScanMode
        let totalPorts = portScanConfiguration.ports.count
        portScanLogger.log(event: .scanStarted(ip: ipAddress, mode: mode, totalPorts: totalPorts))

        var jobState = portScanJobs[ipAddress] ?? .idle(mode: mode)
        jobState.status = .running(
            PortScanProgressUpdate(
                completed: 0,
                total: totalPorts,
                currentPort: nil,
                mode: mode,
                timestamp: Date()
            )
        )
        jobState.lastError = nil
        portScanJobs[ipAddress] = jobState

        let task = Task {
            let start = Date()
            do {
                let ports = try await portScanService.scan(
                    host: host,
                    mode: mode,
                    configuration: portScanConfiguration
                ) { [weak self] update in
                    guard let self else { return }
                    Task { @MainActor [weak self] in
                        guard let self else { return }
                        var state = self.portScanJobs[ipAddress] ?? .idle(mode: mode)
                        state.status = .running(update)
                        self.portScanJobs[ipAddress] = state
                    }
                }

                let timestamp = Date()
                let entry = PortScanHistoryEntry(
                    ipAddress: ipAddress,
                    ports: ports,
                    mode: mode,
                    completedAt: timestamp
                )
                portScanHistoryStore.save(entry: entry)
                portScanLogger.log(event: .scanCompleted(ip: ipAddress, duration: timestamp.timeIntervalSince(start), openPorts: ports.count))

                await mergePorts(ports, into: host, mode: mode, timestamp: timestamp)
                await updatePortScanJobState(
                    ipAddress: ipAddress,
                    status: .completed(timestamp),
                    ports: ports,
                    mode: mode,
                    error: nil,
                    lastRunAt: timestamp
                )
            } catch is CancellationError {
                portScanLogger.log(event: .scanCancelled(ip: ipAddress))
                await updatePortScanJobState(
                    ipAddress: ipAddress,
                    status: .cancelled,
                    ports: jobState.lastPorts,
                    mode: mode,
                    error: nil,
                    lastRunAt: jobState.lastRunAt
                )
            } catch let error as PortScanError {
                let message: String
                switch error {
                case .modeRequiresPrivileges:
                    message = "Enhanced SYN mode requires elevated privileges."
                }
                portScanLogger.log(event: .scanFailed(ip: ipAddress, message: message))
                await updatePortScanJobState(
                    ipAddress: ipAddress,
                    status: .failed(message),
                    ports: jobState.lastPorts,
                    mode: mode,
                    error: message,
                    lastRunAt: jobState.lastRunAt
                )
            } catch {
                let message = error.localizedDescription
                portScanLogger.log(event: .scanFailed(ip: ipAddress, message: message))
                await updatePortScanJobState(
                    ipAddress: ipAddress,
                    status: .failed(message),
                    ports: jobState.lastPorts,
                    mode: mode,
                    error: message,
                    lastRunAt: jobState.lastRunAt
                )
            }
        }

        portScanTasks[ipAddress] = task
    }

    func cancelPortScan(for host: DiscoveredHost) {
        let ipAddress = host.ipAddress
        portScanTasks[ipAddress]?.cancel()
        portScanTasks[ipAddress] = nil
    }

    func jobState(for host: DiscoveredHost) -> PortScanJobState? {
        portScanJobs[host.ipAddress]
    }

    func handleTopologySelection(ipAddress: String) {
        topologySelectionIPAddress = ipAddress
        highlightedHostIPAddress = ipAddress
    }

    func loadSampleData() {
        sampleLoadError = nil
        guard let url = Bundle.main.url(forResource: "network_mapping_sample", withExtension: "json") else {
            sampleLoadError = "Unable to locate bundled sample dataset."
            return
        }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let sample = try decoder.decode(NetworkMappingSample.self, from: data)
            applySample(sample)
        } catch {
            isSampleDatasetActive = false
            sampleLoadError = "Failed to load sample dataset."
        }
    }

    private func update(with snapshot: NetworkDiscoverySnapshot) async {
        isSampleDatasetActive = false
        hosts = applyPortHistory(to: snapshot.hosts)
        topology = topologyService.generateTopology(from: hosts)
        lastDiscoveryDelta = snapshot.delta
        if !snapshot.delta.isEmpty {
            deltaSubject.send(snapshot.delta)
        }
    }

    private func mergePorts(_ ports: [DiscoveredPort], into host: DiscoveredHost, mode: PortScanMode, timestamp: Date) async {
        var updatedHosts = hosts
        if let index = updatedHosts.firstIndex(where: { $0.ipAddress == host.ipAddress }) {
            let updated = updatedHosts[index].updatingPorts(ports, mode: mode, timestamp: timestamp)
            updatedHosts[index] = updated
            hosts = updatedHosts
        }
    }

    private func updatePortScanJobState(
        ipAddress: String,
        status: PortScanJobState.Status,
        ports: [DiscoveredPort],
        mode: PortScanMode,
        error: String?,
        lastRunAt: Date?
    ) async {
        var state = portScanJobs[ipAddress] ?? .idle(mode: mode)
        state.status = status
        state.mode = mode
        state.lastPorts = ports
        state.lastError = error
        state.lastRunAt = lastRunAt
        portScanJobs[ipAddress] = state
        portScanTasks[ipAddress] = nil
    }

    private func applyPortHistory(to hosts: [DiscoveredHost]) -> [DiscoveredHost] {
        hosts.map { host in
            if let entry = portScanHistoryStore.latestEntry(for: host.ipAddress) {
                portScanJobs[host.ipAddress] = PortScanJobState(
                    status: .completed(entry.completedAt),
                    mode: entry.mode,
                    lastPorts: entry.ports,
                    lastError: nil,
                    lastRunAt: entry.completedAt
                )
                return host.updatingPorts(entry.ports, mode: entry.mode, timestamp: entry.completedAt)
            } else {
                if portScanJobs[host.ipAddress] == nil {
                    portScanJobs[host.ipAddress] = .idle(mode: portScanMode)
                }
                return host
            }
        }
    }

    private func applySample(_ sample: NetworkMappingSample) {
        isDiscoveryRunning = false
        highlightedHostIPAddress = nil
        topologySelectionIPAddress = nil

        let delta = NetworkDiscoveryDelta(added: sample.hosts, updated: [], removed: [])
        hosts = sample.hosts
        topology = sample.topology
        lastDiscoveryDelta = delta
        isSampleDatasetActive = true

        portScanJobs = Dictionary(uniqueKeysWithValues: sample.hosts.map { host in
            let ports = host.services.map { summary -> DiscoveredPort in
                let protocolName = summary.protocolName.lowercased()
                let transport = DiscoveredPort.TransportProtocol(rawValue: protocolName) ?? .tcp
                let descriptor = DiscoveredPort.ServiceDescriptor(
                    product: summary.product,
                    version: summary.version,
                    extraInfo: nil
                )
                return DiscoveredPort(
                    port: summary.port,
                    transportProtocol: transport,
                    state: .open,
                    service: descriptor
                )
            }
            let mode = host.lastPortScanMode ?? .connect
            let status: PortScanJobState.Status
            if let timestamp = host.lastPortScanAt {
                status = .completed(timestamp)
            } else {
                status = .idle
            }
            return (
                host.ipAddress,
                PortScanJobState(
                    status: status,
                    mode: mode,
                    lastPorts: ports,
                    lastError: nil,
                    lastRunAt: host.lastPortScanAt
                )
            )
        })

        deltaSubject.send(delta)
        sampleLoadError = nil
    }

    func export(kind: NetworkMappingExportKind, to destinationURL: URL) {
        exportTask?.cancel()
        exportStatus = .running(kind)

        let snapshot = NetworkMappingExportSnapshot(
            generatedAt: Date(),
            hosts: hosts,
            topology: topology
        )

        let manager = exportManager
        exportTask = Task { [weak self] in
            guard let self else { return }
            do {
                let url = try await manager.export(snapshot: snapshot, kind: kind, to: destinationURL)
                await MainActor.run {
                    self.exportStatus = .completed(kind, url, Date())
                    self.exportTask = nil
                }
            } catch is CancellationError {
                await MainActor.run {
                    self.exportStatus = .idle
                    self.exportTask = nil
                }
            } catch {
                await MainActor.run {
                    self.exportStatus = .failed(kind, error.localizedDescription)
                    self.exportTask = nil
                }
            }
        }
    }

    func resetExportStatus() {
        exportStatus = .idle
    }
}

extension NetworkMappingCoordinator {
    static let shared = NetworkMappingCoordinator()
}

private struct NetworkMappingSample: Codable {
    let hosts: [DiscoveredHost]
    let topology: NetworkTopologyGraph
}

enum NetworkMappingExportStatus: Equatable {
    case idle
    case running(NetworkMappingExportKind)
    case completed(NetworkMappingExportKind, URL, Date)
    case failed(NetworkMappingExportKind, String)
}
