//
//  InternetSecurityToolkit.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation
import SystemConfiguration
struct InternetSecurityCheckResult: Identifiable {
    enum Status: String {
        case pass
        case warning
        case fail
        case info
        case error
    }

    enum Kind: String, CaseIterable, Identifiable {
        case dnsLeak
        case ipExposure
        case ipv6Leak
        case firewall
        case proxy

        var id: String { rawValue }

        var title: String {
            switch self {
            case .dnsLeak: return "DNS Leak Detection"
            case .ipExposure: return "IP & GeoIP Exposure"
            case .ipv6Leak: return "IPv6 Leak Monitoring"
            case .firewall: return "Firewall Audit & Stealth"
            case .proxy: return "Proxy & VPN Configuration"
            }
        }

        var summary: String {
            switch self {
            case .dnsLeak: return "Checks resolver paths to confirm DNS queries remain inside trusted tunnels."
            case .ipExposure: return "Profiles external network presence with GeoIP and ASN context."
            case .ipv6Leak: return "Validates IPv6 interfaces so tunnels do not leak traffic."
            case .firewall: return "Audits macOS firewall posture, stealth mode, and exposed listeners."
            case .proxy: return "Captures system proxy and VPN state to spot misconfigurations."
            }
        }
    }

    struct Detail: Identifiable {
        let id = UUID()
        let label: String
        let value: String
    }

    let id = UUID()
    let kind: Kind
    let status: Status
    let headline: String
    let details: [Detail]
    let notes: [String]
    let startedAt: Date
    let finishedAt: Date

    var duration: TimeInterval {
        finishedAt.timeIntervalSince(startedAt)
    }
}

final class InternetSecurityToolkit {
    private struct IPInfoResponse: Decodable {
        let ip: String
        let city: String?
        let region: String?
        let country: String?
        let org: String?
        let loc: String?
    }

    fileprivate enum ToolkitError: LocalizedError {
        case commandMissing(String)
        case timeout
        case resolutionFailed(String)
        case unexpectedResponse

        var errorDescription: String? {
            switch self {
            case .commandMissing(let command):
                return "Unable to locate command \(command)."
            case .timeout:
                return "The request timed out."
            case .resolutionFailed(let host):
                return "Could not resolve host \(host)."
            case .unexpectedResponse:
                return "Unexpected response received."
            }
        }
    }

    private let shellRunner: ShellCommandRunning
    private let session: URLSession

    init(
        session: URLSession = InternetSecurityToolkit.makeDefaultSession(),
        shellRunner: ShellCommandRunning = ProcessShellRunner()
    ) {
        self.session = session
        self.shellRunner = shellRunner
    }

    func runAllChecks() async -> [InternetSecurityCheckResult] {
        var results: [InternetSecurityCheckResult] = []
        var context = ToolkitContext()

        for kind in InternetSecurityCheckResult.Kind.allCases {
            let result = await run(kind: kind, context: &context)
            results.append(result)
        }

        return results
    }

    func run(kind: InternetSecurityCheckResult.Kind) async -> InternetSecurityCheckResult {
        var context = ToolkitContext()
        return await run(kind: kind, context: &context)
    }

    private func run(
        kind: InternetSecurityCheckResult.Kind,
        context: inout ToolkitContext
    ) async -> InternetSecurityCheckResult {
        let started = Date()

        do {
            let evaluation: ToolkitEvaluation
            switch kind {
            case .dnsLeak:
                evaluation = try await evaluateDNSLeak(context: &context)
            case .ipExposure:
                evaluation = try await evaluateIPExposure(context: &context)
            case .ipv6Leak:
                evaluation = try await evaluateIPv6Leak(context: &context)
            case .firewall:
                evaluation = try evaluateFirewallState()
            case .proxy:
                evaluation = try evaluateProxyAndVPN(context: &context)
            }

            return InternetSecurityCheckResult(
                kind: kind,
                status: evaluation.status,
                headline: evaluation.headline,
                details: evaluation.details,
                notes: evaluation.notes,
                startedAt: started,
                finishedAt: Date()
            )
        } catch {
            return InternetSecurityCheckResult(
                kind: kind,
                status: .error,
                headline: error.localizedDescription,
                details: [],
                notes: [],
                startedAt: started,
                finishedAt: Date()
            )
        }
    }
}

// MARK: - Evaluation Helpers

private struct ToolkitContext {
    var dnsServers: [String]?
    var vpnInterfaces: [VPNInterface]?
    var ipv6Addresses: [IPv6AddressInfo]?
    var ipMetadata: IPMetadata?
    var proxySnapshot: ProxySnapshot?
}

