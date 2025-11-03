//
//  NetworkMappingExportManager.swift
//  Aman
//
//  Handles serialization of discovery snapshots and topology graphs into exportable formats.
//

import Foundation

protocol NetworkMappingExportManaging {
    func export(snapshot: NetworkMappingExportSnapshot, kind: NetworkMappingExportKind, to destinationURL: URL) async throws -> URL
}

struct NetworkMappingExportSnapshot {
    let generatedAt: Date
    let hosts: [DiscoveredHost]
    let topology: NetworkTopologyGraph
}

enum NetworkMappingExportKind: CaseIterable {
    case jsonSnapshot
    case hostsCSV
    case topologyDOT
    case topologyMermaid

    var suggestedFileName: String {
        switch self {
        case .jsonSnapshot:
            return "network-mapping-snapshot.json"
        case .hostsCSV:
            return "network-mapping-hosts.csv"
        case .topologyDOT:
            return "network-topology.dot"
        case .topologyMermaid:
            return "network-topology.mmd"
        }
    }
}

enum NetworkMappingExportError: LocalizedError {
    case emptySnapshot
    case failedToEncode
    case writeFailed

    var errorDescription: String? {
        switch self {
        case .emptySnapshot:
            return "Nothing to export yet. Run a discovery sweep first."
        case .failedToEncode:
            return "Unable to serialize the export payload."
        case .writeFailed:
            return "Failed to write export file to the selected location."
        }
    }
}

struct NetworkMappingExportManager: NetworkMappingExportManaging {
    private let metadataFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()

    func export(snapshot: NetworkMappingExportSnapshot, kind: NetworkMappingExportKind, to destinationURL: URL) async throws -> URL {
        guard !snapshot.hosts.isEmpty else {
            throw NetworkMappingExportError.emptySnapshot
        }

        return try await Task.detached(priority: .userInitiated) {
            switch kind {
            case .jsonSnapshot:
                let data = try makeJSONPayload(from: snapshot)
                try write(data: data, to: destinationURL)
                return destinationURL
            case .hostsCSV:
                let csv = makeHostsCSV(from: snapshot)
                try write(string: csv, to: destinationURL)
                return destinationURL
            case .topologyDOT:
                let dot = makeDOT(from: snapshot)
                try write(string: dot, to: destinationURL)
                return destinationURL
            case .topologyMermaid:
                let mermaid = makeMermaid(from: snapshot)
                try write(string: mermaid, to: destinationURL)
                return destinationURL
            }
        }.value
    }

    // MARK: - JSON

    private func makeJSONPayload(from snapshot: NetworkMappingExportSnapshot) throws -> Data {
        let metadata = ExportMetadata(
            generatedAt: metadataFormatter.string(from: snapshot.generatedAt),
            hostCount: snapshot.hosts.count,
            edgeCount: snapshot.topology.edges.count
        )
        let payload = ExportJSONPayload(metadata: metadata, hosts: snapshot.hosts, topology: snapshot.topology)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(payload) else {
            throw NetworkMappingExportError.failedToEncode
        }
        return data
    }

    // MARK: - CSV

    private func makeHostsCSV(from snapshot: NetworkMappingExportSnapshot) -> String {
        var rows: [String] = []
        rows.reserveCapacity(snapshot.hosts.count + 1)

        rows.append("ip_address,host_name,mac_address,interface,last_seen,port,protocol,service_product,service_version")

        let dateFormatter = metadataFormatter
        for host in snapshot.hosts.sorted(by: { $0.ipAddress < $1.ipAddress }) {
            let commonColumns = [
                host.ipAddress.csvEscaped(),
                (host.hostName ?? "").csvEscaped(),
                (host.macAddress ?? "").csvEscaped(),
                (host.interfaceName ?? "").csvEscaped(),
                dateFormatter.string(from: host.lastSeen).csvEscaped()
            ]

            if host.services.isEmpty {
                rows.append((commonColumns + Array(repeating: "", count: 4)).joined(separator: ","))
                continue
            }

            for service in host.services {
                let row = commonColumns + [
                    "\(service.port)".csvEscaped(),
                    service.protocolName.uppercased().csvEscaped(),
                    (service.product ?? "").csvEscaped(),
                    (service.version ?? "").csvEscaped()
                ]
                rows.append(row.joined(separator: ","))
            }
        }

        return rows.joined(separator: "\n")
    }

