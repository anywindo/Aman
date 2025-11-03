//
//  NetworkPortScanHistoryStore.swift
//  Aman
//
//  Persists targeted port scan results for each host.
//

import Foundation

protocol NetworkPortScanHistoryManaging {
    func latestEntry(for ipAddress: String) -> PortScanHistoryEntry?
    func save(entry: PortScanHistoryEntry)
    func remove(ipAddress: String)
}

final class NetworkPortScanHistoryStore: NetworkPortScanHistoryManaging {
    private let fileURL: URL
    private var cache: [String: PortScanHistoryEntry] = [:]
    private let queue = DispatchQueue(label: "com.aman.network.portscan.history", qos: .utility)

    init(
        fileManager: FileManager = .default,
        fileName: String = "network_port_scan_history.json"
    ) {
        let supportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory())

        fileURL = supportURL.appendingPathComponent(fileName)
        cache = loadFromDisk()
    }

    func latestEntry(for ipAddress: String) -> PortScanHistoryEntry? {
        queue.sync {
            cache[ipAddress]
        }
    }

    func save(entry: PortScanHistoryEntry) {
        queue.async {
            self.cache[entry.ipAddress] = entry
            self.persist()
        }
    }

    func remove(ipAddress: String) {
        queue.async {
            self.cache.removeValue(forKey: ipAddress)
            self.persist()
        }
    }

    private func loadFromDisk() -> [String: PortScanHistoryEntry] {
        guard let data = try? Data(contentsOf: fileURL) else { return [:] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([String: PortScanHistoryEntry].self, from: data)) ?? [:]
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(cache) else { return }

        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: fileURL, options: [.atomic])
        } catch {
            // Persisting history is best-effort; ignore failures for now.
        }
    }
}