private struct IPMetadata {
    let address: String
    let geoSummary: String
    let organization: String?
    let location: String?
}

private struct VPNInterface {
    let name: String
    let isActive: Bool
}

private struct IPv6AddressInfo {
    let interface: String
    let address: String
    let scope: String
}

private struct ProxySnapshot {
    let httpProxy: String?
    let httpsProxy: String?
    let socksProxy: String?
    let pacURL: String?
    let proxiesEnabled: Bool
    let rawDictionary: [String: Any]
}

private struct ToolkitEvaluation {
    let status: InternetSecurityCheckResult.Status
    let headline: String
    let details: [InternetSecurityCheckResult.Detail]
    let notes: [String]
}

// MARK: - Individual Checks

private extension InternetSecurityToolkit {
    func evaluateDNSLeak(context: inout ToolkitContext) async throws -> ToolkitEvaluation {
        if context.dnsServers == nil {
            context.dnsServers = try fetchDNSServers()
        }
        if context.vpnInterfaces == nil {
            context.vpnInterfaces = try detectVPNInterfaces()
        }

        let dnsServers = context.dnsServers ?? []
        let vpnInterfaces = context.vpnInterfaces ?? []
        let vpnActive = vpnInterfaces.contains { $0.isActive }

        guard !dnsServers.isEmpty else {
            return ToolkitEvaluation(
                status: .warning,
                headline: "No DNS resolvers were discovered in the current configuration.",
                details: [],
                notes: ["DNS queries may fail or fall back to ISP defaults."]
            )
        }

        let publicResolvers = dnsServers.filter { !Self.isPrivateIPAddress($0) }
        var notes: [String] = []

        if vpnActive && !publicResolvers.isEmpty {
            let activeNames = vpnInterfaces.filter { $0.isActive }.map(\.name).joined(separator: ", ")
            notes.append("Active VPN interfaces: \(activeNames).")
            notes.append("Resolvers include public IPs which may bypass the VPN tunnel.")
            return ToolkitEvaluation(
                status: .fail,
                headline: "Potential DNS leak detected.",
                details: dnsServers.map { .init(label: "Resolver", value: $0) },
                notes: notes
            )
        }

        if publicResolvers.isEmpty {
            return ToolkitEvaluation(
                status: vpnActive ? .pass : .info,
                headline: vpnActive ? "No DNS leak indicators detected." : "Resolvers appear private; no VPN detected.",
                details: dnsServers.map { .init(label: "Resolver", value: $0) },
                notes: notes
            )
        }

        notes.append("Resolvers include public endpoints. Verify that they belong to the VPN provider.")
        return ToolkitEvaluation(
            status: .warning,
            headline: "Mixed DNS resolver configuration observed.",
            details: dnsServers.map { .init(label: "Resolver", value: $0) },
            notes: notes
        )
    }

    func evaluateIPExposure(context: inout ToolkitContext) async throws -> ToolkitEvaluation {
        if context.ipMetadata == nil {
            context.ipMetadata = try await fetchIPMetadata()
        }

        guard let metadata = context.ipMetadata else {
            return ToolkitEvaluation(
                status: .error,
                headline: "Unable to determine external IP address.",
                details: [],
                notes: []
            )
        }

        var details: [InternetSecurityCheckResult.Detail] = [
            .init(label: "External IP", value: metadata.address),
            .init(label: "Geo", value: metadata.geoSummary)
        ]
        if let org = metadata.organization {
            details.append(.init(label: "ASN/Org", value: org))
        }
        if let loc = metadata.location {
            details.append(.init(label: "Coordinates", value: loc))
        }

        return ToolkitEvaluation(
            status: .info,
            headline: "Traffic exits via \(metadata.geoSummary).",
            details: details,
            notes: []
        )
    }

    func evaluateIPv6Leak(context: inout ToolkitContext) async throws -> ToolkitEvaluation {
        if context.ipv6Addresses == nil {
            context.ipv6Addresses = try inspectIPv6Addresses()
        }
        if context.vpnInterfaces == nil {
            context.vpnInterfaces = try detectVPNInterfaces()
        }

        let ipv6Addresses = context.ipv6Addresses ?? []
        let vpnInterfaces = context.vpnInterfaces ?? []
        let vpnNames = Set(vpnInterfaces.map(\.name))

        guard !ipv6Addresses.isEmpty else {
            return ToolkitEvaluation(
                status: .pass,
                headline: "No globally routable IPv6 addresses detected.",
                details: [],
                notes: []
            )
        }

        let nonVPNAddresses = ipv6Addresses.filter { !vpnNames.contains($0.interface) }
        let detailRows = ipv6Addresses.map {
            InternetSecurityCheckResult.Detail(label: "\($0.interface) (\($0.scope))", value: $0.address)
        }

        if !nonVPNAddresses.isEmpty && vpnInterfaces.contains(where: { $0.isActive }) {
            return ToolkitEvaluation(
                status: .fail,
                headline: "IPv6 traffic may bypass the VPN tunnel.",
                details: detailRows,
                notes: ["Interfaces outside the tunnel: \(nonVPNAddresses.map(\.interface).joined(separator: ", "))."]
            )
        }

        return ToolkitEvaluation(
            status: .info,
            headline: "IPv6 connectivity present—confirm VPN support.",
            details: detailRows,
            notes: []
        )
    }

