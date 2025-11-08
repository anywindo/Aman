//
//  NetworkInfoService.swift
//  Aman
//
//  Shared helpers for network metadata, refactored for reuse.
//

import Foundation
import SystemConfiguration
#if canImport(CoreWLAN)
import CoreWLAN
#endif

struct NetworkInfoService {
    struct IPMetadata {
        let address: String
        let geoSummary: String
        let organization: String?
        let location: String?
    }

    struct VPNInterface {
        let name: String
        let isActive: Bool
    }

    struct IPv6AddressInfo {
        let interface: String
        let address: String
        let scope: String
    }

    struct PublicIPResponse: Decodable {
        let ip: String
        let city: String?
        let region: String?
        let country: String?
        let org: String?
        let loc: String?
    }

    // Phase 1 additions
    struct SystemIdentity {
        let hostname: String
        let osVersion: String
        let kernelVersion: String
    }

    struct InterfaceInfo: Identifiable {
        var id: String { name }
        let name: String
        let mac: String?
        let type: String
        let mtu: Int?
        let isDefaultRoute: Bool
    }

    struct FirewallState {
        let enabled: Bool
        let stealthEnabled: Bool
    }

    struct ProxySummary {
        let proxiesEnabled: Bool
        let httpProxy: String?
        let httpsProxy: String?
        let socksProxy: String?
        let pacURL: String?
    }

    // Phase 2 additions
    struct IPv6Detail {
        let privacyEnabled: Bool
        let slaac: Bool
        let dhcpv6: Bool
    }

    struct DHCPLease {
        let leaseStart: Date?
        let leaseExpiry: Date?
        let serverIP: String?
        let clientID: String?
    }

    // Phase 3 additions
    struct RouteEntry: Identifiable {
        let destination: String
        let gateway: String
        let interface: String
        let flags: String
        let metric: String?
        var id: String { "\(destination)->\(gateway)->\(interface)" }
    }

    struct ARPEntry: Identifiable {
        let ip: String
        let mac: String
        let interface: String
        let isPermanent: Bool
        var id: String { "\(ip)->\(mac)->\(interface)" }
    }

    // Phase 4 additions (Wi‑Fi)
    struct WiFiSnapshot {
        let ssid: String?
        let bssid: String?
        let rssi: Int?
        let noise: Int?
        let channel: Int?
        let band: String?
        let txRateMbps: Int?
        let countryCode: String?
        let security: String?
        let interfaceName: String?
        let connectedAt: Date?
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

    // MARK: - Public API

    func fetchIPMetadata() async throws -> IPMetadata {
        guard let url = URL(string: "https://ipinfo.io/json") else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 15

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        let decoded = try JSONDecoder().decode(PublicIPResponse.self, from: data)
        guard !decoded.ip.isEmpty else {
            throw URLError(.cannotDecodeContentData)
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

    func fetchDNSServers() throws -> [String] {
        let scutilPath = "/usr/sbin/scutil"
        guard FileManager.default.isExecutableFile(atPath: scutilPath) else {
            return []
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
            return []
        }
        let result = try shellRunner.run(executableURL: URL(fileURLWithPath: ifconfigPath), arguments: [])

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
            return []
        }
        let result = try shellRunner.run(executableURL: URL(fileURLWithPath: ifconfigPath), arguments: [])

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

            addresses.append(IPv6AddressInfo(interface: interface, address: String(address), scope: scope))
        }

        return addresses
    }

    func defaultGateway() throws -> String? {
        let routePath = "/sbin/route"
        guard FileManager.default.isExecutableFile(atPath: routePath) else {
            return nil
        }
        let result = try shellRunner.run(executableURL: URL(fileURLWithPath: routePath), arguments: ["-n", "get", "default"])
        for line in result.stdout.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("gateway:") {
                return trimmed.components(separatedBy: .whitespaces).last
            }
        }
        return nil
    }

    func httpsReachable() async -> Bool {
        guard let url = URL(string: "https://example.com/") else { return false }
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.timeoutInterval = 8
        do {
            let (_, response) = try await session.data(for: request)
            if let http = response as? HTTPURLResponse {
                return (200..<400).contains(http.statusCode)
            }
            return false
        } catch {
            return false
        }
    }

    static func isPrivateIPAddress(_ address: String) -> Bool {
        InternetSecurityToolkit.isPrivateIPAddress(address)
    }

