//
//  NetworkMappingModels.swift
//  Aman
//
//  Shared model objects for Network Mapping.
//

import Foundation

struct DiscoveredHost: Identifiable, Hashable, Codable {
    struct ServiceSummary: Hashable, Codable {
        let port: UInt16
        let protocolName: String
        let product: String?
        let version: String?
    }

    let id: UUID
    let ipAddress: String
    let hostName: String?
    let lastSeen: Date
    let services: [ServiceSummary]
    let macAddress: String?
    let interfaceName: String?
    let lastPortScanAt: Date?
    let lastPortScanMode: PortScanMode?

    init(
        id: UUID = UUID(),
        ipAddress: String,
        hostName: String? = nil,
        lastSeen: Date = Date(),
        services: [ServiceSummary] = [],
        macAddress: String? = nil,
        interfaceName: String? = nil,
        lastPortScanAt: Date? = nil,
        lastPortScanMode: PortScanMode? = nil
    ) {
        self.id = id
        self.ipAddress = ipAddress
        self.hostName = hostName
        self.lastSeen = lastSeen
        self.services = services
        self.macAddress = macAddress
        self.interfaceName = interfaceName
        self.lastPortScanAt = lastPortScanAt
        self.lastPortScanMode = lastPortScanMode
    }

    func updatingPorts(_ ports: [DiscoveredPort], mode: PortScanMode, timestamp: Date = Date()) -> DiscoveredHost {
        let summaries = ports.map {
            ServiceSummary(
                port: $0.port,
                protocolName: $0.transportProtocol.rawValue,
                product: $0.service?.product,
                version: $0.service?.version
            )
        }
        return DiscoveredHost(
            id: id,
            ipAddress: ipAddress,
            hostName: hostName,
            lastSeen: Date(),
            services: summaries,
            macAddress: macAddress,
            interfaceName: interfaceName,
            lastPortScanAt: timestamp,
            lastPortScanMode: mode
        )
    }

    func updatingHostName(_ hostName: String?) -> DiscoveredHost {
        DiscoveredHost(
            id: id,
            ipAddress: ipAddress,
            hostName: hostName ?? self.hostName,
            lastSeen: lastSeen,
            services: services,
            macAddress: self.macAddress,
            interfaceName: self.interfaceName,
            lastPortScanAt: lastPortScanAt,
            lastPortScanMode: lastPortScanMode
        )
    }

    func updatingLastSeen(_ lastSeen: Date) -> DiscoveredHost {
        DiscoveredHost(
            id: id,
            ipAddress: ipAddress,
            hostName: hostName,
            lastSeen: lastSeen,
            services: services,
            macAddress: macAddress,
            interfaceName: interfaceName,
            lastPortScanAt: lastPortScanAt,
            lastPortScanMode: lastPortScanMode
        )
    }

    func updatingNetworkDetails(macAddress: String?, interfaceName: String?) -> DiscoveredHost {
        DiscoveredHost(
            id: id,
            ipAddress: ipAddress,
            hostName: hostName,
            lastSeen: lastSeen,
            services: services,
            macAddress: macAddress ?? self.macAddress,
            interfaceName: interfaceName ?? self.interfaceName,
            lastPortScanAt: lastPortScanAt,
            lastPortScanMode: lastPortScanMode
        )
    }
}

struct DiscoveredPort: Identifiable, Hashable, Codable {
    struct ServiceDescriptor: Hashable, Codable {
        let product: String?
        let version: String?
        let extraInfo: String?
    }

    enum TransportProtocol: String, Codable {
        case tcp
        case udp
    }

    let id: UUID
    let port: UInt16
    let transportProtocol: TransportProtocol
    let state: PortScanState
    let service: ServiceDescriptor?

    init(
        id: UUID = UUID(),
        port: UInt16,
        transportProtocol: TransportProtocol,
        state: PortScanState,
        service: ServiceDescriptor? = nil
    ) {
        self.id = id
        self.port = port
        self.transportProtocol = transportProtocol
        self.state = state
        self.service = service
    }
}

enum PortScanState: String, Codable {
    case open
    case closed
    case filtered
    case unknown
}

struct NetworkTopologyGraph: Codable {
    struct Edge: Hashable, Codable {
        let source: UUID
        let target: UUID
        let relationship: String
    }

    let nodes: [DiscoveredHost]
    let edges: [Edge]

    static let empty = NetworkTopologyGraph(nodes: [], edges: [])
}

struct NetworkDiscoveryDelta: Codable {
    let added: [DiscoveredHost]
    let updated: [DiscoveredHost]
    let removed: [DiscoveredHost]

    var isEmpty: Bool {
        added.isEmpty && updated.isEmpty && removed.isEmpty
    }
}

enum PortScanMode: String, Codable, CaseIterable {
    case connect
    case syn

    var displayName: String {
        switch self {
        case .connect:
            return "Standard (Connect)"
        case .syn:
            return "Enhanced (SYN)"
        }
    }

    var requiresPrivileges: Bool {
        switch self {
        case .connect:
            return false
        case .syn:
            return true
        }
    }
}

struct PortScannerConfiguration {
    let ports: [UInt16]
    let timeout: TimeInterval
    let maxConcurrency: Int

    static let `default` = PortScannerConfiguration(
        ports: Self.commonPorts,
        timeout: 1.25,
        maxConcurrency: 32
    )

    private static let commonPorts: [UInt16] = [
        21, 22, 23, 25, 53, 80, 110, 123, 135, 137,
        138, 139, 143, 161, 162, 389, 443, 445, 465,
        500, 514, 520, 587, 593, 623, 631, 636, 860,
        902, 912, 989, 990, 993, 995, 1025, 1026, 1027,
        1030, 1433, 1521, 1723, 2049, 2082, 2083, 2181,
        2483, 2484, 3128, 3260, 3306, 3389, 3690, 4333,
        4443, 4500, 4567, 5000, 5060, 5432, 5671, 5672,
        5900, 5985, 5986, 6379, 6666, 7001, 7002, 7170,
        7180, 8080, 8081, 8443, 8500, 8888, 9000, 9001,
        9090, 9200, 9300, 9418, 11211, 27017, 50051
    ]
}

struct PortScanProgressUpdate {
    let completed: Int
    let total: Int
    let currentPort: UInt16?
    let mode: PortScanMode
    let timestamp: Date

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(completed) / Double(total)
    }
}

struct PortScanJobState {
    enum Status {
        case idle
        case running(PortScanProgressUpdate)
        case completed(Date)
        case failed(String)
        case cancelled
    }

    var status: Status
    var mode: PortScanMode
    var lastPorts: [DiscoveredPort]
    var lastError: String?
    var lastRunAt: Date?

    static func idle(mode: PortScanMode) -> PortScanJobState {
        PortScanJobState(
            status: .idle,
            mode: mode,
            lastPorts: [],
            lastError: nil,
            lastRunAt: nil
        )
    }
}

struct PortScanHistoryEntry: Codable {
    let ipAddress: String
    let ports: [DiscoveredPort]
    let mode: PortScanMode
    let completedAt: Date
}
