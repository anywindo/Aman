//
//  NetworkProbes.swift
//  Aman
//
//  Provides ARP and ICMP sweep helpers used by discovery service.
//

import Foundation

enum NetworkProbeError: Error {
    case commandFailed(String)
}

protocol ARPScanning {
    func scan() async throws -> [DiscoveredHost]
}

protocol ICMPSweeping {
    func sweep(addresses: [String]) async throws -> [DiscoveredHost]
}

final class DefaultARPScanner: ARPScanning {
    private let shell: ShellCommandRunning

    init(shell: ShellCommandRunning = ProcessShellRunner()) {
        self.shell = shell
    }

    func scan() async throws -> [DiscoveredHost] {
        try await Task.detached(priority: .utility) { () throws -> [DiscoveredHost] in
            let result = try self.shell.run(
                executableURL: URL(fileURLWithPath: "/usr/sbin/arp"),
                arguments: ["-a"]
            )
            guard result.terminationStatus == 0 else {
                throw NetworkProbeError.commandFailed(result.stderr)
            }
            let lines = result.stdout.split(separator: "\n")
            return lines.compactMap { line in
                self.parseARPLine(String(line))
            }
        }.value
    }

    private func parseARPLine(_ line: String) -> DiscoveredHost? {
        // Example: ? (192.168.1.1) at 0:11:22:33:44:55 on en0 ifscope [ethernet]
        guard let addressStart = line.firstIndex(of: "("),
              let addressEnd = line.firstIndex(of: ")"),
              addressStart < addressEnd else {
            return nil
        }
        let ip = String(line[line.index(after: addressStart)..<addressEnd])

        let hostname = line.split(separator: " ").first.flatMap { token -> String? in
            token == "?" ? nil : String(token)
        }

        let mac: String? = {
            guard let atRange = line.range(of: " at "),
                  let onRange = line.range(of: " on ", range: atRange.upperBound..<line.endIndex) else {
                return nil
            }
            let raw = line[atRange.upperBound..<onRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            if raw == "(incomplete)" { return nil }
            return raw.lowercased()
        }()

        let interfaceName: String? = {
            guard let onRange = line.range(of: " on ") else { return nil }
            let afterOn = line[onRange.upperBound...]
            if let spaceIndex = afterOn.firstIndex(where: { $0 == " " }) {
                return String(afterOn[..<spaceIndex])
            } else {
                return String(afterOn)
            }
        }()

        return DiscoveredHost(
            ipAddress: ip,
            hostName: hostname,
            lastSeen: Date(),
            services: [],
            macAddress: mac,
            interfaceName: interfaceName
        )
    }
}

final class DefaultICMPSweeper: ICMPSweeping {
    private let shell: ShellCommandRunning

    init(shell: ShellCommandRunning = ProcessShellRunner()) {
        self.shell = shell
    }

    func sweep(addresses: [String]) async throws -> [DiscoveredHost] {
        let batches = stride(from: 0, to: addresses.count, by: 32).map {
            Array(addresses[$0..<min($0 + 32, addresses.count)])
        }

        var responsive: [DiscoveredHost] = []
        for batch in batches {
            let results = try await withThrowingTaskGroup(of: DiscoveredHost?.self) { group -> [DiscoveredHost] in
                for address in batch {
                    group.addTask {
                        try await self.probe(address: address)
                    }
                }

                var collected: [DiscoveredHost] = []
                for try await host in group {
                    if let host {
                        collected.append(host)
                    }
                }
                return collected
            }
            responsive.append(contentsOf: results)
        }
        return responsive
    }

    private func probe(address: String) async throws -> DiscoveredHost? {
        try await Task.detached(priority: .utility) { () throws -> DiscoveredHost? in
            let result = try self.shell.run(
                executableURL: URL(fileURLWithPath: "/sbin/ping"),
                arguments: ["-c", "1", "-W", "1000", address]
            )
            guard result.terminationStatus == 0,
                  result.stdout.contains("1 packets transmitted"),
                  result.stdout.contains("1 packets received") else { return nil }
            return DiscoveredHost(ipAddress: address, hostName: nil, lastSeen: Date())
        }.value
    }
}