    func evaluateFirewallState() throws -> ToolkitEvaluation {
        let socketfilterPath = "/usr/libexec/ApplicationFirewall/socketfilterfw"
        guard FileManager.default.isExecutableFile(atPath: socketfilterPath) else {
            throw ToolkitError.commandMissing(socketfilterPath)
        }

        let stateResult = try shellRunner.run(
            executableURL: URL(fileURLWithPath: socketfilterPath),
            arguments: ["--getglobalstate"]
        )
        let stealthResult = try shellRunner.run(
            executableURL: URL(fileURLWithPath: socketfilterPath),
            arguments: ["--getstealthmode"]
        )
        let netstatResult = try shellRunner.run(
            executableURL: URL(fileURLWithPath: "/usr/sbin/netstat"),
            arguments: ["-anp", "tcp"]
        )

        let firewallEnabled = stateResult.stdout.contains("(State = 1)") || stateResult.stdout.localizedCaseInsensitiveContains("enabled")
        let stealthEnabled = stealthResult.stdout.localizedCaseInsensitiveContains("enabled")

        let listeningSockets = netstatResult.stdout
            .components(separatedBy: .newlines)
            .filter { $0.contains("LISTEN") && !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let details: [InternetSecurityCheckResult.Detail] = [
            .init(label: "Firewall", value: firewallEnabled ? "Enabled" : "Disabled"),
            .init(label: "Stealth Mode", value: stealthEnabled ? "Enabled" : "Disabled"),
            .init(label: "Listening Ports", value: "\(listeningSockets.count)")
        ]

        var notes: [String] = []
        if !listeningSockets.isEmpty {
            notes.append("Sample listening entries: \(listeningSockets.prefix(5).joined(separator: " / "))")
            if listeningSockets.count > 5 {
                notes.append("Additional \(listeningSockets.count - 5) listener(s) not shown.")
            }
        }

        if firewallEnabled && stealthEnabled {
            return ToolkitEvaluation(
                status: .pass,
                headline: "Firewall and stealth mode are enabled.",
                details: details,
                notes: notes
            )
        }

        if !firewallEnabled {
            return ToolkitEvaluation(
                status: .fail,
                headline: "macOS Application Firewall is disabled.",
                details: details,
                notes: notes
            )
        }

        return ToolkitEvaluation(
            status: .warning,
            headline: "Firewall enabled but stealth mode is disabled.",
            details: details,
            notes: notes
        )
    }

    func evaluateProxyAndVPN(context: inout ToolkitContext) throws -> ToolkitEvaluation {
        if context.vpnInterfaces == nil {
            context.vpnInterfaces = try detectVPNInterfaces()
        }
        if context.proxySnapshot == nil {
            context.proxySnapshot = try captureProxySnapshot()
        }

        let vpnInterfaces = context.vpnInterfaces ?? []
        let snapshot = context.proxySnapshot
        let vpnActive = vpnInterfaces.contains { $0.isActive }
        let activeVPNNames = vpnInterfaces.filter { $0.isActive }.map(\.name)

        var details: [InternetSecurityCheckResult.Detail] = []
        details.append(.init(label: "Active VPN", value: vpnActive ? activeVPNNames.joined(separator: ", ") : "None detected"))

        if let snapshot {
            details.append(.init(label: "Proxies Enabled", value: snapshot.proxiesEnabled ? "Yes" : "No"))
            if let http = snapshot.httpProxy { details.append(.init(label: "HTTP Proxy", value: http)) }
            if let https = snapshot.httpsProxy { details.append(.init(label: "HTTPS Proxy", value: https)) }
            if let socks = snapshot.socksProxy { details.append(.init(label: "SOCKS Proxy", value: socks)) }
            if let pac = snapshot.pacURL { details.append(.init(label: "PAC URL", value: pac)) }
        }

        var notes: [String] = []
        var status: InternetSecurityCheckResult.Status = .info
        var headline = vpnActive ? "VPN interface detected." : "No active VPN interface found."

        if let snapshot {
            let noHostsConfigured = snapshot.httpProxy == nil && snapshot.httpsProxy == nil && snapshot.socksProxy == nil && snapshot.pacURL == nil
            if snapshot.proxiesEnabled && noHostsConfigured {
                status = .warning
                headline = "Proxy flags enabled without explicit proxy hosts."
                notes.append("System network settings may leak traffic due to inconsistent proxy configuration.")
            }
        } else {
            notes.append("Unable to read system proxy settings.")
        }

        if !vpnActive {
            status = .warning
            notes.append("Consider enabling a VPN before running leak detection checks.")
        }

        return ToolkitEvaluation(
            status: status,
            headline: headline,
            details: details,
            notes: notes
        )
    }

}

// MARK: - System Queries

private extension InternetSecurityToolkit {
    func fetchDNSServers() throws -> [String] {
        let scutilPath = "/usr/sbin/scutil"
        guard FileManager.default.isExecutableFile(atPath: scutilPath) else {
            throw ToolkitError.commandMissing(scutilPath)
        }

        let result = try shellRunner.run(executableURL: URL(fileURLWithPath: scutilPath), arguments: ["--dns"])
        let lines = result.stdout.components(separatedBy: .newlines)
        var servers: [String] = []

        for line in lines {
            guard let range = line.range(of: "nameserver") else { continue }
            let suffix = line[range.upperBound...]
            if let ipStart = suffix.range(of: ":")?.upperBound {
                let candidate = suffix[ipStart...].trimmingCharacters(in: .whitespaces)
                if !candidate.isEmpty {
                    servers.append(candidate)
                }
            }
        }

        return Array(Set(servers))
    }

