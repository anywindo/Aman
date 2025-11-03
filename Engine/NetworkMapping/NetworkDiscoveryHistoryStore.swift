//
//  NetworkDiscoveryHistoryStore.swift
//  Aman
//
//  Persists host discovery history and computes deltas between snapshots.
//

import Foundation

protocol NetworkDiscoveryHistoryManaging {
    func loadHosts() -> [DiscoveredHost]
    func saveHosts(_ hosts: [DiscoveredHost])
    func computeDelta(newHosts: [DiscoveredHost]) -> NetworkDiscoveryDelta
}

final class NetworkDiscoveryHistoryStore: NetworkDiscoveryHistoryManaging {
    private let storeURL: URL
    private var cache: [DiscoveredHost] = []

    init(fileManager: FileManager = .default, storeFileName: String = "network_discovery_history.json") {
        let documents = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())
        storeURL = documents.appendingPathComponent(storeFileName)
        cache = loadHosts()
    }

    func loadHosts() -> [DiscoveredHost] {
        guard let data = try? Data(contentsOf: storeURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([DiscoveredHost].self, from: data)) ?? []
    }

    func saveHosts(_ hosts: [DiscoveredHost]) {
        cache = hosts
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(hosts) else { return }
        try? FileManager.default.createDirectory(
            at: storeURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: storeURL, options: [.atomic])
    }

    func computeDelta(newHosts: [DiscoveredHost]) -> NetworkDiscoveryDelta {
        let previous = cache
        let previousByIP = Dictionary(uniqueKeysWithValues: previous.map { ($0.ipAddress, $0) })
        let newByIP = Dictionary(uniqueKeysWithValues: newHosts.map { ($0.ipAddress, $0) })

        let added = newHosts.filter { previousByIP[$0.ipAddress] == nil }

        let updated = newHosts.compactMap { host -> DiscoveredHost? in
            guard let old = previousByIP[host.ipAddress] else { return nil }
            return old != host ? host : nil
        }

        let removed = previous.filter { newByIP[$0.ipAddress] == nil }

        return NetworkDiscoveryDelta(added: added, updated: updated, removed: removed)
    }
}