    // MARK: - DOT

    private func makeDOT(from snapshot: NetworkMappingExportSnapshot) -> String {
        let hosts = snapshot.hosts
        let edges = snapshot.topology.edges
        var result: [String] = []
        result.append("digraph NetworkTopology {")
        result.append("  graph [splines=true, overlap=false];")
        result.append("  node [shape=circle, style=filled, fontname=\"Helvetica\"];")

        let nodeEntries = hosts.map { host -> String in
            let labelComponents = [
                host.ipAddress,
                host.hostName
            ].compactMap { $0 }.joined(separator: "\\n")
            let color: String
            if let name = host.hostName?.lowercased(), name.contains("gateway") {
                color = "#ff9f0a"
            } else if let name = host.hostName?.lowercased(), name.contains("local") {
                color = "#0a84ff"
            } else {
                color = "#6c6c70"
            }
            return "  \"\(host.id.uuidString)\" [label=\"\(labelComponents)\", fillcolor=\"\(color)\"];"
        }
        result.append(contentsOf: nodeEntries)

        let relationshipStyles: [String: String] = [
            "uplink": "[color=\"#0a84ff\", penwidth=2.4]",
            "gateway": "[color=\"#ff9f0a\", penwidth=2.0]",
            "arp": "[color=\"#6c6c70\", penwidth=1.4, style=dashed]"
        ]

        for edge in edges {
            let style = relationshipStyles[edge.relationship, default: ""]
            result.append("  \"\(edge.source.uuidString)\" -> \"\(edge.target.uuidString)\" \(style);")
        }

        result.append("}")
        return result.joined(separator: "\n")
    }

    // MARK: - Mermaid

    private func makeMermaid(from snapshot: NetworkMappingExportSnapshot) -> String {
        var lines: [String] = []
        lines.append("graph TD")

        let hosts = snapshot.hosts
        let edges = snapshot.topology.edges

        for host in hosts {
            let labelComponents = [
                host.ipAddress,
                host.hostName
            ].compactMap { $0 }
            let label = labelComponents.joined(separator: "<br>")
            lines.append("    \(host.id.uuidString.replacingOccurrences(of: "-", with: "_"))[\"\(label)\"]")
        }

        for edge in edges {
            let relationshipLabel = edge.relationship.uppercased()
            let source = edge.source.uuidString.replacingOccurrences(of: "-", with: "_")
            let target = edge.target.uuidString.replacingOccurrences(of: "-", with: "_")
            lines.append("    \(source) -->|\(relationshipLabel)| \(target)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Write Helpers

    private func write(data: Data, to url: URL) throws {
        do {
            try data.write(to: url, options: [.atomic])
        } catch {
            throw NetworkMappingExportError.writeFailed
        }
    }

    private func write(string: String, to url: URL) throws {
        guard let data = string.data(using: .utf8) else {
            throw NetworkMappingExportError.failedToEncode
        }
        try write(data: data, to: url)
    }
}

private struct ExportJSONPayload: Codable {
    let metadata: ExportMetadata
    let hosts: [DiscoveredHost]
    let topology: NetworkTopologyGraph
}

private struct ExportMetadata: Codable {
    let generatedAt: String
    let hostCount: Int
    let edgeCount: Int
}

private extension String {
    func csvEscaped() -> String {
        if isEmpty {
            return ""
        }
        let needsQuotes = contains(",") || contains("\"") || contains("\n")
        if needsQuotes {
            let escaped = replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return self
    }
}