    func detectVPNInterfaces() throws -> [VPNInterface] {
        let ifconfigPath = "/sbin/ifconfig"
        guard FileManager.default.isExecutableFile(atPath: ifconfigPath) else {
            throw ToolkitError.commandMissing(ifconfigPath)
        }
        let result = try shellRunner.run(
            executableURL: URL(fileURLWithPath: ifconfigPath),
            arguments: []
        )

        let vpnCandidatePrefixes = ["utun", "ppp", "ipsec", "tap", "tun"]
        let lines = result.stdout.components(separatedBy: .newlines)

        var interfaces: [VPNInterface] = []
        var currentName: String?
        var currentIsCandidate = false
        var currentActive = false

        func flushCurrent() {
            guard let name = currentName, currentIsCandidate else { return }
            interfaces.append(VPNInterface(name: name, isActive: currentActive))
        }

        for rawLine in lines {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if !rawLine.hasPrefix("\t") && !rawLine.hasPrefix(" ") {
                flushCurrent()

                let name = rawLine.components(separatedBy: ":").first ?? trimmed
                currentName = name

                let lowerName = name.lowercased()
                currentIsCandidate = vpnCandidatePrefixes.contains { lowerName.hasPrefix($0) } || lowerName.contains("vpn")
                let flagsSection = rawLine.split(separator: "<").dropFirst().first?.split(separator: ">").first ?? Substring()
                currentActive = flagsSection.contains("UP") && flagsSection.contains("RUNNING")
            } else if currentIsCandidate {
                let lowercased = trimmed.lowercased()
                if lowercased.hasPrefix("status:") {
                    currentActive = lowercased.contains("active")
                } else if lowercased.contains("inactive") {
                    currentActive = false
                }
            }
        }

        flushCurrent()
        return interfaces
    }

    func inspectIPv6Addresses() throws -> [IPv6AddressInfo] {
        let ifconfigPath = "/sbin/ifconfig"
        guard FileManager.default.isExecutableFile(atPath: ifconfigPath) else {
            throw ToolkitError.commandMissing(ifconfigPath)
        }

        let result = try shellRunner.run(
            executableURL: URL(fileURLWithPath: ifconfigPath),
            arguments: []
        )

        var addresses: [IPv6AddressInfo] = []
        var currentInterface: String?

        for rawLine in result.stdout.components(separatedBy: .newlines) {
            if rawLine.isEmpty { continue }

            if !rawLine.hasPrefix("\t") && !rawLine.hasPrefix(" ") {
                currentInterface = rawLine.components(separatedBy: ":").first
                continue
            }

            guard let interface = currentInterface else { continue }
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.hasPrefix("inet6 ") else { continue }

            let components = trimmed
                .components(separatedBy: .whitespaces)
                .filter { !$0.isEmpty }

            guard components.count >= 2 else { continue }
            let addressToken = components[1]
            let address = addressToken.split(separator: "%").first.map(String.init) ?? addressToken

            let scope: String
            if address == "::1" {
                scope = "loopback"
            } else if address.hasPrefix("fe80") {
                scope = "link-local"
            } else if address.hasPrefix("fd") || address.hasPrefix("fc") {
                scope = "unique-local"
            } else {
                scope = "global"
            }

            addresses.append(IPv6AddressInfo(interface: interface, address: address, scope: scope))
        }

        return addresses
    }

