// 
//  [NetworkInterfaceService].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation
import Darwin

struct NetworkInterfaceSnapshot {
    let name: String
    let address: String?
    let netmask: String?
    let isUp: Bool
    let isLoopback: Bool
}

protocol NetworkInterfaceProviding {
    func fetchInterfaces() -> [NetworkInterfaceSnapshot]
}

final class SystemNetworkInterfaceService: NetworkInterfaceProviding {
    func fetchInterfaces() -> [NetworkInterfaceSnapshot] {
        var addressPointer: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addressPointer) == 0, let head = addressPointer else {
            return []
        }

        defer {
            freeifaddrs(addressPointer)
        }

        var snapshots: [String: NetworkInterfaceSnapshot] = [:]

        var pointer: UnsafeMutablePointer<ifaddrs>? = head
        while let interface = pointer?.pointee {
            let name = String(cString: interface.ifa_name)
            let flags = Int32(interface.ifa_flags)
            let isUp = (flags & IFF_UP) == IFF_UP
            let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK

            var address: String? = snapshots[name]?.address
            var netmask: String? = snapshots[name]?.netmask

            if let addr = interface.ifa_addr, addr.pointee.sa_family == UInt8(AF_INET) {
                address = ipv4String(from: addr)
            }

            if let mask = interface.ifa_netmask, mask.pointee.sa_family == UInt8(AF_INET) {
                netmask = ipv4String(from: mask)
            }

            snapshots[name] = NetworkInterfaceSnapshot(
                name: name,
                address: address,
                netmask: netmask,
                isUp: isUp,
                isLoopback: isLoopback
            )

            pointer = interface.ifa_next
        }

        return snapshots.values.sorted { lhs, rhs in
            lhs.name < rhs.name
        }
    }

    private func ipv4String(from sockaddrPointer: UnsafePointer<sockaddr>) -> String? {
        var address = sockaddrPointer.pointee
        return withUnsafePointer(to: &address) { ptr -> String? in
            ptr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { addrIn -> String? in
                var sinAddr = addrIn.pointee.sin_addr
                var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard inet_ntop(AF_INET, &sinAddr, &buffer, socklen_t(INET_ADDRSTRLEN)) != nil else {
                    return nil
                }
                return String(cString: buffer)
            }
        }
    }
}

struct GatewayInfo: Equatable {
    let interfaceName: String
    let gatewayIP: String
}

protocol GatewayResolving {
    func resolveGateways() -> [GatewayInfo]
}

final class DefaultGatewayResolver: GatewayResolving {
    private let shell: ShellCommandRunning

    init(shell: ShellCommandRunning = ProcessShellRunner()) {
        self.shell = shell
    }

    func resolveGateways() -> [GatewayInfo] {
        guard let output = try? shell.run(
            executableURL: URL(fileURLWithPath: "/usr/sbin/netstat"),
            arguments: ["-rn"]
        ).stdout else {
            return []
        }

        var gateways: [GatewayInfo] = []
        var isIPv4Section = false

        for rawLine in output.split(separator: "\n") {
            var line = rawLine.trimmingCharacters(in: .whitespaces)
            if line.isEmpty { continue }

            if line == "Internet:" {
                isIPv4Section = true
                continue
            }
            if line == "Internet6:" {
                isIPv4Section = false
                continue
            }
            guard isIPv4Section else { continue }

            let tokens = line.split(whereSeparator: { $0 == " " || $0 == "\t" })
            guard tokens.count >= 6 else { continue }

            let destination = tokens[0]
            if destination != "default" && destination != "0.0.0.0" {
                continue
            }

            let gateway = String(tokens[1])
            let interface = String(tokens[5])
            let info = GatewayInfo(interfaceName: interface, gatewayIP: gateway)
            if !gateways.contains(info) {
                gateways.append(info)
            }
        }

        return gateways
    }
}
