//
//  NetworkSecurityViewModel.swift
//  Aman
//
//  Simplified view model driving the Network Security dashboard.
//

import Combine
import Foundation

@MainActor
final class NetworkSecurityViewModel: ObservableObject {
    @Published private(set) var internetResults: [InternetSecurityCheckResult.Kind: InternetSecurityCheckResult] = [:]
    @Published private(set) var internetRunningChecks: Set<InternetSecurityCheckResult.Kind> = []
    @Published private(set) var isInternetSuiteRunning = false
    @Published private(set) var internetLastError: String?
    @Published private(set) var networkMappingHosts: [DiscoveredHost] = []
    @Published private(set) var lastNetworkDiscoveryDelta: NetworkDiscoveryDelta?
    @Published private(set) var portScanJobs: [String: PortScanJobState] = [:]
    @Published private(set) var currentPortScanMode: PortScanMode = .connect
    @Published private(set) var networkMappingSampleError: String?

    private let toolkit: InternetSecurityToolkit
    private let networkMappingCoordinator: NetworkMappingCoordinator
    private var internetSuiteTask: Task<Void, Never>?
    private var internetCheckTasks: [InternetSecurityCheckResult.Kind: Task<Void, Never>] = [:]
    private var cancellables: Set<AnyCancellable> = []

    init(
        toolkit: InternetSecurityToolkit = InternetSecurityToolkit(),
        networkMappingCoordinator: NetworkMappingCoordinator = .shared
    ) {
        self.toolkit = toolkit
        self.networkMappingCoordinator = networkMappingCoordinator
        observeNetworkMapping()
    }

    func runInternetSuite() {
        guard !isInternetSuiteRunning else { return }
        internetSuiteTask?.cancel()
        cancelIndividualTasks()

        internetSuiteTask = Task { [weak self] in
            await self?.executeInternetSuite()
        }
    }

    func runInternetCheck(_ kind: InternetSecurityCheckResult.Kind) {
        guard !internetRunningChecks.contains(kind) else { return }
        internetCheckTasks[kind]?.cancel()

        internetCheckTasks[kind] = Task { [weak self] in
            await self?.executeInternetCheck(kind: kind)
        }
    }

    func internetResult(for kind: InternetSecurityCheckResult.Kind) -> InternetSecurityCheckResult? {
        internetResults[kind]
    }

    func startNetworkDiscovery() {
        networkMappingCoordinator.startDiscovery()
    }

    func refreshNetworkTopology() {
        networkMappingCoordinator.refreshTopology()
    }

    func coordinatorForNetworkMapping() -> NetworkMappingCoordinator {
        networkMappingCoordinator
    }

    func runPortScan(for host: DiscoveredHost) {
        networkMappingCoordinator.runTargetedPortScan(for: host)
    }

    func cancelPortScan(for host: DiscoveredHost) {
        networkMappingCoordinator.cancelPortScan(for: host)
    }

    func portScanState(for host: DiscoveredHost?) -> PortScanJobState? {
        guard let host else { return nil }
        return portScanJobs[host.ipAddress]
    }

    func setPortScanMode(_ mode: PortScanMode) {
        guard currentPortScanMode != mode else { return }
        networkMappingCoordinator.portScanMode = mode
        currentPortScanMode = mode
    }

    func loadSampleNetworkData() {
        networkMappingCoordinator.loadSampleData()
    }

    @MainActor
    private func cancelIndividualTasks() {
        internetCheckTasks.values.forEach { $0.cancel() }
        internetCheckTasks.removeAll()
    }

    @MainActor
    private func executeInternetSuite() async {
        isInternetSuiteRunning = true
        internetLastError = nil
        internetRunningChecks = Set(InternetSecurityCheckResult.Kind.allCases)

        let results = await toolkit.runAllChecks()
        internetResults = Dictionary(uniqueKeysWithValues: results.map { ($0.kind, $0) })

        isInternetSuiteRunning = false
        internetRunningChecks.removeAll()
        internetSuiteTask = nil
    }

    @MainActor
    private func executeInternetCheck(kind: InternetSecurityCheckResult.Kind) async {
        internetRunningChecks.insert(kind)
        internetLastError = nil

        let result = await toolkit.run(kind: kind)
        internetResults[kind] = result

        internetRunningChecks.remove(kind)
        internetCheckTasks[kind] = nil
    }

    private func observeNetworkMapping() {
        networkMappingCoordinator.$hosts
            .receive(on: DispatchQueue.main)
            .sink { [weak self] hosts in
                self?.networkMappingHosts = hosts
            }
            .store(in: &cancellables)

        networkMappingCoordinator.$lastDiscoveryDelta
            .compactMap { $0 }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] delta in
                self?.lastNetworkDiscoveryDelta = delta
            }
            .store(in: &cancellables)

        networkMappingCoordinator.$portScanJobs
            .receive(on: DispatchQueue.main)
            .sink { [weak self] jobs in
                self?.portScanJobs = jobs
            }
            .store(in: &cancellables)

        networkMappingCoordinator.$portScanMode
            .receive(on: DispatchQueue.main)
            .sink { [weak self] mode in
                self?.currentPortScanMode = mode
            }
            .store(in: &cancellables)

        networkMappingCoordinator.$sampleLoadError
            .receive(on: DispatchQueue.main)
            .sink { [weak self] error in
                self?.networkMappingSampleError = error
            }
            .store(in: &cancellables)
    }
}
