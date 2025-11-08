//
//  NetworkProfileViewModel.swift
//  Aman
//
//  View model to fetch and expose compact network profile information.
//

import Foundation
import Network

@MainActor
final class NetworkProfileViewModel: ObservableObject {
    struct Snapshot {
        // Existing
        var publicIP: String?
        var isp: String?
        var asn: String? // extracted from ISP/org string if present
        var geo: String?
        var latitude: Double?
        var longitude: Double?
        var localIP: String?
        var subnet: String?
        var gateway: String?
        var dnsServers: [String] = []
        var interfaceName: String?
        var interfaceType: String?
        var vpnActive: Bool = false
        var ipv6Enabled: Bool = false
        var httpsReachable: Bool = false
        var lastRefresh: Date = Date()
        var systemUptime: TimeInterval = ProcessInfo.processInfo.systemUptime

        // Phase 1 additions
        var systemHostname: String?
        var osVersion: String?
        var kernelVersion: String?
        var interfaces: [NetworkInfoService.InterfaceInfo] = []
        var defaultRouteInterface: String?
        var reverseDNS: String?
        var firewallEnabled: Bool = false
        var stealthEnabled: Bool = false
        var proxy: NetworkInfoService.ProxySummary?

        // Phase 2 additions
        var ipv6PrivacyEnabled: Bool = false
        var ipv6SLAAC: Bool = false
        var ipv6DHCPv6: Bool = false
        var dhcpLeaseStart: Date?
        var dhcpLeaseExpiry: Date?
        var dhcpServerIP: String?

        // Phase 3 additions
        var gatewayLatencyMs: Int?
        var gatewayLossPct: Int?
        var externalLatencyMs: Int?
        var externalLossPct: Int?
        var routes: [NetworkInfoService.RouteEntry] = []
        var arpTop: [NetworkInfoService.ARPEntry] = []

        // Phase 4 additions
        var wifi: NetworkInfoService.WiFiSnapshot?
        var captivePortal: Bool?
        var connectionTimestamp: Date?
        var networkType: String?

        // Phase 5 additions (Enrichment)
        var geoCity: String?
        var geoRegion: String?
        var geoCountry: String?
        var whoisRegistrationDate: Date?
        var whoisRegistry: String?
        var enrichmentLastUpdated: Date?
    }

    @Published private(set) var snapshot = Snapshot()
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let service: NetworkInfoService
    private var monitor: NWPathMonitor?

    // Phase 5: enrichment service and TTL (45 minutes default)
    private let enrichmentService = EnrichmentService()
    private let enrichmentTTL: TimeInterval = 45 * 60

    init(service: NetworkInfoService = NetworkInfoService()) {
        self.service = service
        Task { await refresh() }
    }

