import SwiftUI

struct NetworkAnalyzerView: View {
    @ObservedObject var viewModel: NetworkAnalyzerViewModel
    @State private var showingPreferences = false

    private var selectedPacket: PacketSample? {
        guard let id = viewModel.selectedPacketID else { return nil }
        return viewModel.packets.first(where: { $0.id == id })
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.capabilityBannerMessage != nil || viewModel.payloadWarningMessage != nil {
                banners
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.06))
            }

            // Single scroll view; Traffic sits right under Capture Configuration
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    header

                    SectionCard {
                        sectionHeader("Session & Export")
                        sessionMenus
                    }

                    SectionCard {
                        sectionHeader("Capture Configuration")
                        ViewThatFits(in: .horizontal) {
                            HStack(alignment: .firstTextBaseline, spacing: 12) {
                                captureConfigInterface
                                captureConfigMode
                                captureConfigBPF
                            }
                            VStack(alignment: .leading, spacing: 12) {
                                captureConfigInterface
                                captureConfigMode
                                captureConfigBPF
                            }
                        }
                        Divider().accessibilityHidden(true)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 8) {
                                startButton
                                stopButton
                                clearButton
                                analyzeButton
                            }
                            VStack(alignment: .leading, spacing: 10) {
                                startButton
                                stopButton
                                clearButton
                                analyzeButton
                            }
                        }
                    }

                    // Move Payload Inspection above Traffic to avoid overlap with GeometryReader section below
                    if let adapter = viewModel.captureAdapters.first(where: { $0.mode == viewModel.selectedCaptureMode }),
                       adapter.supportsPayloadInspection {
                        SectionCard {
                            sectionHeader("Payload Inspection")
                            payloadControls(adapter: adapter)
                        }
                    }

                    // Traffic immediately follows (no SectionCard)
                    trafficSectionContents
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onAppear {
            if viewModel.interfaces.isEmpty {
                viewModel.refreshInterfaces()
            }
        }
        .sheet(isPresented: $showingPreferences) {
            NetworkAnalyzerPreferencesSheet(viewModel: viewModel)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Network Analyzer")
                    .font(.title2.bold())
                    .accessibilityLabel("Network Analyzer")
                Text("Capture traffic, apply filters, and analyze anomalies.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
            }
            Spacer()
        }
    }

    // MARK: - Banners

    @ViewBuilder
    private var banners: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let banner = viewModel.capabilityBannerMessage {
                bannerView(text: banner, symbol: "exclamationmark.shield.fill", tint: .orange)
            }
            if let payloadWarning = viewModel.payloadWarningMessage {
                bannerView(
                    text: payloadWarning,
                    symbol: "lock.shield",
                    tint: .red,
                    dismissAction: viewModel.clearPayloadWarning
                )
            }
        }
    }

    private var captureConfigurationStack: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                captureConfigInterface
                captureConfigMode
                captureConfigBPF
            }

            VStack(alignment: .leading, spacing: 12) {
                captureConfigInterface
                captureConfigMode
                captureConfigBPF
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var captureConfigInterface: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Interface")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            interfacePickerControl
        }
    }

    private var captureConfigMode: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Capture Mode")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            captureModePicker
        }
    }

    private var captureConfigBPF: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("BPF Filter")
                .font(.caption)
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            bpfField
        }
    }

    private var startButton: some View {
        Button {
            viewModel.startCapture()
        } label: {
            Label("Start Capture", systemImage: "play.fill")
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.selectedInterfaceName == nil || isCapturing)
        .accessibilityHint("Begins collecting packets on the selected interface")
    }

    private var stopButton: some View {
        Button {
            viewModel.stopCapture()
        } label: {
            Label("Stop Capture", systemImage: "stop.fill")
        }
        .buttonStyle(.bordered)
        .disabled(!isCapturing)
        .accessibilityHint("Stops the active packet capture session")
    }

    private var clearButton: some View {
        Button {
            viewModel.clearCapture()
        } label: {
            Label("Clear Data", systemImage: "trash")
        }
        .buttonStyle(.bordered)
        .disabled(viewModel.packets.isEmpty && !isCapturing)
        .accessibilityHint("Removes captured packets from the workspace")
    }

    private var analyzeButton: some View {
        Button {
            viewModel.runAnalyzer()
        } label: {
            if isAnalyzing {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("Analyzing")
            } else {
                Label("Analyze", systemImage: "waveform.path.ecg")
            }
        }
        .buttonStyle(.borderedProminent)
        .disabled(viewModel.packets.isEmpty || isAnalyzing)
        .accessibilityHint("Runs the anomaly detection analysis on captured traffic")
    }

    private var sessionMenus: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                openMenu
                sessionManagementMenu
                exportMenu
                toolsMenu
            }
            .padding(.vertical, 1)
        }
        .frame(maxWidth: .infinity, maxHeight: 34, alignment: .leading)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("SessionMenuToolbar")
    }

    // MARK: - Traffic content (no SectionCard)

    private var trafficSectionContents: some View {
        // GeometryReader: compute available viewport height and stretch the table to bottom
        GeometryReader { proxy in
            // Compute a viewport-relative height for this Traffic block
            let viewportHeight: CGFloat = {
                // Frame of this block in global space
                let frame = proxy.frame(in: .global)
                // Height of the app’s main screen; fall back to proxy size if unavailable
                let screenHeight = NSScreen.main?.visibleFrame.height ?? frame.height
                // Visible height from current block’s top to bottom of the window
                let available = max(0, screenHeight - frame.minY)
                // Keep a sensible floor so the section never collapses
                return max(520, available)
            }()

            VStack(alignment: .leading, spacing: 12) {
                sectionHeader("Traffic")

                HStack(alignment: .firstTextBaseline, spacing: 16) {
                    Label(viewModel.captureState.label, systemImage: "dot.radiowaves.left.and.right")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label(viewModel.analyzerState.label, systemImage: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Label("Anomalies: \(viewModel.streamingAnomalies.count)", systemImage: "exclamationmark.triangle")
                        .font(.subheadline)
                        .foregroundStyle(viewModel.streamingAnomalies.isEmpty ? Color.secondary : Color.orange)
                    Spacer()
                    summaryInline
                }
                .accessibilityElement(children: .combine)
                .accessibilityLabel(
                    "Capture state \(viewModel.captureState.label). Analyzer state \(viewModel.analyzerState.label). " +
                    "Detected anomalies \(viewModel.streamingAnomalies.count)."
                )

                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                        .font(.caption)
                }

                filterRow

                Divider().accessibilityHidden(true)

                // Table expands to fill remaining space
                PacketListView(packets: viewModel.filteredPackets, selection: $viewModel.selectedPacketID)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .accessibilityLabel("Captured packets list")
                    .accessibilityHint("Select a packet to review details")
            }
            .frame(maxWidth: .infinity, minHeight: viewportHeight, alignment: .topLeading)
        }
        // Give the GeometryReader a concrete minimum so it participates in ScrollView layout
        .frame(maxWidth: .infinity, minHeight: 520)
    }

    private var sessionManagementMenu: some View {
        Menu {
            Button {
                viewModel.saveSessionToDisk()
            } label: {
                Label("Save Session…", systemImage: "square.and.arrow.down")
            }
            Button {
                viewModel.loadSessionFromDisk()
            } label: {
                Label("Load Session…", systemImage: "square.and.arrow.down.on.square")
            }
        } label: {
            Label("Session", systemImage: "folder")
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Session menu")
    }

    private var exportMenu: some View {
        Menu {
            Button {
                viewModel.exportMetricsCSV()
            } label: {
                Label("Metrics CSV…", systemImage: "chart.bar.doc.horizontal")
            }
            Button {
                viewModel.exportSessionJSON()
            } label: {
                Label("Session JSON…", systemImage: "doc.richtext")
            }
            Button {
                viewModel.exportReportPDF()
            } label: {
                Label("Report PDF…", systemImage: "doc.text.magnifyingglass")
            }
        } label: {
            Label("Export", systemImage: "square.and.arrow.up")
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Export menu")
    }

    private var toolsMenu: some View {
        Menu {
            Button {
                viewModel.refreshCaptureCapabilities()
            } label: {
                Label("Refresh Capture Capabilities", systemImage: "arrow.clockwise")
            }
            Button {
                showingPreferences = true
            } label: {
                Label("Preferences…", systemImage: "gearshape")
            }
        } label: {
            Label("Tools", systemImage: "wrench.and.screwdriver")
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Tools menu")
    }

    // Fix: Use a Menu (not a borderless Button) so it renders enabled consistently
    private var openMenu: some View {
        Menu {
            Button {
                viewModel.importCaptureFromDisk()
            } label: {
                Label("Open PCAP…", systemImage: "externaldrive.connected.to.line.below")
            }
        } label: {
            Label("Open", systemImage: "tray.and.arrow.down")
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("Open menu")
    }

    // MARK: - Filters

    private var filterRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                filterTitle
                filterMenus
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: 12) {
                filterTitle
                filterMenus
            }
        }
        .padding(.vertical, 4)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Traffic filters")
    }

    private var filterTitle: some View {
        Text("Filters")
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityAddTraits(.isHeader)
            .accessibilityLabel("Filter controls")
    }

    private var filterMenus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 12) {
                protocolFilter
                destinationFilter
                portFilter
            }
            VStack(alignment: .leading, spacing: 12) {
                protocolFilter
                destinationFilter
                portFilter
            }
        }
        .accessibilityElement(children: .contain)
    }

    private var protocolFilter: some View {
        filterMenu(
            title: "Protocol",
            selection: viewModel.selectedProtocolFilter,
            options: viewModel.availableProtocols,
            action: viewModel.setProtocolFilter
        )
    }

    private var destinationFilter: some View {
        filterMenu(
            title: "Destination",
            selection: viewModel.selectedDestinationFilter,
            options: viewModel.availableDestinations,
            action: viewModel.setDestinationFilter
        )
    }

    private var portFilter: some View {
        filterMenu(
            title: "Port",
            selection: viewModel.selectedPortFilter,
            options: viewModel.availablePorts,
            action: viewModel.setPortFilter
        )
    }

    private func filterMenu(title: String, selection: String?, options: [String], action: @escaping (String?) -> Void) -> some View {
        Menu {
            Button("All") { action(nil) }
            if !options.isEmpty {
                Section("Select") {
                    ForEach(options, id: \.self) { value in
                        Button(value) { action(value) }
                    }
                }
            }
        } label: {
            let display = selection ?? "All"
            Label("\(title): \(display)", systemImage: "line.3.horizontal.decrease.circle")
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("\(title) filter")
        .accessibilityValue(selection ?? "All")
        .accessibilityHint("Choose a \(title.lowercased()) filter value")
    }

    // MARK: - Payload controls

    @ViewBuilder
    private func payloadControls(adapter: NetworkAnalyzerViewModel.CaptureAdapter) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Image(systemName: "lock.shield")
                    .foregroundStyle(.orange)
                Text("Payload Inspection")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Toggle("Enable", isOn: Binding(
                    get: { viewModel.payloadInspectionEnabled },
                    set: { viewModel.setPayloadInspection($0) }
                ))
                .toggleStyle(.switch)
                .labelsHidden()
                .disabled(!adapter.supportsPayloadInspection)
                .help("Capture full packet payloads (may include sensitive data). Requires privileged capture.")
            }
            Toggle(isOn: $viewModel.payloadConsentGranted) {
                Text("I understand payloads may contain sensitive data and consent to collect them on this host.")
                    .font(.caption)
            }
            .toggleStyle(.checkbox)
            .onChange(of: viewModel.payloadConsentGranted) { granted in
                if viewModel.payloadInspectionEnabled && !granted {
                    viewModel.setPayloadInspection(false)
                }
            }
            Text(adapter.availabilityMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            if viewModel.payloadInspectionEnabled {
                Text("Payload capture active. Consider refining your BPF filter to limit sensitive data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Payload inspection controls")
    }

    // MARK: - Control Bar subviews

    private var interfacePickerControl: some View {
        Picker("Interface", selection: $viewModel.selectedInterfaceName) {
            ForEach(viewModel.interfaces) { iface in
                Text(iface.description).tag(Optional(iface.name))
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .help("Choose the network interface to capture on")
        .accessibilityLabel("Capture interface")
    }

    private var captureModePicker: some View {
        Picker("Mode", selection: $viewModel.selectedCaptureMode) {
            ForEach(viewModel.captureAdapters) { adapter in
                Text(adapter.title).tag(adapter.mode)
            }
        }
        .pickerStyle(.menu)
        .labelsHidden()
        .help("Select capture backend")
        .accessibilityLabel("Capture mode")
    }

    private var bpfField: some View {
        HStack(spacing: 6) {
            Image(systemName: "line.diagonal.arrow")
                .foregroundStyle(.secondary)
                .accessibilityHidden(true)
            TextField("BPF filter (optional)", text: $viewModel.bpfFilter)
                .textFieldStyle(.roundedBorder)
                .disabled(isCapturing)
        }
        .help("Berkeley Packet Filter, e.g. 'tcp port 443'")
        .accessibilityElement(children: .combine)
        .accessibilityLabel("BPF filter")
        .accessibilityHint("Provide an optional Berkeley Packet Filter expression")
    }

    // MARK: - Utilities

    private func bannerView(text: String, symbol: String, tint: Color, dismissAction: (() -> Void)? = nil) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
            Text(text)
                .font(.caption)
                .foregroundStyle(.primary)
            Spacer(minLength: 8)
            if let dismiss = dismissAction {
                Button {
                    dismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.caption)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.12))
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel(text)
        .accessibilityHint("Important capture notice")
    }

    private var isCapturing: Bool {
        if case .capturing = viewModel.captureState { return true }
        return false
    }

    private var isAnalyzing: Bool {
        viewModel.analyzerState == .running
    }

    private func summaryItem(title: String, value: String) -> some View {
        LabeledContent {
            Text(value)
                .font(.caption.monospacedDigit())
        } label: {
            Text(title.uppercased())
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .accessibilityLabel("\(title) \(value)")
    }

    // Inline summary added to fix missing symbol
    private var summaryInline: some View {
        let summary = viewModel.captureSummary
        return HStack(spacing: 12) {
            summaryItem(title: "Packets", value: "\(summary.packetCount)")
            summaryItem(title: "Bytes", value: Self.byteFormatter(summary.totalBytes))
            summaryItem(title: "Duration", value: Self.durationFormatter(summary.duration))
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Summary")
    }

    static func byteFormatter(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesActualByteCount = false
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(bytes))
    }

    static func durationFormatter(_ seconds: TimeInterval) -> String {
        guard seconds > 0 else { return "0 s" }
        if seconds < 60 {
            return String(format: "%.1f s", seconds)
        }
        let minutes = seconds / 60
        if minutes < 60 {
            return String(format: "%.1f m", minutes)
        }
        let hours = minutes / 60
        return String(format: "%.1f h", hours)
    }

    static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()
}

// MARK: - Local SectionCard (scoped to this file)

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

// MARK: - Section header helper

private func sectionHeader(_ title: String) -> some View {
    Text(title)
        .font(.subheadline.weight(.semibold))
        .foregroundStyle(.secondary)
        .padding(.top, 4)
        .accessibilityLabel(title)
}
