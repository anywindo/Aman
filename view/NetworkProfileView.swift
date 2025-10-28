//
//  NetworkProfileView.swift
//  Aman
//
//  Compact card UI for user network profile.
//

import SwiftUI

struct NetworkProfileView: View {
    @ObservedObject var viewModel: NetworkProfileViewModel

    @State private var showAllRoutes = false
    @State private var showAllARP = false

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .medium
        return f
    }()

    private static let dhcpDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .short
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let error = viewModel.error {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                        .font(.subheadline)
                        .accessibilityLabel("Error")
                        .accessibilityValue(error)
                }
                
                SectionCard {
                    sectionHeader("Addressing & Connectivity")
                    VStack(alignment: .leading, spacing: 8) {
                        row(icon: "globe", title: "Public IP", value: publicIPDisplay)
                        row(icon: "network", title: "Local IP / Subnet", value: localDisplay)
                        row(icon: "arrow.triangle.branch", title: "Gateway", value: viewModel.snapshot.gateway ?? "—")
                        row(icon: "server.rack", title: "DNS", value: dnsDisplay)
                        row(icon: "building.columns", title: "ISP / ASN", value: ispDisplay)
                        row(icon: "link", title: "IPv6", value: ipv6Display)
                        row(icon: "link.badge.plus", title: "IPv6 Detail", value: ipv6DetailDisplay)
                        row(icon: "clock", title: "DHCP Lease", value: dhcpLeaseDisplay)
                    }
                }
                
                SectionCard {
                    sectionHeader("Security & Exposure")
                    VStack(alignment: .leading, spacing: 8) {
                        row(icon: "lock.shield", title: "Firewall", value: viewModel.snapshot.firewallEnabled ? "Enabled" : "Disabled")
                        row(icon: "eye.trianglebadge.exclamationmark", title: "Stealth Mode", value: viewModel.snapshot.stealthEnabled ? "Enabled" : "Disabled")
                        row(icon: "shield.lefthalf.filled", title: "VPN", value: viewModel.snapshot.vpnActive ? "Active" : "Not active")
                        proxySummaryRow
                    }
                }
                
                SectionCard {
                    sectionHeader("Network Layer Diagnostics")
                    VStack(alignment: .leading, spacing: 8) {
                        row(icon: "wave.3.right", title: "Latency", value: latencyDisplay)
                        row(icon: "gauge", title: "MTU", value: mtuPrimaryDisplay)

                        // Progressive disclosure for Routes
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: "point.topleft.down.curvedto.point.bottomright.up")
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 18)
                                Text("Routes")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if viewModel.snapshot.routes.count > 3 {
                                    Button(showAllRoutes ? "Show less" : "Show more") {
                                        withAnimation { showAllRoutes.toggle() }
                                    }
                                    .buttonStyle(.link)
                                    .accessibilityLabel("Toggle routes list")
                                }
                            }
                            Text(routesDisplay(showAll: showAllRoutes))
                                .font(.body)
                                .lineLimit(showAllRoutes ? nil : 1)
                                .truncationMode(.middle)
                                .accessibilityLabel("Routes")
                                .accessibilityValue(routesDisplay(showAll: true))
                        }

                        // Progressive disclosure for ARP
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: "person.3.sequence")
                                    .foregroundStyle(Color.accentColor)
                                    .frame(width: 18)
                                Text("ARP")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                if viewModel.snapshot.arpTop.count > 3 {
                                    Button(showAllARP ? "Show less" : "Show more") {
                                        withAnimation { showAllARP.toggle() }
                                    }
                                    .buttonStyle(.link)
                                    .accessibilityLabel("Toggle ARP list")
                                }
                            }
                            Text(arpDisplay(showAll: showAllARP))
                                .font(.body)
                                .lineLimit(showAllARP ? nil : 1)
                                .truncationMode(.middle)
                                .accessibilityLabel("ARP table")
                                .accessibilityValue(arpDisplay(showAll: true))
                        }
                    }
                }

                

                SectionCard {
                    sectionHeader("Environment & Metadata")
                    VStack(alignment: .leading, spacing: 8) {
                        row(icon: "wifi", title: "SSID / BSSID", value: ssidBssidDisplay)
                        row(icon: "antenna.radiowaves.left.and.right", title: "Signal / Channel", value: signalChannelDisplay)
                        row(icon: "calendar.badge.clock", title: "Connected", value: connectedDisplay)
                        row(icon: "building.2.fill", title: "Network Type", value: viewModel.snapshot.networkType ?? "—")
                        row(icon: "questionmark.circle", title: "Captive Portal", value: captivePortalDisplay)
                    }
                }
                
                SectionCard {
                    sectionHeader("Interface & System Identity")
                    VStack(alignment: .leading, spacing: 8) {
                        row(icon: "desktopcomputer", title: "Hostname", value: viewModel.snapshot.systemHostname ?? "—")
                        row(icon: "cpu", title: "OS / Kernel", value: osKernelDisplay)
                        row(icon: "arrow.triangle.branch", title: "Default Route", value: viewModel.snapshot.defaultRouteInterface ?? "—")
                        interfacesList
                    }
                }
                
                SectionCard {
                    sectionHeader("Others")
                    VStack(alignment: .leading, spacing: 8) {
                        row(icon: "mappin.and.ellipse", title: "Geo", value: geoDetailDisplay)
                        row(icon: "clock.arrow.2.circlepath", title: "Last Refresh", value: lastRefreshDisplay)
                        row(icon: "gauge.with.dots.needle.67percent", title: "Uptime", value: uptimeDisplay)
                        row(icon: "doc.text.magnifyingglass", title: "WHOIS / Registration", value: whoisDisplay)
                    }
                }
            }
            .padding(20)
        }
        .onAppear {
            // Ensure cadence reflects current VM state if you persist later
            // Default is .off
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Profile")
                    .font(.title2.bold())
                    .accessibilityLabel("Network Profile")
                Text("Summary of your current connection.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Spacer()

            Button {
                Task { await viewModel.refresh() }
            } label: {
                HStack(spacing: 8) {
                    if viewModel.isLoading {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                            .accessibilityLabel("Refreshing")
                    }
                    Text(viewModel.isLoading ? "Refreshing…" : "Refresh")
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 12)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(0.2))
                )
            }
            .buttonStyle(.plain)
            .disabled(viewModel.isLoading)
            .accessibilityLabel("Refresh now")
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .padding(.top, 4)
            .accessibilityLabel(title)
    }

    private func subtleNote(_ text: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "info.circle")
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text(text)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 2)
        .accessibilityLabel("Note")
        .accessibilityValue(text)
    }

    private func row(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(Color.accentColor)
                .frame(width: 18)
                .accessibilityHidden(true)
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .accessibilityLabel(title)
            Spacer()
            Text(value)
                .font(.body)
                .lineLimit(1)
                .truncationMode(.middle)
                .accessibilityValue(value)
        }
        .padding(.vertical, 4)
    }

    // MARK: - Composed rows

    private var interfacesList: some View {
        VStack(alignment: .leading, spacing: 6) {
            if viewModel.snapshot.interfaces.isEmpty {
                subtleNote("No interfaces discovered.")
            } else {
                ForEach(viewModel.snapshot.interfaces) { iface in
                    HStack(spacing: 10) {
                        Image(systemName: iconForInterfaceType(iface.type))
                            .foregroundStyle(Color.accentColor)
                            .frame(width: 18)
                            .accessibilityHidden(true)
                        let defaultMark = iface.isDefaultRoute ? " • default" : ""
                        Text("\(iface.name) (\(iface.type))\(defaultMark)")
                            .font(.subheadline)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            if let mac = iface.mac, !mac.isEmpty {
                                Text(mac.uppercased())
                                    .font(.footnote.monospaced())
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            if let mtu = iface.mtu {
                                Text("MTU \(mtu)")
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                    .accessibilityElement(children: .combine)
                    .accessibilityLabel("\(iface.name) \(iface.type)\(iface.isDefaultRoute ? " default" : "")")
                }
            }
        }
    }

    private var proxySummaryRow: some View {
        let p = viewModel.snapshot.proxy
        let enabled = p?.proxiesEnabled == true
        let summary: String = {
            guard let p else { return "Unavailable" }
            var parts: [String] = []
            if let http = p.httpProxy { parts.append("HTTP \(http)") }
            if let https = p.httpsProxy { parts.append("HTTPS \(https)") }
            if let socks = p.socksProxy { parts.append("SOCKS \(socks)") }
            if let pac = p.pacURL { parts.append("PAC \(pac)") }
            if parts.isEmpty {
                return enabled ? "Enabled (no explicit hosts)" : "Disabled"
            }
            return parts.joined(separator: " • ")
        }()
        return row(icon: "arrow.triangle.2.circlepath", title: "Proxy", value: summary)
    }

    // MARK: - Display helpers

    private var osKernelDisplay: String {
        let os = viewModel.snapshot.osVersion ?? "—"
        let kernel = viewModel.snapshot.kernelVersion ?? "—"
        return "\(os) • Kernel \(kernel)"
    }

    private var publicIPDisplay: String {
        var parts: [String] = []
        if let ip = viewModel.snapshot.publicIP { parts.append(ip) }
        if let ptr = viewModel.snapshot.reverseDNS, !ptr.isEmpty { parts.append(ptr) }
        if parts.isEmpty { return "—" }
        return parts.joined(separator: " • ")
    }

    private var interfaceDisplay: String {
        let name = viewModel.snapshot.interfaceName ?? "—"
        let type = viewModel.snapshot.interfaceType ?? ""
        return type.isEmpty ? name : "\(name) (\(type))"
    }

    private var localDisplay: String {
        let ip = viewModel.snapshot.localIP ?? "—"
        let mask = viewModel.snapshot.subnet ?? "—"
        return "\(ip) / \(mask)"
    }

    private var dnsDisplay: String {
        if viewModel.snapshot.dnsServers.isEmpty { return "—" }
        return viewModel.snapshot.dnsServers.prefix(3).joined(separator: ", ")
    }

    private var ispDisplay: String {
        let isp = viewModel.snapshot.isp ?? "—"
        if let asn = viewModel.snapshot.asn {
            return "\(isp) (\(asn))"
        }
        return isp
    }

    private var ipv6Display: String {
        viewModel.snapshot.ipv6Enabled ? "Enabled" : "Disabled"
    }

    private var ipv6DetailDisplay: String {
        var parts: [String] = []
        if viewModel.snapshot.ipv6PrivacyEnabled { parts.append("Privacy") }
        if viewModel.snapshot.ipv6SLAAC { parts.append("SLAAC") }
        if viewModel.snapshot.ipv6DHCPv6 { parts.append("DHCPv6") }
        return parts.isEmpty ? "—" : parts.joined(separator: " • ")
    }

    private var dhcpLeaseDisplay: String {
        let start = viewModel.snapshot.dhcpLeaseStart.map { NetworkProfileView.dhcpDateFormatter.string(from: $0) }
        let end = viewModel.snapshot.dhcpLeaseExpiry.map { NetworkProfileView.dhcpDateFormatter.string(from: $0) }
        let server = viewModel.snapshot.dhcpServerIP

        var parts: [String] = []
        if let start, let end {
            parts.append("\(start) → \(end)")
        } else if let start {
            parts.append("Start \(start)")
        } else if let end {
            parts.append("Expires \(end)")
        }
        if let server, !server.isEmpty {
            parts.append("Server \(server)")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " • ")
    }

    private var latencyDisplay: String {
        var parts: [String] = []
        if let gwMs = viewModel.snapshot.gatewayLatencyMs {
            let loss = viewModel.snapshot.gatewayLossPct.map { "\($0)%" } ?? "—"
            parts.append("GW \(gwMs) ms (\(loss))")
        }
        if let extMs = viewModel.snapshot.externalLatencyMs {
            let loss = viewModel.snapshot.externalLossPct.map { "\($0)%" } ?? "—"
            parts.append("8.8.8.8 \(extMs) ms (\(loss))")
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " • ")
    }

    private func routesDisplay(showAll: Bool) -> String {
        if viewModel.snapshot.routes.isEmpty { return "—" }
        let list = showAll ? viewModel.snapshot.routes.prefix(50) : viewModel.snapshot.routes.prefix(3)
        let items = list.map { r in
            "\(r.destination) → \(r.gateway) (\(r.interface))"
        }
        let more = (!showAll && viewModel.snapshot.routes.count > 3) ? " +\(viewModel.snapshot.routes.count - 3) more" : ""
        return items.joined(separator: " • ") + more
    }

    private func arpDisplay(showAll: Bool) -> String {
        if viewModel.snapshot.arpTop.isEmpty { return "—" }
        let list = showAll ? viewModel.snapshot.arpTop.prefix(50) : viewModel.snapshot.arpTop.prefix(3)
        let items = list.map { a in
            "\(a.ip) → \(a.mac)"
        }
        let more = (!showAll && viewModel.snapshot.arpTop.count > 3) ? " +\(viewModel.snapshot.arpTop.count - 3) more" : ""
        return items.joined(separator: " • ") + more
    }

    private var lastRefreshDisplay: String {
        NetworkProfileView.dateFormatter.string(from: viewModel.snapshot.lastRefresh)
    }

    private var whoisDisplay: String {
        guard let date = viewModel.snapshot.whoisRegistrationDate else {
            return "—"
        }
        let dateString = NetworkProfileView.dateFormatter.string(from: date)
        if let registry = viewModel.snapshot.whoisRegistry, !registry.isEmpty {
            return "\(dateString) • \(registry)"
        }
        return dateString
    }

    private var uptimeDisplay: String {
        let seconds = Int(viewModel.snapshot.systemUptime)
        let days = seconds / 86400
        let hours = (seconds % 86400) / 3600
        let mins = (seconds % 3600) / 60
        if days > 0 {
            return "\(days)d \(hours)h \(mins)m"
        } else if hours > 0 {
            return "\(hours)h \(mins)m"
        } else {
            return "\(mins)m"
        }
    }

    private var mtuPrimaryDisplay: String {
        if let def = viewModel.snapshot.defaultRouteInterface,
           let iface = viewModel.snapshot.interfaces.first(where: { $0.name == def }),
           let mtu = iface.mtu {
            return "\(def) • MTU \(mtu)"
        }
        if let mtu = viewModel.snapshot.interfaces.first?.mtu, let name = viewModel.snapshot.interfaces.first?.name {
            return "\(name) • MTU \(mtu)"
        }
        return "—"
    }

    private var ssidBssidDisplay: String {
        let ssid = viewModel.snapshot.wifi?.ssid ?? "—"
        let bssid = viewModel.snapshot.wifi?.bssid?.uppercased() ?? "—"
        if ssid == "—" && bssid == "—" { return "—" }
        return "\(ssid) • \(bssid)"
    }

    private var signalChannelDisplay: String {
        let rssi = viewModel.snapshot.wifi?.rssi
        let noise = viewModel.snapshot.wifi?.noise
        let channel = viewModel.snapshot.wifi?.channel
        let band = viewModel.snapshot.wifi?.band

        var parts: [String] = []
        if let rssi {
            parts.append("\(rssi) dBm")
        }
        if let noise {
            parts.append("noise \(noise) dBm")
        }
        if let channel, let band {
            parts.append("ch \(channel) (\(band))")
        } else if let channel {
            parts.append("ch \(channel)")
        } else if let band {
            parts.append(band)
        }
        return parts.isEmpty ? "—" : parts.joined(separator: " • ")
    }

    private var connectedDisplay: String {
        if let ts = viewModel.snapshot.connectionTimestamp {
            let since = NetworkProfileView.dateFormatter.string(from: ts)
            // If we had a duration, we could render it; for now show timestamp
            return "Since \(since)"
        }
        return "—"
    }

    private var geoDetailDisplay: String {
        // Prefer detailed geo if provided
        var parts: [String] = []
        if let city = viewModel.snapshot.geoCity, !city.isEmpty { parts.append(city) }
        if let region = viewModel.snapshot.geoRegion, !region.isEmpty { parts.append(region) }
        if let country = viewModel.snapshot.geoCountry, !country.isEmpty { parts.append(country) }
        if parts.isEmpty {
            return viewModel.snapshot.geo ?? "—"
        }
        return parts.joined(separator: ", ")
    }

    private var captivePortalDisplay: String {
        guard let cp = viewModel.snapshot.captivePortal else { return "—" }
        return cp ? "Detected" : "No"
    }

    private func iconForInterfaceType(_ type: String) -> String {
        let lower = type.lowercased()
        if lower.contains("wi‑fi") || lower.contains("wifi") {
            return "wifi"
        } else if lower.contains("ethernet") {
            return "cable.connector"
        } else if lower.contains("vpn") {
            return "lock.shield"
        } else if lower.contains("loopback") {
            return "arrow.triangle.2.circlepath"
        } else if lower.contains("bridge") {
            return "point.3.connected.trianglepath.dotted"
        }
        return "network"
    }
}

// MARK: - Section container

private struct SectionCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color.primary.opacity(0.03))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.primary.opacity(0.06), lineWidth: 1)
        )
    }
}