    func refresh() async {
        isLoading = true
        error = nil
        defer { isLoading = false }

        var snap = Snapshot()
        snap.systemUptime = ProcessInfo.processInfo.systemUptime

        async let httpsOK = service.httpsReachable()
        async let ipMetaResult = fetchIPMeta()
        async let dnsResult = fetchDNS()
        async let gatewayResult = fetchGateway()
        async let v6Result = fetchIPv6()
        async let vpnResult = fetchVPN()

        // Identity
        let identity = service.systemIdentity()
        snap.systemHostname = identity.hostname
        snap.osVersion = identity.osVersion
        snap.kernelVersion = identity.kernelVersion

        // Local addressing via getifaddrs
        let (localIP, subnet, ifName, ifType) = Self.primaryInterface()
        snap.localIP = localIP
        snap.subnet = subnet
        snap.interfaceName = ifName
        snap.interfaceType = ifType

        // Await async basics
        let httpsReachable = await httpsOK
        let ipMeta = await ipMetaResult
        let dns = await dnsResult
        let gateway = await gatewayResult
        let ipv6Enabled = await v6Result
        let vpnActive = await vpnResult

        if let meta = ipMeta {
            snap.publicIP = meta.address
            snap.geo = meta.geoSummary
            if let org = meta.organization {
                snap.isp = org
                if let asnToken = org.split(separator: " ").first, asnToken.uppercased().hasPrefix("AS") {
                    snap.asn = String(asnToken)
                }
            }
            if let loc = meta.location {
                let parts = loc.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
                if parts.count == 2, let lat = Double(parts[0]), let lon = Double(parts[1]) {
                    snap.latitude = lat
                    snap.longitude = lon
                }
            }
        }

        snap.dnsServers = dns
        snap.gateway = gateway
        snap.httpsReachable = httpsReachable
        snap.ipv6Enabled = ipv6Enabled
        snap.vpnActive = vpnActive
        snap.lastRefresh = Date()

        // Phase 1: Inventory, firewall, proxy, PTR
        do {
            snap.interfaces = try service.interfaceInventory(defaultGatewayIP: gateway ?? nil)
            snap.defaultRouteInterface = snap.interfaces.first(where: { $0.isDefaultRoute })?.name
        } catch {
            self.error = error.localizedDescription
        }

        do {
            let fw = try service.firewallState()
            snap.firewallEnabled = fw.enabled
            snap.stealthEnabled = fw.stealthEnabled
        } catch {
            self.error = error.localizedDescription
        }

        do {
            let proxy = try service.proxySummary()
            snap.proxy = proxy
        } catch {
            self.error = error.localizedDescription
        }

        if let ip = snap.publicIP {
            let ptr = await service.reverseDNS(of: ip)
            snap.reverseDNS = ptr
        }

        // Phase 2: IPv6 detail + DHCP lease
        let v6Detail = service.fetchIPv6Detail()
        snap.ipv6PrivacyEnabled = v6Detail.privacyEnabled
        snap.ipv6SLAAC = v6Detail.slaac
        snap.ipv6DHCPv6 = v6Detail.dhcpv6

        let leaseIface = snap.defaultRouteInterface ?? ifName
        if let leaseIface, let lease = service.fetchDHCPLease(for: leaseIface) {
            snap.dhcpLeaseStart = lease.leaseStart
            snap.dhcpLeaseExpiry = lease.leaseExpiry
            snap.dhcpServerIP = lease.serverIP
        }

        // Phase 3: Diagnostics
        async let gwPing = measureGatewayPing(gateway: gateway)
        async let extPing = measureExternalPing()
        async let routesResult = fetchRoutes()
        async let arpResult = fetchARP()

        let (gwAvg, gwLoss) = await gwPing
        let (extAvg, extLoss) = await extPing
        let routes = await routesResult
        let arp = await arpResult

        if let avg = gwAvg { snap.gatewayLatencyMs = Int(avg.rounded()) }
        if let loss = gwLoss { snap.gatewayLossPct = Int(loss.rounded()) }
        if let avg = extAvg { snap.externalLatencyMs = Int(avg.rounded()) }
        if let loss = extLoss { snap.externalLossPct = Int(loss.rounded()) }

        snap.routes = Array(routes.prefix(6))
        snap.arpTop = Array(arp.prefix(6))

        // Phase 4: Wi‑Fi snapshot and captive portal
        let wifi = service.fetchWiFiSnapshot()
        snap.wifi = wifi
        snap.connectionTimestamp = wifi?.connectedAt
        snap.captivePortal = await service.detectCaptivePortal()
        snap.networkType = service.classifyNetworkType(security: wifi?.security, ssid: wifi?.ssid)

        // Publish core snapshot
        snapshot = snap

        // Phase 5: Optional Enrichment (off-main, cached with TTL)
        if let ip = snap.publicIP {
            let asn = snap.asn
            Task.detached(priority: .utility) { [weak self] in
                guard let self else { return }
                do {
                    // Check staleness
                    let isFresh: Bool = await MainActor.run {
                        if let updated = self.snapshot.enrichmentLastUpdated {
                            return Date().timeIntervalSince(updated) < self.enrichmentTTL
                        }
                        return false
                    }
                    if isFresh {
                        return
                    }

                    // Geo details (city/region/country) from ipinfo (we already call it, but normalize again for fields)
                    let geo = try await self.enrichmentService.fetchGeoAndASN(publicIP: ip)

                    // RDAP for IP; if it fails or lacks dates, try ASN if available
                    var rdap: EnrichmentService.RDAPResult? = try? await self.enrichmentService.fetchRDAPForIP(publicIP: ip)
                    if (rdap?.registrationDate == nil), let asn = asn {
                        rdap = try? await self.enrichmentService.fetchRDAPForASN(asn: asn)
                    }
                    let rdapResult = rdap // capture immutable value for @Sendable closure

                    await MainActor.run { [geo, rdapResult] in
                        var updated = self.snapshot
                        // Fill geo detail fields if not already set
                        updated.geoCity = geo.city
                        updated.geoRegion = geo.region
                        updated.geoCountry = geo.country
                        if updated.latitude == nil, let lat = geo.lat { updated.latitude = lat }
                        if updated.longitude == nil, let lon = geo.lon { updated.longitude = lon }
                        if updated.isp == nil, let isp = geo.isp { updated.isp = isp }
                        if updated.asn == nil, let asnVal = geo.asn { updated.asn = asnVal }

                        if let rd = rdapResult {
                            updated.whoisRegistrationDate = rd.registrationDate
                            updated.whoisRegistry = rd.registry
                        }
                        updated.enrichmentLastUpdated = Date()
                        self.snapshot = updated
                    }
                } catch {
                    // Non-fatal; record error for visibility but do not overwrite core data
                    await MainActor.run {
                        self.error = error.localizedDescription
                    }
                }
            }
        }
    }

