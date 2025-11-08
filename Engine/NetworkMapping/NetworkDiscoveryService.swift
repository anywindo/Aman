// 
//  [NetworkDiscoveryService].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

struct NetworkDiscoverySnapshot {
    let hosts: [DiscoveredHost]
    let topology: NetworkTopologyGraph
    let delta: NetworkDiscoveryDelta
}

protocol NetworkDiscoveryService {
    func enumerateNetwork() async throws -> NetworkDiscoverySnapshot
}

final class DefaultNetworkDiscoveryService: NetworkDiscoveryService {
    private let arpScanner: ARPScanning
    private let icmpSweeper: ICMPSweeping
    private let historyStore: NetworkDiscoveryHistoryManaging

    init(
        arpScanner: ARPScanning = DefaultARPScanner(),
        icmpSweeper: ICMPSweeping = DefaultICMPSweeper(),
        historyStore: NetworkDiscoveryHistoryManaging = NetworkDiscoveryHistoryStore()
    ) {
        self.arpScanner = arpScanner
        self.icmpSweeper = icmpSweeper
        self.historyStore = historyStore
    }

    func enumerateNetwork() async throws -> NetworkDiscoverySnapshot {
        let previousHosts = historyStore.loadHosts()
        let arpHosts = try await arpScanner.scan()

        let pingTargets = targets(from: arpHosts, previous: previousHosts)
        let icmpHosts = try await icmpSweeper.sweep(addresses: pingTargets)

        let mergedHosts = merge(previous: previousHosts, arpHosts: arpHosts, icmpHosts: icmpHosts)
        let delta = historyStore.computeDelta(newHosts: mergedHosts)
        historyStore.saveHosts(mergedHosts)

        // Topology is currently stubbed; will be enriched during Phase 3.
        return NetworkDiscoverySnapshot(
            hosts: mergedHosts,
            topology: NetworkTopologyGraph(nodes: mergedHosts, edges: []),
            delta: delta
        )
    }

    private func targets(from arpHosts: [DiscoveredHost], previous: [DiscoveredHost]) -> [String] {
        let arpIPs = Set(arpHosts.map(\.ipAddress))
        let previousIPs = Set(previous.map(\.ipAddress))
        return Array(arpIPs.union(previousIPs)).sorted()
    }

    private func merge(
        previous: [DiscoveredHost],
        arpHosts: [DiscoveredHost],
        icmpHosts: [DiscoveredHost]
    ) -> [DiscoveredHost] {
        var merged = Dictionary(uniqueKeysWithValues: previous.map { ($0.ipAddress, $0) })
        let currentIPs = Set(arpHosts.map(\.ipAddress)).union(icmpHosts.map(\.ipAddress))

        for arpHost in arpHosts {
            var existing = merged[arpHost.ipAddress] ?? arpHost
            existing = existing.updatingHostName(arpHost.hostName)
            existing = existing.updatingNetworkDetails(
                macAddress: arpHost.macAddress,
                interfaceName: arpHost.interfaceName
            )
            existing = existing.updatingLastSeen(Date())
            merged[arpHost.ipAddress] = existing
        }

        for icmpHost in icmpHosts {
            var existing = merged[icmpHost.ipAddress] ?? icmpHost
            existing = existing.updatingLastSeen(Date())
            merged[icmpHost.ipAddress] = existing
        }

        merged = merged.filter { currentIPs.contains($0.key) }

        return merged.values.sorted { lhs, rhs in
            lhs.ipAddress < rhs.ipAddress
        }
    }
}