    // MARK: - Phase 1 Additions

    func systemIdentity() -> SystemIdentity {
        var nameBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        gethostname(&nameBuf, nameBuf.count)
        let hostname = String(cString: nameBuf).trimmingCharacters(in: .whitespacesAndNewlines)

        let osVersion = ProcessInfo.processInfo.operatingSystemVersionString

        var uts = utsname()
        uname(&uts)
        let kernel: String = withUnsafeBytes(of: uts.release) { raw in
            let ptr = raw.bindMemory(to: CChar.self).baseAddress!
            return String(cString: ptr)
        }

        return SystemIdentity(
            hostname: hostname.isEmpty ? Host.current().localizedName ?? "Unknown" : hostname,
            osVersion: osVersion,
            kernelVersion: kernel
        )
    }

    func interfaceInventory(defaultGatewayIP: String?) throws -> [InterfaceInfo] {
        let defaultIface = try defaultRouteInterfaceName()

        let ifconfigPath = "/sbin/ifconfig"
        guard FileManager.default.isExecutableFile(atPath: ifconfigPath) else { return [] }
        let result = try shellRunner.run(executableURL: URL(fileURLWithPath: ifconfigPath), arguments: [])

        var interfaces: [InterfaceInfo] = []
        var currentName: String?
        var currentMAC: String?
        var currentMTU: Int?

        func flush() {
            guard let name = currentName else { return }
            let type = Self.interfaceType(for: name)
            let info = InterfaceInfo(
                name: name,
                mac: currentMAC,
                type: type,
                mtu: currentMTU,
                isDefaultRoute: name == defaultIface
            )
            interfaces.append(info)
            currentName = nil
            currentMAC = nil
            currentMTU = nil
        }

        for raw in result.stdout.components(separatedBy: .newlines) {
            if raw.isEmpty { continue }
            if !raw.hasPrefix("\t") && !raw.hasPrefix(" ") {
                if currentName != nil { flush() }
                currentName = raw.components(separatedBy: ":").first
                continue
            }

            let line = raw.trimmingCharacters(in: .whitespaces)
            if line.hasPrefix("ether ") {
                let mac = line.replacingOccurrences(of: "ether ", with: "").trimmingCharacters(in: .whitespaces)
                if !mac.isEmpty { currentMAC = mac }
            } else if line.contains("mtu ") {
                if let idx = line.range(of: "mtu ")?.upperBound {
                    let rest = line[idx...]
                    let token = rest.split(whereSeparator: { !$0.isNumber }).first.map(String.init) ?? ""
                    if let mtuVal = Int(token) {
                        currentMTU = mtuVal
                    }
                }
            }
        }
        flush()

        return interfaces
    }