    private func measureGatewayPing(gateway: String?) async -> (Double?, Double?) {
        guard let gw = gateway, !gw.isEmpty else { return (nil, nil) }
        do {
            let (avg, loss) = try await service.measurePing(host: gw, count: 4, interval: 0.25, timeout: 2.0)
            return (avg, loss)
        } catch {
            self.error = error.localizedDescription
            return (nil, nil)
        }
    }

    private func measureExternalPing() async -> (Double?, Double?) {
        do {
            let (avg, loss) = try await service.measurePing(host: "8.8.8.8", count: 4, interval: 0.25, timeout: 2.5)
            return (avg, loss)
        } catch {
            self.error = error.localizedDescription
            return (nil, nil)
        }
    }

    private func fetchRoutes() async -> [NetworkInfoService.RouteEntry] {
        do {
            return try service.fetchRoutes()
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    private func fetchARP() async -> [NetworkInfoService.ARPEntry] {
        do {
            return try service.fetchARPTable()
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    private func fetchIPMeta() async -> NetworkInfoService.IPMetadata? {
        do {
            return try await service.fetchIPMetadata()
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    private func fetchDNS() async -> [String] {
        do {
            return try service.fetchDNSServers()
        } catch {
            self.error = error.localizedDescription
            return []
        }
    }

    private func fetchGateway() async -> String? {
        do {
            return try service.defaultGateway()
        } catch {
            self.error = error.localizedDescription
            return nil
        }
    }

    private func fetchIPv6() async -> Bool {
        do {
            let addrs = try service.inspectIPv6Addresses()
            return addrs.contains { $0.scope == "global" || $0.scope == "unique-local" || $0.scope == "link-local" }
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    private func fetchVPN() async -> Bool {
        do {
            let vpns = try service.detectVPNInterfaces()
            return vpns.contains { $0.isActive }
        } catch {
            self.error = error.localizedDescription
            return false
        }
    }

    // MARK: - Local IP/Subnet via getifaddrs

    private static func primaryInterface() -> (ip: String?, subnet: String?, name: String?, type: String?) {
        var address: String?
        var netmask: String?
        var name: String?
        var type: String?

        var ifaddrPtr: UnsafeMutablePointer<ifaddrs>?
        if getifaddrs(&ifaddrPtr) == 0, let first = ifaddrPtr {
            var ptr: UnsafeMutablePointer<ifaddrs>? = first
            while ptr != nil {
                guard let ifa = ptr?.pointee else { break }
                defer { ptr = ifa.ifa_next }

                let flags = Int32(ifa.ifa_flags)
                let isUp = (flags & IFF_UP) == IFF_UP
                let isRunning = (flags & IFF_RUNNING) == IFF_RUNNING
                let isLoopback = (flags & IFF_LOOPBACK) == IFF_LOOPBACK
                guard isUp && isRunning && !isLoopback else { continue }

                let family = ifa.ifa_addr.pointee.sa_family
                if family == sa_family_t(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    if getnameinfo(ifa.ifa_addr, socklen_t(ifa.ifa_addr.pointee.sa_len), &hostname, socklen_t(hostname.count), nil, 0, NI_NUMERICHOST) == 0 {
                        let ip = String(cString: hostname)
                        if !NetworkInfoService.isPrivateIPAddress(ip) {
                            // Prefer private for "local", skip if public
                        } else {
                            address = ip
                            name = String(cString: ifa.ifa_name)
                            if let net = ifa.ifa_netmask {
                                var maskname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                                if getnameinfo(net, socklen_t(net.pointee.sa_len), &maskname, socklen_t(maskname.count), nil, 0, NI_NUMERICHOST) == 0 {
                                    netmask = String(cString: maskname)
                                }
                            }
                            type = interfaceType(for: name ?? "")
                            break
                        }
                    }
                }
            }
            freeifaddrs(first)
        }
        return (address, netmask, name, type)
    }

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
    
    // MARK: - Background refresh scheduling (Phase 6)

    private var backgroundRefreshTask: Task<Void, Never>?
    private var backgroundCadence: TimeInterval = 0

    func startBackgroundRefresh(cadence: TimeInterval) {
        // Stop any existing loop
        stopBackgroundRefresh()
        guard cadence > 0 else { return }

        backgroundCadence = cadence
        // Run a periodic loop that sleeps between refreshes and avoids overlapping runs
        backgroundRefreshTask = Task(priority: .utility) { [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                // Sleep first to avoid immediate double refresh after user changes cadence
                do {
                    try await Task.sleep(nanoseconds: UInt64(cadence * 1_000_000_000))
                } catch {
                    break
                }
                if Task.isCancelled { break }

                // Avoid overlapping refresh calls
                if !self.isLoading {
                    await self.refresh()
                }
            }
        }
    }

    func stopBackgroundRefresh() {
        backgroundRefreshTask?.cancel()
        backgroundRefreshTask = nil
        backgroundCadence = 0
    }
}

import Darwin

