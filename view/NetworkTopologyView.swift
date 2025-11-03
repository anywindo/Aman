//
//  NetworkTopologyView.swift
//  Aman
//
//  SwiftUI shell for the topology experience powered by an embedded HTML renderer.
//

import SwiftUI
import WebKit

struct NetworkTopologyWindowView: View {
    @ObservedObject var coordinator: NetworkMappingCoordinator

    @State private var graph: NetworkTopologyGraph = .empty
    @State private var lastUpdated: Date?
    @State private var highlightedIPAddress: String?
    @State private var focusedHost: DiscoveredHost?
    @State private var resetToken = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            content
        }
        .padding(20)
        .frame(minWidth: 760, minHeight: 560)
        .onAppear {
            graph = coordinator.topology
            highlightedIPAddress = coordinator.highlightedHostIPAddress
            lastUpdated = Date()
            syncFocus(for: highlightedIPAddress ?? focusedHost?.ipAddress)
        }
        .onReceive(coordinator.$topology) { value in
            graph = value
            lastUpdated = Date()
            syncFocus(for: highlightedIPAddress ?? focusedHost?.ipAddress)
        }
        .onReceive(coordinator.$highlightedHostIPAddress) { ip in
            highlightedIPAddress = ip
            syncFocus(for: ip)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Topology")
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 10) {
                Button {
                    resetToken = UUID()
                    highlightedIPAddress = nil
                    focusedHost = nil
                } label: {
                    Label("Reset View", systemImage: "viewfinder")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.bordered)
                .disabled(graph.nodes.isEmpty)

                Button {
                    coordinator.refreshTopology()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .labelStyle(.titleAndIcon)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        parts.append("Nodes \(graph.nodes.count)")
        parts.append("Edges \(graph.edges.count)")
        if coordinator.isSampleDatasetActive {
            parts.append("Sample dataset")
        }
        return parts.joined(separator: " • ")
    }

    private var content: some View {
        Group {
            if graph.nodes.isEmpty {
                emptyState
            } else {
                ZStack(alignment: .bottomLeading) {
                    NetworkTopologyWebView(
                        graph: graph,
                        highlightedIPAddress: highlightedIPAddress,
                        resetTrigger: resetToken
                    ) { ip in
                        if let ip {
                            syncFocus(for: ip)
                        } else if highlightedIPAddress == nil {
                            focusedHost = nil
                        }
                    }
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.primary.opacity(0.12), lineWidth: 1)
                    )

                    infoOverlay
                        .padding(14)
                        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.2), lineWidth: 0.8)
                        )
                        .padding(18)
                }
            }
        }
    }

    private var emptyState: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(nsColor: .windowBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                )
            VStack(spacing: 12) {
                Image(systemName: "network.slash")
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundStyle(.secondary)
                Text("Topology unavailable")
                    .font(.headline)
                Text("Run a network discovery sweep to populate hosts before opening the topology view.")
                    .multilineTextAlignment(.center)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 24)
            }
        }
    }

    private var infoOverlay: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 12) {
                Label("\(graph.nodes.count) nodes", systemImage: "point.3.connected.trianglepath.dotted")
                Label("\(graph.edges.count) edges", systemImage: "link")
            }
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.secondary)

            if let host = focusedHost {
                VStack(alignment: .leading, spacing: 4) {
                    Text(host.hostName ?? host.ipAddress)
                        .font(.headline)
                    Text(host.ipAddress)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if let mac = host.macAddress {
                        Text("MAC: \(mac)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let iface = host.interfaceName {
                        Text("Interface: \(iface)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if !host.services.isEmpty {
                        let portsSummary = host.services
                            .map { "\($0.protocolName.uppercased()) \($0.port)" }
                            .joined(separator: ", ")
                        Text("Ports: \(portsSummary)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.top, 6)
            } else {
                Text(coordinator.isSampleDatasetActive ? "Sample dataset loaded. Hover a node to inspect details." : "Hover a node to see details here.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            if let lastUpdated {
                Text("Updated \(lastUpdated.formatted(date: .omitted, time: .standard))")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func syncFocus(for ip: String?) {
        guard let ip else {
            focusedHost = nil
            return
        }
        if let host = graph.nodes.first(where: { $0.ipAddress.caseInsensitiveCompare(ip) == .orderedSame }) {
            focusedHost = host
        } else {
            focusedHost = nil
        }
    }
}

// MARK: - WebView bridge

private struct NetworkTopologyWebView: NSViewRepresentable {
    let graph: NetworkTopologyGraph
    let highlightedIPAddress: String?
    let resetTrigger: UUID
    let onFocusChange: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeNSView(context: Context) -> WKWebView {
        context.coordinator.webView
    }

    func updateNSView(_ nsView: WKWebView, context: Context) {
        context.coordinator.update(graph: graph, highlightedIPAddress: highlightedIPAddress)
        if context.coordinator.lastResetTrigger != resetTrigger {
            context.coordinator.lastResetTrigger = resetTrigger
            context.coordinator.resetView()
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private(set) var webView: WKWebView
        private let encoder = JSONEncoder()

        private var pendingGraphJSON: String?
        private var pendingHighlightIP: String?
        private var shouldClearHighlight = false
        private var pendingReset = false
        private var isContentLoaded = false

        var lastResetTrigger: UUID
        private let parent: NetworkTopologyWebView

        init(parent: NetworkTopologyWebView) {
            self.parent = parent
            self.lastResetTrigger = parent.resetTrigger

            let configuration = WKWebViewConfiguration()
            configuration.preferences.javaScriptEnabled = true
            configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

            let webView = WKWebView(frame: .zero, configuration: configuration)
            self.webView = webView

            super.init()

            configuration.userContentController.add(self, name: "nodeFocusChanged")
            encoder.outputFormatting = [.withoutEscapingSlashes]
            webView.navigationDelegate = self
            webView.setValue(false, forKey: "drawsBackground")
            webView.loadHTMLString(NetworkTopologyHTML.template, baseURL: nil)
        }

        func update(graph: NetworkTopologyGraph, highlightedIPAddress: String?) {
            guard let json = encodeGraph(graph: graph) else { return }
            if isContentLoaded {
                sendGraph(json)
            } else {
                pendingGraphJSON = json
            }

            if let ip = highlightedIPAddress, !ip.isEmpty {
                if isContentLoaded {
                    highlightNode(ipAddress: ip)
                } else {
                    pendingHighlightIP = ip
                }
            } else {
                if isContentLoaded {
                    clearHighlight()
                } else {
                    pendingHighlightIP = nil
                    shouldClearHighlight = true
                }
            }
        }

        func resetView() {
            if isContentLoaded {
                webView.evaluateJavaScript("window.resetView && window.resetView();", completionHandler: nil)
            } else {
                pendingReset = true
            }
        }

        private func sendGraph(_ json: String) {
            webView.evaluateJavaScript("window.renderGraph(\(json));", completionHandler: nil)
        }

        private func highlightNode(ipAddress: String) {
            let escaped = ipAddress
                .replacingOccurrences(of: "\\", with: "\\\\")
                .replacingOccurrences(of: "'", with: "\\'")
            webView.evaluateJavaScript("window.highlightNodeByIP && window.highlightNodeByIP('\(escaped)');", completionHandler: nil)
        }

        private func clearHighlight() {
            webView.evaluateJavaScript("window.clearHighlight && window.clearHighlight();", completionHandler: nil)
        }

        private func encodeGraph(graph: NetworkTopologyGraph) -> String? {
            let payload = TopologyPayload(
                nodes: graph.nodes.map { TopologyPayload.Node(from: $0) },
                edges: graph.edges.map { TopologyPayload.Edge(from: $0) }
            )
            guard let data = try? encoder.encode(payload),
                  let json = String(data: data, encoding: .utf8) else { return nil }
            return json
        }

        // MARK: - WKNavigationDelegate

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            isContentLoaded = true

            if let json = pendingGraphJSON {
                sendGraph(json)
                pendingGraphJSON = nil
            }
            if let ip = pendingHighlightIP {
                highlightNode(ipAddress: ip)
                pendingHighlightIP = nil
            } else if shouldClearHighlight {
                clearHighlight()
                shouldClearHighlight = false
            }
            if pendingReset {
                resetView()
                pendingReset = false
            }
        }

        // MARK: - WKScriptMessageHandler

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard message.name == "nodeFocusChanged",
                  let body = message.body as? [String: Any] else { return }

            if let ip = body["ipAddress"] as? String, !ip.isEmpty {
                parent.onFocusChange(ip)
            } else {
                parent.onFocusChange(nil)
            }
        }
    }
}

// MARK: - Payload mapping

private struct TopologyPayload: Codable {
    struct Node: Codable {
        let id: String
        let ipAddress: String
        let hostName: String?
        let macAddress: String?
        let interfaceName: String?
        let category: String
        let servicePorts: [UInt16]
    }

    struct Edge: Codable {
        let source: String
        let target: String
        let relationship: String
    }

    let nodes: [Node]
    let edges: [Edge]
}

private extension TopologyPayload.Node {
    init(from host: DiscoveredHost) {
        let category: String
        if host.hostName?.lowercased().hasPrefix("local") == true {
            category = "local"
        } else if host.hostName?.lowercased().contains("gateway") == true {
            category = "gateway"
        } else {
            category = "host"
        }

        self = TopologyPayload.Node(
            id: host.id.uuidString,
            ipAddress: host.ipAddress,
            hostName: host.hostName,
            macAddress: host.macAddress,
            interfaceName: host.interfaceName,
            category: category,
            servicePorts: host.services.map(\.port)
        )
    }
}

private extension TopologyPayload.Edge {
    init(from edge: NetworkTopologyGraph.Edge) {
        self = TopologyPayload.Edge(
            source: edge.source.uuidString,
            target: edge.target.uuidString,
            relationship: edge.relationship
        )
    }
}

// MARK: - Embedded HTML template

private enum NetworkTopologyHTML {
    static let template = #"""
    <!DOCTYPE html>
    <html lang="en">
        <head>
            <meta charset="utf-8" />
            <meta name="viewport" content="width=device-width, initial-scale=1.0" />
            <title>Network Topology</title>
            <style>
                html, body {
                    margin: 0;
                    padding: 0;
                    width: 100%;
                    height: 100%;
                    overflow: hidden;
                    font-family: -apple-system, BlinkMacSystemFont, "San Francisco", sans-serif;
                    background-color: #ffffff;
                }

                #container {
                    width: 100%;
                    height: 100%;
                    position: relative;
                    background-image: radial-gradient(circle, rgba(0, 0, 0, 0.08) 1px, transparent 1px);
                    background-size: 46px 46px;
                }

                svg {
                    width: 100%;
                    height: 100%;
                    user-select: none;
                }

                .node-label {
                    pointer-events: none;
                    font-size: 11px;
                    font-weight: 600;
                    fill: #ffffff;
                    text-shadow: 0 1px 3px rgba(0, 0, 0, 0.35);
                }
            </style>
        </head>
        <body>
            <div id="container">
                <noscript>Please enable JavaScript to render the network topology.</noscript>
            </div>
            <script>
                (function () {
                    'use strict';

                    const SVG_NS = 'http://www.w3.org/2000/svg';
                    const container = document.getElementById('container');
                    const svgRoot = document.createElementNS(SVG_NS, 'svg');
                    svgRoot.setAttribute('width', '100%');
                    svgRoot.setAttribute('height', '100%');
                    svgRoot.setAttribute('viewBox', '-400 -400 800 800');
                    svgRoot.style.touchAction = 'none';
                    container.appendChild(svgRoot);

                    const linkGroup = document.createElementNS(SVG_NS, 'g');
                    const nodeGroup = document.createElementNS(SVG_NS, 'g');
                    svgRoot.appendChild(linkGroup);
                    svgRoot.appendChild(nodeGroup);

                    const colorByCategory = {
                        gateway: '#ff9f0a',
                        local: '#0a84ff',
                        host: '#6c6c70'
                    };

                    const relationshipStyles = {
                        uplink: { stroke: '#0a84ff', width: 2.4 },
                        gateway: { stroke: '#ff9f0a', width: 2.0 },
                        arp: { stroke: '#6c6c70', width: 1.2, dash: '5 4' }
                    };

                    let currentNodes = [];
                    let currentEdges = [];
                    const nodeElements = new Map();
                    let hoverFocusIP = null;
                    let externalFocusIP = null;
                    let lastNotifiedIP = '';

                    let defaultView = { x: -400, y: -400, width: 800, height: 800 };
                    let viewBox = { ...defaultView };
                    let aspectRatio = 1;
                    let isPanning = false;
                    let panStart = { x: 0, y: 0 };
                    let viewBoxStart = { ...viewBox };

                    function equalsIP(lhs, rhs) {
                        return typeof lhs === 'string' && typeof rhs === 'string' && lhs.toLowerCase() === rhs.toLowerCase();
                    }

                    function notifyFocus(ip) {
                        const value = ip ?? '';
                        if (lastNotifiedIP === value) {
                            return;
                        }
                        lastNotifiedIP = value;
                        const handler = window.webkit?.messageHandlers?.nodeFocusChanged;
                        if (handler) {
                            handler.postMessage({ ipAddress: value });
                        }
                    }

                    function effectiveIP() {
                        return hoverFocusIP ?? externalFocusIP ?? null;
                    }

                    function applyViewBox() {
                        svgRoot.setAttribute('viewBox', `${viewBox.x} ${viewBox.y} ${viewBox.width} ${viewBox.height}`);
                    }

                    function updateAspectRatio() {
                        const widthPx = container.clientWidth || 1;
                        const heightPx = container.clientHeight || 1;
                        aspectRatio = widthPx / heightPx;
                    }

                    function placeRing(nodes, radius, phase, placed) {
                        if (!nodes.length) {
                            return;
                        }
                        if (nodes.length === 1) {
                            nodes[0].x = radius * Math.cos(phase);
                            nodes[0].y = radius * Math.sin(phase);
                            placed.add(nodes[0]);
                            return;
                        }
                        nodes.forEach((node, idx) => {
                            const angle = phase + (idx / nodes.length) * Math.PI * 2;
                            node.x = radius * Math.cos(angle);
                            node.y = radius * Math.sin(angle);
                            placed.add(node);
                        });
                    }

                    function layoutNodes(nodes) {
                        if (!nodes.length) {
                            return;
                        }
                        if (nodes.length === 1) {
                            nodes[0].x = 0;
                            nodes[0].y = 0;
                            return;
                        }

                        const locals = [];
                        const gateways = [];
                        const others = [];

                        nodes.forEach((node) => {
                            if (node.hostName && node.hostName.toLowerCase().startsWith('local')) {
                                locals.push(node);
                            } else if (node.hostName && node.hostName.toLowerCase().includes('gateway')) {
                                gateways.push(node);
                            } else {
                                others.push(node);
                            }
                        });

                        const placed = new Set();
                        placeRing(locals, 80, -Math.PI / 2, placed);
                        placeRing(gateways, 150, Math.PI / 4, placed);

                        const outerRadius = 240 + Math.max(0, others.length - 12) * 14;
                        placeRing(others, outerRadius, 0, placed);

                        nodes.forEach((node, index) => {
                            if (!placed.has(node)) {
                                const angle = (index / nodes.length) * Math.PI * 2;
                                node.x = outerRadius * Math.cos(angle);
                                node.y = outerRadius * Math.sin(angle);
                            }
                        });
                    }

                    function clearChildren(element) {
                        while (element.firstChild) {
                            element.removeChild(element.firstChild);
                        }
                    }

                    function labelFor(node) {
                        if (node.category === 'gateway') {
                            return 'GW';
                        }
                        if (node.hostName && node.hostName.length > 0) {
                            return node.hostName.slice(0, 3).toUpperCase();
                        }
                        if (node.servicePorts && node.servicePorts.length > 0) {
                            return String(node.servicePorts[0]);
                        }
                        const octets = node.ipAddress?.split('.') ?? [];
                        return octets[octets.length - 1] ?? node.ipAddress;
                    }

                    function drawGraph() {
                        clearChildren(linkGroup);
                        clearChildren(nodeGroup);
                        nodeElements.clear();

                        const nodeLookup = new Map();
                        currentNodes.forEach((node) => {
                            nodeLookup.set(node.id, node);
                        });

                        currentEdges.forEach((edge) => {
                            const source = nodeLookup.get(edge.source);
                            const target = nodeLookup.get(edge.target);
                            if (!source || !target) {
                                return;
                            }
                            const style = relationshipStyles[edge.relationship] || { stroke: '#d0d0d5', width: 1.2 };
                            const line = document.createElementNS(SVG_NS, 'line');
                            line.setAttribute('x1', String(source.x));
                            line.setAttribute('y1', String(source.y));
                            line.setAttribute('x2', String(target.x));
                            line.setAttribute('y2', String(target.y));
                            line.setAttribute('stroke', style.stroke);
                            line.setAttribute('stroke-width', String(style.width));
                            line.setAttribute('stroke-linecap', 'round');
                            line.setAttribute('stroke-opacity', '0.8');
                            if (style.dash) {
                                line.setAttribute('stroke-dasharray', style.dash);
                            }
                            linkGroup.appendChild(line);
                        });

                        currentNodes.forEach((node) => {
                            const group = document.createElementNS(SVG_NS, 'g');
                            group.setAttribute('transform', `translate(${node.x}, ${node.y})`);

                            const circle = document.createElementNS(SVG_NS, 'circle');
                            const radius = node.category === 'local' ? 28 : node.category === 'gateway' ? 25 : 22;
                            circle.setAttribute('r', String(radius));
                            circle.setAttribute('fill', colorByCategory[node.category] || '#6c6c70');
                            circle.setAttribute('stroke', 'rgba(255,255,255,0.35)');
                            circle.setAttribute('stroke-width', '1.4');

                            const label = document.createElementNS(SVG_NS, 'text');
                            label.setAttribute('class', 'node-label');
                            label.setAttribute('text-anchor', 'middle');
                            label.setAttribute('dominant-baseline', 'middle');
                            label.textContent = labelFor(node);

                            group.appendChild(circle);
                            group.appendChild(label);
                            nodeGroup.appendChild(group);

                            nodeElements.set(node.ipAddress.toLowerCase(), { node, circle });

                            group.addEventListener('mouseenter', () => {
                                hoverFocusIP = node.ipAddress;
                                updateHighlights();
                                notifyFocus(node.ipAddress);
                            });

                            group.addEventListener('mouseleave', () => {
                                hoverFocusIP = null;
                                updateHighlights();
                                if (!externalFocusIP) {
                                    notifyFocus(null);
                                }
                            });
                        });
                    }

                    function updateHighlights() {
                        const activeIP = effectiveIP();
                        nodeElements.forEach(({ node, circle }) => {
                            if (activeIP && equalsIP(node.ipAddress, activeIP)) {
                                circle.setAttribute('stroke', 'rgba(48,209,88,0.95)');
                                circle.setAttribute('stroke-width', '4');
                            } else {
                                circle.setAttribute('stroke', 'rgba(255,255,255,0.35)');
                                circle.setAttribute('stroke-width', '1.4');
                            }
                        });
                    }

                    function computeBounds(nodes) {
                        let minX = Infinity;
                        let maxX = -Infinity;
                        let minY = Infinity;
                        let maxY = -Infinity;
                        nodes.forEach((node) => {
                            if (typeof node.x === 'number' && typeof node.y === 'number') {
                                minX = Math.min(minX, node.x);
                                maxX = Math.max(maxX, node.x);
                                minY = Math.min(minY, node.y);
                                maxY = Math.max(maxY, node.y);
                            }
                        });
                        if (!isFinite(minX) || !isFinite(maxX) || !isFinite(minY) || !isFinite(maxY)) {
                            return { minX: -200, maxX: 200, minY: -200, maxY: 200 };
                        }
                        return { minX, maxX, minY, maxY };
                    }

                    function setDefaultView() {
                        if (!currentNodes.length) {
                            viewBox = { ...defaultView };
                            applyViewBox();
                            return;
                        }
                        const bounds = computeBounds(currentNodes);
                        const margin = 160;
                        let width = (bounds.maxX - bounds.minX) || 40;
                        let height = (bounds.maxY - bounds.minY) || 40;
                        width += margin * 2;
                        height += margin * 2;

                        updateAspectRatio();
                        if (!aspectRatio || !isFinite(aspectRatio)) {
                            aspectRatio = 1;
                        }

                        if (width / height < aspectRatio) {
                            width = height * aspectRatio;
                        } else {
                            height = width / aspectRatio;
                        }

                        const centerX = (bounds.minX + bounds.maxX) / 2;
                        const centerY = (bounds.minY + bounds.maxY) / 2;

                        defaultView = {
                            x: centerX - width / 2,
                            y: centerY - height / 2,
                            width,
                            height
                        };

                        viewBox = { ...defaultView };
                        applyViewBox();
                    }

                    function zoomToNode(ip) {
                        if (!ip) {
                            return;
                        }
                        const entry = nodeElements.get(ip.toLowerCase());
                        if (!entry) {
                            return;
                        }
                        updateAspectRatio();
                        const node = entry.node;
                        const targetWidth = Math.max(defaultView.width / 4, 160);
                        const targetHeight = targetWidth / aspectRatio;
                        viewBox = {
                            x: node.x - targetWidth / 2,
                            y: node.y - targetHeight / 2,
                            width: targetWidth,
                            height: targetHeight
                        };
                        applyViewBox();
                    }

                    function clearGraph() {
                        currentNodes = [];
                        currentEdges = [];
                        nodeElements.clear();
                        clearChildren(linkGroup);
                        clearChildren(nodeGroup);
                        hoverFocusIP = null;
                        externalFocusIP = null;
                        updateHighlights();
                        notifyFocus(null);
                        viewBox = { ...defaultView };
                        applyViewBox();
                    }

                    function renderGraph(payload) {
                        currentNodes = (payload?.nodes ?? []).map((node) => ({ ...node }));
                        currentEdges = (payload?.edges ?? []).map((edge) => ({ ...edge }));

                        if (!currentNodes.length) {
                            clearGraph();
                            return;
                        }

                        layoutNodes(currentNodes);
                        drawGraph();
                        setDefaultView();
                        updateHighlights();

                        if (externalFocusIP) {
                            zoomToNode(externalFocusIP);
                        }
                    }

                    function highlightNodeByIP(ip) {
                        if (ip && ip.length) {
                            externalFocusIP = ip;
                            updateHighlights();
                            zoomToNode(ip);
                            notifyFocus(ip);
                        } else {
                            externalFocusIP = null;
                            updateHighlights();
                            if (!hoverFocusIP) {
                                notifyFocus(null);
                            }
                        }
                    }

                    function clearHighlight() {
                        highlightNodeByIP(null);
                    }

                    function resetView() {
                        externalFocusIP = null;
                        hoverFocusIP = null;
                        updateHighlights();
                        setDefaultView();
                        notifyFocus(null);
                    }

                    function handlePointerDown(event) {
                        if (event.button !== 0) {
                            return;
                        }
                        isPanning = true;
                        panStart = { x: event.clientX, y: event.clientY };
                        viewBoxStart = { ...viewBox };
                        svgRoot.setPointerCapture(event.pointerId);
                    }

                    function handlePointerMove(event) {
                        if (!isPanning) {
                            return;
                        }
                        const widthPx = container.clientWidth || 1;
                        const heightPx = container.clientHeight || 1;
                        const dx = event.clientX - panStart.x;
                        const dy = event.clientY - panStart.y;
                        viewBox.x = viewBoxStart.x - dx * viewBox.width / widthPx;
                        viewBox.y = viewBoxStart.y - dy * viewBox.height / heightPx;
                        applyViewBox();
                    }

                    function handlePointerUp(event) {
                        if (!isPanning) {
                            return;
                        }
                        isPanning = false;
                        svgRoot.releasePointerCapture(event.pointerId);
                    }

                    function handleWheel(event) {
                        event.preventDefault();
                        updateAspectRatio();
                        const widthPx = container.clientWidth || 1;
                        const heightPx = container.clientHeight || 1;
                        const pointerX = event.offsetX / widthPx;
                        const pointerY = event.offsetY / heightPx;
                        const anchorX = viewBox.x + viewBox.width * pointerX;
                        const anchorY = viewBox.y + viewBox.height * pointerY;

                        const scaleFactor = Math.exp(-event.deltaY * 0.0015);
                        const minWidth = Math.max(defaultView.width / 10, 80);
                        const maxWidth = defaultView.width * 4;

                        let newWidth = viewBox.width / scaleFactor;
                        newWidth = Math.min(Math.max(newWidth, minWidth), maxWidth);
                        let newHeight = newWidth / aspectRatio;

                        viewBox = {
                            x: anchorX - newWidth * pointerX,
                            y: anchorY - newHeight * pointerY,
                            width: newWidth,
                            height: newHeight
                        };

                        applyViewBox();
                    }

                    svgRoot.addEventListener('pointerdown', handlePointerDown);
                    svgRoot.addEventListener('pointermove', handlePointerMove);
                    svgRoot.addEventListener('pointerup', handlePointerUp);
                    svgRoot.addEventListener('pointercancel', handlePointerUp);
                    svgRoot.addEventListener('wheel', handleWheel, { passive: false });

                    window.renderGraph = renderGraph;
                    window.highlightNodeByIP = highlightNodeByIP;
                    window.clearHighlight = clearHighlight;
                    window.resetView = resetView;

                    window.addEventListener('resize', () => {
                        updateAspectRatio();
                        setDefaultView();
                        if (externalFocusIP) {
                            zoomToNode(externalFocusIP);
                        }
                    });
                })();
            </script>
        </body>
    </html>
    """#
}