    private func defaultRouteInterfaceName() throws -> String? {
        let routePath = "/sbin/route"
        guard FileManager.default.isExecutableFile(atPath: routePath) else {
            return nil
        }
        let result = try shellRunner.run(executableURL: URL(fileURLWithPath: routePath), arguments: ["-n", "get", "default"])
        for line in result.stdout.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("interface:") {
                return trimmed.components(separatedBy: .whitespaces).last
            }
        }
        return nil
    }

    func reverseDNS(of ip: String) async -> String? {
        var hints = addrinfo(ai_flags: AI_NUMERICHOST, ai_family: AF_UNSPEC, ai_socktype: SOCK_STREAM, ai_protocol: 0, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var res: UnsafeMutablePointer<addrinfo>?
        let status = getaddrinfo(ip, nil, &hints, &res)
        guard status == 0, let ai = res?.pointee, let sa = ai.ai_addr else {
            if res != nil { freeaddrinfo(res) }
            return nil
        }
        defer { freeaddrinfo(res) }

        var hostBuf = [CChar](repeating: 0, count: Int(NI_MAXHOST))
        let rc = getnameinfo(sa, socklen_t(sa.pointee.sa_len), &hostBuf, socklen_t(hostBuf.count), nil, 0, NI_NAMEREQD)
        if rc == 0 {
            let name = String(cString: hostBuf).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }
        return nil
    }

    func firewallState() throws -> FirewallState {
        let socketfilterPath = "/usr/libexec/ApplicationFirewall/socketfilterfw"
        guard FileManager.default.isExecutableFile(atPath: socketfilterPath) else {
            return FirewallState(enabled: false, stealthEnabled: false)
        }

        let stateResult = try shellRunner.run(
            executableURL: URL(fileURLWithPath: socketfilterPath),
            arguments: ["--getglobalstate"]
        )
        let stealthResult = try shellRunner.run(
            executableURL: URL(fileURLWithPath: socketfilterPath),
            arguments: ["--getstealthmode"]
        )

        let firewallEnabled = stateResult.stdout.contains("(State = 1)") || stateResult.stdout.localizedCaseInsensitiveContains("enabled")
        let stealthEnabled = stealthResult.stdout.localizedCaseInsensitiveContains("enabled")
        return FirewallState(enabled: firewallEnabled, stealthEnabled: stealthEnabled)
    }

    func proxySummary() throws -> ProxySummary {
        guard let proxiesCF = SCDynamicStoreCopyProxies(nil) else {
            return ProxySummary(proxiesEnabled: false, httpProxy: nil, httpsProxy: nil, socksProxy: nil, pacURL: nil)
        }
        guard let dict = proxiesCF as? [String: Any] else {
            return ProxySummary(proxiesEnabled: false, httpProxy: nil, httpsProxy: nil, socksProxy: nil, pacURL: nil)
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

        return ProxySummary(
            proxiesEnabled: proxiesEnabled,
            httpProxy: httpProxy,
            httpsProxy: httpsProxy,
            socksProxy: socksProxy,
            pacURL: pacURL
        )
    }

    // MARK: - Phase 2 additions

    func fetchIPv6Detail() -> IPv6Detail {
        let privacyEnabled = (readSysctlInt("net.inet6.ip6.use_tempaddr") ?? 0) > 0

        let ifconfigPath = "/sbin/ifconfig"
        let ifconfigOut = (try? shellRunner.run(executableURL: URL(fileURLWithPath: ifconfigPath), arguments: [])).map { $0.stdout } ?? ""

        let lower = ifconfigOut.lowercased()
        let slaac = lower.contains("autoconf")
        let dhcpv6 = lower.contains("dhcp6") || lower.contains("dhcpv6") || lower.contains("managed") || lower.contains("stateful")

        return IPv6Detail(privacyEnabled: privacyEnabled, slaac: slaac, dhcpv6: dhcpv6)
    }

    func fetchDHCPLease(for interface: String) -> DHCPLease? {
        let ipconfig = "/usr/sbin/ipconfig"
        guard FileManager.default.isExecutableFile(atPath: ipconfig) else { return nil }
        guard !interface.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }

        let result = try? shellRunner.run(executableURL: URL(fileURLWithPath: ipconfig), arguments: ["getpacket", interface])
        guard let stdout = result?.stdout, !stdout.isEmpty else { return nil }

        let serverIP = matchValue(in: stdout, key: "server_identifier")
        let clientID = matchValue(in: stdout, key: "client_identifier")
        let leaseTimeStr = matchValue(in: stdout, key: "lease_time")

        var start: Date? = nil
        var expiry: Date? = nil

        if let startStr = matchValue(in: stdout, key: "lease_start_time") {
            start = parseDateFlexible(startStr)
        }
        if let expStr = matchValue(in: stdout, key: "lease_expiration_time") {
            expiry = parseDateFlexible(expStr)
        }

        if (start == nil || expiry == nil), let seconds = leaseTimeStr.flatMap({ Int($0) }) {
            start = start ?? Date()
            expiry = expiry ?? Date(timeIntervalSinceNow: TimeInterval(seconds))
        }

        return DHCPLease(leaseStart: start, leaseExpiry: expiry, serverIP: serverIP, clientID: clientID)
    }

    // MARK: - Phase 3 additions

    func measurePing(host: String, count: Int = 4, interval: Double = 0.25, timeout: Double = 3.0) async throws -> (avgMs: Double?, lossPct: Double) {
        let isIPv6 = host.contains(":")
        let executable = isIPv6 ? "/sbin/ping6" : "/sbin/ping"
        guard FileManager.default.isExecutableFile(atPath: executable) else {
            throw URLError(.fileDoesNotExist)
        }

        let args: [String] = [
            "-c", String(max(1, count)),
            "-i", String(max(0.1, interval)),
            "-W", String(max(1.0, timeout)),
            host
        ]

        let result = try shellRunner.run(executableURL: URL(fileURLWithPath: executable), arguments: args)
        let output = result.stdout + "\n" + result.stderr

        let lossPct: Double = parsePacketLossPercent(output) ?? 100.0
        let avgMs = parseAverageRttMs(output)

        return (avgMs, lossPct)
    }

    func fetchRoutes() throws -> [RouteEntry] {
        let netstat = "/usr/sbin/netstat"
        guard FileManager.default.isExecutableFile(atPath: netstat) else { return [] }
        let result = try shellRunner.run(executableURL: URL(fileURLWithPath: netstat), arguments: ["-rn"])
        let lines = result.stdout.split(whereSeparator: \.isNewline).map(String.init)

        var entries: [RouteEntry] = []
        var inInternetTable = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty { continue }

            if trimmed.lowercased().contains("internet:") || trimmed.lowercased().contains("internet6:") {
                inInternetTable = true
                continue
            }
            if !inInternetTable { continue }

            if trimmed.lowercased().hasPrefix("destination") { continue }

            let cols = trimmed.split(whereSeparator: { $0.isWhitespace }).map(String.init)
            guard cols.count >= 5 else { continue }

            let destination = cols[0]
            let gateway = cols[1]
            let flags = cols[2]
            let iface = cols.count >= 7 ? cols[cols.count - 2] : (cols.count >= 5 ? cols[4] : "")
            let metric: String? = nil

            entries.append(RouteEntry(destination: destination, gateway: gateway, interface: iface, flags: flags, metric: metric))
        }

        return entries
    }

    func fetchARPTable() throws -> [ARPEntry] {
        let arp = "/usr/sbin/arp"
        guard FileManager.default.isExecutableFile(atPath: arp) else { return [] }
        let result = try shellRunner.run(executableURL: URL(fileURLWithPath: arp), arguments: ["-an"])
        let lines = result.stdout.split(whereSeparator: \.isNewline).map(String.init)

        var entries: [ARPEntry] = []
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            guard let ip = matchFirst(in: trimmed, pattern: #"\(([^)]+)\)"#) else { continue }
            let mac = matchFirst(in: trimmed, pattern: #"(([0-9a-f]{1,2}:){5}[0-9a-f]{1,2})"#, options: .caseInsensitive) ?? "incomplete"
            let iface = matchFirst(in: trimmed, pattern: #" on ([^\s]+) "#)?.trimmingCharacters(in: .whitespaces) ?? ""
            let permanent = trimmed.localizedCaseInsensitiveContains("permanent")
            entries.append(ARPEntry(ip: ip, mac: mac, interface: iface, isPermanent: permanent))
        }
        return entries
    }

    // MARK: - Phase 4 additions (Wi‑Fi)

    func fetchWiFiSnapshot() -> WiFiSnapshot? {
        #if os(macOS) && canImport(CoreWLAN)
        // Access the default Wi‑Fi interface
        let client = CWWiFiClient.shared()
        guard let iface = client.interface() else {
            return nil
        }

        let ssid = iface.ssid()
        let bssid = iface.bssid()
        let rssi = iface.rssiValue()
        let noise = iface.noiseMeasurement()
        let channel = iface.wlanChannel()?.channelNumber
        let band = iface.wlanChannel().flatMap { ch -> String in
            switch ch.channelBand {
            case .band2GHz: return "2.4 GHz"
            case .band5GHz: return "5 GHz"
            case .band6GHz: return "6 GHz"
            case .bandUnknown: return "Unrecognizable"
            @unknown default: return "Wi‑Fi"
            }
        }
        let txRate = Int(iface.transmitRate())
        let cc = iface.countryCode()
        let security = String(describing: iface.security()) // CWSecurity enum -> string
        let interfaceName = iface.interfaceName
        // CoreWLAN doesn’t expose connection timestamp; we’ll leave nil for now.
        let connectedAt: Date? = nil

        return WiFiSnapshot(
            ssid: ssid,
            bssid: bssid,
            rssi: rssi,
            noise: noise,
            channel: channel,
            band: band,
            txRateMbps: txRate,
            countryCode: cc,
            security: security,
            interfaceName: interfaceName,
            connectedAt: connectedAt
        )
        #else
        return nil
        #endif
    }

    func detectCaptivePortal() async -> Bool {
        // Best-effort: try an HTTP GET to Apple's known captive portal URL and detect redirects or unexpected body.
        guard let url = URL(string: "http://captive.apple.com/hotspot-detect.html") else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = "GET"
        req.timeoutInterval = 3.0

        do {
            let (data, response) = try await session.data(for: req)
            guard let http = response as? HTTPURLResponse else { return false }
            if (300..<400).contains(http.statusCode) {
                // Redirect likely indicates captive portal
                return true
            }
            // Captive portal page often doesn't contain the expected "Success" body
            let body = String(data: data, encoding: .utf8) ?? ""
            // Apple’s endpoint historically returns a simple success page with "Success"
            if !body.contains("Success") {
                // If HTTPS is OK, likely not captive; otherwise treat as possible captive
                return true
            }
            return false
        } catch {
            // Network failure could be due to captive portal interception
            return true
        }
    }

    func classifyNetworkType(security: String?, ssid: String?) -> String {
        let sec = (security ?? "").lowercased()
        let name = (ssid ?? "").lowercased()

        if sec.contains("enterprise") || sec.contains("8021x") || name.contains("corp") || name.contains("guest") && sec.contains("enterprise") {
            return "Enterprise"
        }
        if name.contains("guest") || name.contains("wifi") || name.contains("free") || name.contains("cafe") || name.contains("public") {
            return "Public"
        }
        return "Home"
    }

    // MARK: - Helpers

    private static func interfaceType(for name: String) -> String {
        let lower = name.lowercased()
        if lower.hasPrefix("en") {
            return "Wi‑Fi/Ethernet"
        } else if lower.hasPrefix("awdl") || lower.hasPrefix("wl") {
            return "Wi‑Fi"
        } else if lower.hasPrefix("utun") || lower.contains("vpn") || lower.hasPrefix("ppp") || lower.hasPrefix("ipsec") || lower.hasPrefix("tap") || lower.hasPrefix("tun") {
            return "VPN"
        } else if lower.hasPrefix("bridge") {
            return "Bridge"
        } else if lower.hasPrefix("lo") {
            return "Loopback"
        }
        return "Interface"
    }

    private func readSysctlInt(_ name: String) -> Int? {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size == MemoryLayout<Int32>.size else { return nil }
        var value: Int32 = 0
        let result = sysctlbyname(name, &value, &size, nil, 0)
        if result == 0 { return Int(value) }
        return nil
    }

    private func matchValue(in text: String, key: String) -> String? {
        let patterns = [
            #"(?mi)^\s*\#(key)\s*=\s*([^\n]+)$"#,
            #"(?mi)^\s*\#(key)\s*:\s*([^\n]+)$"#
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                if let match = regex.firstMatch(in: text, options: [], range: range),
                   match.numberOfRanges >= 3,
                   let r = Range(match.range(at: 2), in: text) {
                    return text[r].trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        return nil
    }

    private func parseDateFlexible(_ raw: String) -> Date? {
        let fmts = [
            "yyyy-MM-dd HH:mm:ss ZZZZZ",
            "yyyy-MM-dd HH:mm:ss",
            "EEE MMM d HH:mm:ss yyyy",
            "EEE MMM d HH:mm:ss zzz yyyy"
        ]
        for f in fmts {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            df.dateFormat = f
            if let d = df.date(from: raw) { return d }
        }
        return nil
    }

    private func parsePacketLossPercent(_ text: String) -> Double? {
        if let regex = try? NSRegularExpression(pattern: #"([0-9]+(?:\.[0-9]+)?)%\s+packet\s+loss"#, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let m = regex.firstMatch(in: text, options: [], range: range),
               let r = Range(m.range(at: 1), in: text) {
                return Double(text[r])
            }
        }
        return nil
    }

    private func parseAverageRttMs(_ text: String) -> Double? {
        if let regex = try? NSRegularExpression(pattern: #"min/avg/max/(?:stddev|mdev)\s*=\s*([0-9\.]+)/([0-9\.]+)/([0-9\.]+)/([0-9\.]+)\s*ms"#, options: .caseInsensitive) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            if let m = regex.firstMatch(in: text, options: [], range: range),
               let r = Range(m.range(at: 2), in: text) {
                return Double(text[r])
            }
        }
        return nil
    }

    private func matchFirst(in text: String, pattern: String, options: NSRegularExpression.Options = []) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              match.numberOfRanges >= 2,
              let r = Range(match.range(at: 1), in: text) else { return nil }
        return String(text[r])
    }
}

