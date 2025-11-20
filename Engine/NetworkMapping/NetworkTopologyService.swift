// 
//  [NetworkTopologyService].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

protocol NetworkTopologyService {
    func generateTopology(from hosts: [DiscoveredHost]) -> NetworkTopologyGraph
}

final class DefaultNetworkTopologyService: NetworkTopologyService {
    private let interfaceService: NetworkInterfaceProviding
    private let gatewayResolver: GatewayResolving

    init(
        interfaceService: NetworkInterfaceProviding = SystemNetworkInterfaceService(),
        gatewayResolver: GatewayResolving = DefaultGatewayResolver()
    ) {
        self.interfaceService = interfaceService
        self.gatewayResolver = gatewayResolver
    }

    func generateTopology(from hosts: [DiscoveredHost]) -> NetworkTopologyGraph {
        var hostsByIP = Dictionary(uniqueKeysWithValues: hosts.map { ($0.ipAddress, $0) })

        let interfaces = interfaceService.fetchInterfaces()
        let gateways = gatewayResolver.resolveGateways()

        var localNodesByInterface: [String: DiscoveredHost] = [:]
        for interface in interfaces where interface.isUp && !interface.isLoopback {
            guard let address = interface.address else { continue }
            var node = hostsByIP[address] ?? DiscoveredHost(
                ipAddress: address,
                hostName: "Local (\(interface.name))",
                lastSeen: Date(),
                services: [],
                macAddress: nil,
                interfaceName: interface.name
            )
            node = node.updatingNetworkDetails(macAddress: node.macAddress, interfaceName: interface.name)
            if node.hostName == nil {
                node = node.updatingHostName("Local (\(interface.name))")
            }
            hostsByIP[address] = node
            localNodesByInterface[interface.name] = node
        }

        var gatewayNodesByInterface: [String: DiscoveredHost] = [:]
        for gateway in gateways {
            guard let local = localNodesByInterface[gateway.interfaceName] else { continue }
            var node = hostsByIP[gateway.gatewayIP] ?? DiscoveredHost(
                ipAddress: gateway.gatewayIP,
                hostName: "Gateway (\(gateway.interfaceName))",
                lastSeen: Date(),
                services: [],
                macAddress: nil,
                interfaceName: gateway.interfaceName
            )
            if node.hostName == nil {
                node = node.updatingHostName("Gateway (\(gateway.interfaceName))")
            }
            node = node.updatingNetworkDetails(macAddress: node.macAddress, interfaceName: gateway.interfaceName)
            hostsByIP[gateway.gatewayIP] = node
            gatewayNodesByInterface[gateway.interfaceName] = node

            if node.id != local.id {
                hostsByIP[local.ipAddress] = local
            }
        }

        var edges = Set<NetworkTopologyGraph.Edge>()
        let hostList = hostsByIP.values.sorted { lhs, rhs in
            lhs.ipAddress < rhs.ipAddress
        }
        let idByIP = Dictionary(uniqueKeysWithValues: hostList.map { ($0.ipAddress, $0.id) })

        for host in hosts {
            guard let hostID = idByIP[host.ipAddress] else { continue }

            if let interface = host.interfaceName,
               let localNode = localNodesByInterface[interface],
               let localID = idByIP[localNode.ipAddress],
               localID != hostID {
                edges.insert(NetworkTopologyGraph.Edge(
                    source: localID,
                    target: hostID,
                    relationship: "arp"
                ))
            }

            if let interface = host.interfaceName,
               let gatewayNode = gatewayNodesByInterface[interface],
               let gatewayID = idByIP[gatewayNode.ipAddress],
               gatewayID != hostID {
                edges.insert(NetworkTopologyGraph.Edge(
                    source: gatewayID,
                    target: hostID,
                    relationship: "gateway"
                ))
            }
        }

        for (interface, gatewayNode) in gatewayNodesByInterface {
            guard let localNode = localNodesByInterface[interface],
                  let localID = idByIP[localNode.ipAddress],
                  let gatewayID = idByIP[gatewayNode.ipAddress],
                  localID != gatewayID else { continue }
            edges.insert(NetworkTopologyGraph.Edge(
                source: localID,
                target: gatewayID,
                relationship: "uplink"
            ))
        }

        return NetworkTopologyGraph(
            nodes: hostList,
            edges: Array(edges)
        )
    }
}