    func fetchIPMetadata() async throws -> IPMetadata {
        guard let url = URL(string: "https://ipinfo.io/json") else {
            throw ToolkitError.unexpectedResponse
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse, (200..<300).contains(httpResponse.statusCode) else {
            throw ToolkitError.unexpectedResponse
        }

        let decoder = JSONDecoder()
        let decoded = try decoder.decode(IPInfoResponse.self, from: data)
        guard !decoded.ip.isEmpty else {
            throw ToolkitError.unexpectedResponse
        }

        let geoComponents = [decoded.city, decoded.region, decoded.country].compactMap { $0 }.filter { !$0.isEmpty }
        let geoSummary = geoComponents.isEmpty ? "Unknown location" : geoComponents.joined(separator: ", ")

        return IPMetadata(
            address: decoded.ip,
            geoSummary: geoSummary,
            organization: decoded.org?.isEmpty == false ? decoded.org : nil,
            location: decoded.loc?.isEmpty == false ? decoded.loc : nil
        )
    }

    func captureProxySnapshot() throws -> ProxySnapshot {
        guard let proxiesCF = SCDynamicStoreCopyProxies(nil) else {
            throw ToolkitError.unexpectedResponse
        }

        guard let dict = proxiesCF as? [String: Any] else {
            throw ToolkitError.unexpectedResponse
        }

        func numericValue(for key: CFString) -> Int? {
            if let value = dict[key as String] as? NSNumber {
                return value.intValue
            }
            if let value = dict[key as String] as? Int {
                return value
            }
            return nil
        }

        func boolValue(for key: CFString) -> Bool {
            (numericValue(for: key) ?? 0) == 1
        }

        func hostValue(hostKey: CFString, portKey: CFString) -> String? {
            guard let host = dict[hostKey as String] as? String, !host.isEmpty else { return nil }
            if let port = numericValue(for: portKey), port > 0 {
                return "\(host):\(port)"
            }
            return host
        }

        let httpProxy = hostValue(hostKey: kCFNetworkProxiesHTTPProxy, portKey: kCFNetworkProxiesHTTPPort)
        let httpsProxy = hostValue(hostKey: kCFNetworkProxiesHTTPSProxy, portKey: kCFNetworkProxiesHTTPSPort)
        let socksProxy = hostValue(hostKey: kCFNetworkProxiesSOCKSProxy, portKey: kCFNetworkProxiesSOCKSPort)
        let pacURL = dict[kCFNetworkProxiesProxyAutoConfigURLString as String] as? String

        let proxiesEnabled = boolValue(for: kCFNetworkProxiesHTTPEnable)
            || boolValue(for: kCFNetworkProxiesHTTPSEnable)
            || boolValue(for: kCFNetworkProxiesSOCKSEnable)
            || boolValue(for: kCFNetworkProxiesProxyAutoConfigEnable)
            || boolValue(for: kCFNetworkProxiesProxyAutoDiscoveryEnable)

        return ProxySnapshot(
            httpProxy: httpProxy,
            httpsProxy: httpsProxy,
            socksProxy: socksProxy,
            pacURL: pacURL,
            proxiesEnabled: proxiesEnabled,
            rawDictionary: dict
        )
    }
}

// MARK: - Public/Internal helpers usable by other files

extension InternetSecurityToolkit {
    static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 15
        configuration.timeoutIntervalForResource = 30
        configuration.waitsForConnectivity = true
        return URLSession(configuration: configuration)
    }

    static func isPrivateIPAddress(_ address: String) -> Bool {
        let trimmed = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }

        if trimmed.contains(":") {
            let lower = trimmed.lowercased()
            if lower == "::1" { return true }
            if lower.hasPrefix("fe80") { return true }
            if lower.hasPrefix("fd") || lower.hasPrefix("fc") { return true }
            return false
        }

        let octets = trimmed.split(separator: ".").compactMap { Int($0) }
        guard octets.count == 4 else { return false }

        switch octets[0] {
        case 10:
            return true
        case 172:
            return octets[1] >= 16 && octets[1] <= 31
        case 192:
            return octets[1] == 168
        case 127:
            return true
        case 169:
            return octets[1] == 254
        default:
            return false
        }
    }
}
