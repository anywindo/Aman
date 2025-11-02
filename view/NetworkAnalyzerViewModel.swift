import Foundation
import AppKit
import UniformTypeIdentifiers
import Darwin
import PDFKit

@MainActor
final class NetworkAnalyzerViewModel: ObservableObject {
    enum CaptureState: Equatable {
        case idle
        case loading(String)
        case ready(String)
        case capturing(String)
        case completed(String)
        case failed(String)

        var label: String {
            switch self {
            case .idle:
                return "Idle"
            case .loading(let name):
                return "Loading \(name)…"
            case .ready(let name):
                return "\(name) ready"
            case .capturing(let iface):
                return "Capturing on \(iface)…"
            case .completed(let name):
                return "\(name) captured"
            case .failed(let reason):
                return "Failed: \(reason)"
            }
        }
    }

    enum AnalyzerState: Equatable {
        case idle
        case running
        case ready

        var label: String {
            switch self {
            case .idle:
                return "Analyzer idle"
            case .running:
                return "Analyzing…"
            case .ready:
                return "Analyzer ready"
            }
        }
    }

    struct InterfaceOption: Identifiable, Hashable {
        let name: String
        let description: String
        var id: String { name }
    }

    enum CaptureMode: String, CaseIterable, Identifiable, Codable {
        case standard
        case privileged

        var id: String { rawValue }

        var title: String {
            switch self {
            case .standard:
                return "Standard"
            case .privileged:
                return "Privileged libpcap"
            }
        }

        var requiresPrivileges: Bool {
            switch self {
            case .standard:
                return false
            case .privileged:
                return true
            }
        }

        var supportsPayloadInspection: Bool {
            switch self {
            case .standard:
                return false
            case .privileged:
                return true
            }
        }
    }

    struct CaptureAdapter: Identifiable {
        let mode: CaptureMode
        let title: String
        let subtitle: String
        let requiresPrivileges: Bool
        let isAvailable: Bool
        let availabilityMessage: String
        let supportsPayloadInspection: Bool

        var id: CaptureMode { mode }
    }

    enum AnalyzerAlgorithm: String, CaseIterable, Identifiable, Codable {
        case zScore = "zscore"
        case mad = "mad"
        case ewma = "ewma"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .zScore:
                return "Z-Score"
            case .mad:
                return "MAD"
            case .ewma:
                return "EWMA"
            }
        }

        var description: String {
            switch self {
            case .zScore:
                return "Rolling mean with standard deviation."
            case .mad:
                return "Median absolute deviation for robust spikes."
            case .ewma:
                return "Exponentially weighted moving average for smoother trends."
            }
        }
    }

    // MARK: - Published state

    @Published private(set) var captureState: CaptureState = .idle
    @Published private(set) var analyzerState: AnalyzerState = .idle
    @Published private(set) var interfaces: [InterfaceOption] = []
    @Published var selectedInterfaceName: String?
    @Published var bpfFilter: String = ""
    @Published private(set) var captureAdapters: [CaptureAdapter] = []
    @Published var selectedCaptureMode: CaptureMode = .standard {
        didSet {
            validateCaptureModeSelection()
            persistPreferences()
        }
    }
    @Published private(set) var capabilityBannerMessage: String?
    @Published private(set) var payloadWarningMessage: String?
    @Published private(set) var payloadInspectionEnabled = false
    @Published var payloadConsentGranted = false {
        didSet {
            if !payloadConsentGranted && payloadInspectionEnabled {
                payloadInspectionEnabled = false
            }
        }
    }
    @Published private(set) var packets: [PacketSample] = []
    @Published private(set) var perSecondMetrics: [MetricPoint] = []
    @Published private(set) var perMinuteMetrics: [MetricPoint] = []
    @Published private(set) var filteredPackets: [PacketSample] = []
    @Published private(set) var filteredPerSecondMetrics: [MetricPoint] = []
    @Published private(set) var filteredPerMinuteMetrics: [MetricPoint] = []
    @Published private(set) var analyzerResult: AnalyzerResult?
    @Published private(set) var streamingAnomalies: [Anomaly] = []
    @Published private(set) var captureSummary: CaptureSummary = CaptureSummary(interfaceName: nil, packetCount: 0, totalBytes: 0, duration: 0, start: nil, end: nil)
    @Published private(set) var availableProtocols: [String] = []
    @Published private(set) var availableDestinations: [String] = []
    @Published private(set) var availablePorts: [String] = []
    @Published private(set) var topDestinations: [TagRank] = []
    @Published private(set) var topProtocols: [TagRank] = []
    @Published private(set) var topPorts: [TagRank] = []
    @Published private(set) var timelineAnnotations: [TimelineAnnotation] = []
    @Published private(set) var correlationClusters: [CorrelationCluster] = []
    @Published private(set) var activeClusterContext: CorrelationCluster?
    @Published private(set) var timelineCursorTimestamp: Date?
    @Published var selectedPacketID: PacketSample.ID?
    @Published var windowSeconds: Int = 60 {
        didSet {
            if windowSeconds < 5 {
                windowSeconds = 5
                return
            }
            scheduleStreamingAnalysis()
            persistPreferences()
        }
    }
    @Published var zThreshold: Double = 3.0 {
        didSet {
            if zThreshold < 0.5 {
                zThreshold = 0.5
                return
            }
            scheduleStreamingAnalysis()
            persistPreferences()
        }
    }
    @Published var selectedAlgorithm: AnalyzerAlgorithm = .zScore {
        didSet {
            scheduleStreamingAnalysis()
            persistPreferences()
        }
    }
    @Published var ewmaAlpha: Double = 0.3 {
        didSet {
            if ewmaAlpha < 0.05 {
                ewmaAlpha = 0.05
                return
            }
            if ewmaAlpha > 0.9 {
                ewmaAlpha = 0.9
                return
            }
            scheduleStreamingAnalysis()
            persistPreferences()
        }
    }
    @Published var selectedProtocolFilter: String?
    @Published var selectedDestinationFilter: String?
    @Published var selectedPortFilter: String?
    @Published var selectedTimeRange: TimeInterval = 120 {
        didSet {
            applyFilters()
            persistPreferences()
        }
    }
    @Published var selectedClusterID: UUID? {
        didSet { updateActiveClusterContext() }
    }
    @Published var selectedAnomalyID: UUID?
    @Published var timelineCursorProgress: Double = 1.0 {
        didSet { updateTimelineCursorTimestamp() }
    }
    @Published var isDebugOverlayEnabled = false
    @Published var errorMessage: String?

    // MARK: - Private state

    private let pythonRunner = PythonProcessRunner.shared
    private let captureController = PcapCaptureController()
    private let shellRunner: ShellCommandRunning
    private let preferencesDefaults = UserDefaults.standard
    private let preferencesKey = "NetworkAnalyzerPreferences"

    private var activeCaptureLabel: String?
    private var activeInterfaceName: String?

    private var packetCounter: Int = 0
    private var captureStart: Date?
    private var captureEnd: Date?
    private var totalBytes: Int = 0

    private var secondBuckets: [Date: SecondBucket] = [:]
    private var perSecondSeries: [MetricPoint] = []
    private var perMinuteSeriesStorage: [MetricPoint] = []
    private var minuteWindow: [MetricPoint] = []
    private var minuteBytesSum: Double = 0
    private var minutePacketsSum: Double = 0
    private var minuteProtocolHistogram: [String: Int] = [:]
    private var minuteTagTotals: [String: [String: TagTotals]] = [:]
    private var flowLastSeen: [String: Date] = [:]

    private var analysisQueue = DispatchQueue(label: "com.aman.networkAnalyzer.analysis")
    private var analysisWorkItem: DispatchWorkItem?
    private var seenAnomalyKeys: Set<String> = []

    private var fallbackTimer: DispatchSourceTimer?
    private var fallbackSnapshot: NetstatSnapshot?

    private let maxPacketBuffer = 6000
    private let maxPerSecondPoints = 1200
    private let maxPerMinutePoints = 240
    private let analysisDebounceInterval: TimeInterval = 0.6
    private let streamingWindowSeconds: Int = 120
    private var isRestoringPreferences = false

    // MARK: - Initialiser

    init(shellRunner: ShellCommandRunning = ProcessShellRunner()) {
        self.shellRunner = shellRunner
        configureCaptureCallbacks()
        refreshCaptureAdapters()
        loadPreferences()
        applyFilters()
    }

    deinit {
        fallbackTimer?.cancel()
        fallbackTimer = nil
    }

    // MARK: - Interface inventory

    func refreshInterfaces() {
        let service = NetworkInfoService()
        do {
            let inventory = try service.interfaceInventory(defaultGatewayIP: nil)
            let mapped: [InterfaceOption] = inventory.map {
                InterfaceOption(
                    name: $0.name,
                    description: "\($0.name) • \($0.type)\($0.isDefaultRoute ? " • default" : "")"
                )
            }
            interfaces = mapped.sorted { lhs, rhs in
                if lhs.name == "en0" { return true }
                if rhs.name == "en0" { return false }
                return lhs.name < rhs.name
            }
            if selectedInterfaceName == nil {
                selectedInterfaceName = interfaces.first?.name
            }
        } catch {
            interfaces = []
            selectedInterfaceName = nil
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Capture capability management

    func refreshCaptureCapabilities() {
        refreshCaptureAdapters()
    }

    private func refreshCaptureAdapters() {
        let standard = CaptureAdapter(
            mode: .standard,
            title: CaptureMode.standard.title,
            subtitle: "User-space tcpdump without elevated privileges.",
            requiresPrivileges: false,
            isAvailable: true,
            availabilityMessage: "Standard capture uses tcpdump with metadata only.",
            supportsPayloadInspection: CaptureMode.standard.supportsPayloadInspection
        )

        let privilegedAvailable = geteuid() == 0 || getuid() == 0 || ProcessInfo.processInfo.environment["SUDO_UID"] != nil
        let privilegedMessage = privilegedAvailable ?
            "Privileged capture active. Ensure you trust this host before collecting payloads." :
            "Run Aman with sudo/root privileges (e.g. sudo /Aman.app/Contents/MacOS/Aman) to enable privileged capture."
        let privileged = CaptureAdapter(
            mode: .privileged,
            title: CaptureMode.privileged.title,
            subtitle: "Full packet capture via libpcap (root/sudo required).",
            requiresPrivileges: true,
            isAvailable: privilegedAvailable,
            availabilityMessage: privilegedMessage,
            supportsPayloadInspection: CaptureMode.privileged.supportsPayloadInspection
        )

        captureAdapters = [standard, privileged]
        if !captureAdapters.contains(where: { $0.mode == selectedCaptureMode }) {
            selectedCaptureMode = .standard
        } else {
            validateCaptureModeSelection()
        }
    }

    private func validateCaptureModeSelection() {
        guard let adapter = selectedCaptureAdapter else {
            capabilityBannerMessage = nil
            return
        }

        updateCapabilityBanner(for: adapter)

        if !adapter.supportsPayloadInspection && payloadInspectionEnabled {
            payloadInspectionEnabled = false
            persistPreferences()
        }

        if adapter.mode == .standard && payloadConsentGranted {
            payloadConsentGranted = false
        }
    }

    private func updateCapabilityBanner(for adapter: CaptureAdapter) {
        switch adapter.mode {
        case .standard:
            capabilityBannerMessage = nil
        case .privileged:
            capabilityBannerMessage = adapter.isAvailable
                ? "Privileged capture is running with sudo/root access. Payloads may include sensitive data."
                : adapter.availabilityMessage
        }
    }

    func setPayloadInspection(_ enabled: Bool) {
        guard let adapter = selectedCaptureAdapter else {
            payloadInspectionEnabled = false
            payloadWarningMessage = "Select a capture mode before enabling payload inspection."
            return
        }
        if enabled {
            guard adapter.supportsPayloadInspection else {
                payloadInspectionEnabled = false
                payloadWarningMessage = "Payload inspection is only available when privileged capture is active."
                persistPreferences()
                return
            }
            guard payloadConsentGranted else {
                payloadInspectionEnabled = false
                payloadWarningMessage = "Acknowledge the payload privacy warning before enabling inspection."
                persistPreferences()
                return
            }
            if adapter.requiresPrivileges && !adapter.isAvailable {
                payloadInspectionEnabled = false
                payloadWarningMessage = adapter.availabilityMessage
                persistPreferences()
                return
            }
            payloadInspectionEnabled = true
            payloadWarningMessage = nil
            persistPreferences()
        } else {
            payloadInspectionEnabled = false
            persistPreferences()
        }
    }

    func clearPayloadWarning() {
        payloadWarningMessage = nil
    }

    private var selectedCaptureAdapter: CaptureAdapter? {
        captureAdapters.first(where: { $0.mode == selectedCaptureMode })
    }

    private var currentPayloadConfig: AnalyzerPayloadConfig {
        AnalyzerPayloadConfig(
            captureMode: selectedCaptureMode.rawValue,
            payloadInspectionEnabled: payloadInspectionEnabled
        )
    }

    private func loadPreferences() {
        guard let data = preferencesDefaults.data(forKey: preferencesKey) else { return }
        do {
            let stored = try JSONDecoder().decode(StoredPreferences.self, from: data)
            isRestoringPreferences = true
            defer { isRestoringPreferences = false }

            if let mode = CaptureMode(rawValue: stored.captureMode) {
                selectedCaptureMode = mode
            }
            windowSeconds = stored.windowSeconds
            zThreshold = stored.zThreshold
            selectedTimeRange = stored.timeRange
            if let algorithm = AnalyzerAlgorithm(rawValue: stored.algorithm) {
                selectedAlgorithm = algorithm
            }
            ewmaAlpha = stored.ewmaAlpha
            payloadInspectionEnabled = stored.payloadInspectionEnabled
            payloadConsentGranted = stored.payloadInspectionEnabled
        } catch {
            // Ignore corrupted preferences; defaults will be used instead.
        }
    }

    private func persistPreferences() {
        if isRestoringPreferences { return }
        let stored = StoredPreferences(
            captureMode: selectedCaptureMode.rawValue,
            windowSeconds: windowSeconds,
            zThreshold: zThreshold,
            timeRange: selectedTimeRange,
            algorithm: selectedAlgorithm.rawValue,
            ewmaAlpha: ewmaAlpha,
            payloadInspectionEnabled: payloadInspectionEnabled
        )
        if let data = try? JSONEncoder().encode(stored) {
            preferencesDefaults.set(data, forKey: preferencesKey)
        }
    }

    private func makeSessionSnapshot() -> AnalyzerSession {
        let preferencesSnapshot = AnalyzerPreferencesSnapshot(
            captureMode: selectedCaptureMode.rawValue,
            windowSeconds: windowSeconds,
            zThreshold: zThreshold,
            timeRange: selectedTimeRange,
            algorithm: selectedAlgorithm.rawValue,
            ewmaAlpha: ewmaAlpha,
            payloadInspectionEnabled: payloadInspectionEnabled
        )
        return AnalyzerSession(
            createdAt: Date(),
            summary: captureSummary,
            packets: packets,
            perSecondMetrics: perSecondMetrics,
            perMinuteMetrics: perMinuteMetrics,
            analyzerResult: analyzerResult,
            streamingAnomalies: streamingAnomalies,
            preferences: preferencesSnapshot
        )
    }

    private func restore(from session: AnalyzerSession) {
        resetCaptureState(label: session.summary.interfaceName, interface: session.summary.interfaceName, clearPackets: true)
        packets = session.packets
        packetCounter = session.summary.packetCount
        totalBytes = session.summary.totalBytes
        captureStart = session.summary.start
        captureEnd = session.summary.end
        captureSummary = session.summary

        perSecondSeries = session.perSecondMetrics
        perSecondMetrics = session.perSecondMetrics
        perMinuteSeriesStorage = session.perMinuteMetrics
        perMinuteMetrics = session.perMinuteMetrics
        filteredPerSecondMetrics = session.perSecondMetrics
        filteredPerMinuteMetrics = session.perMinuteMetrics

        analyzerResult = session.analyzerResult
        streamingAnomalies = session.streamingAnomalies
        seenAnomalyKeys = Set(streamingAnomalies.map(anomalyKey))

        payloadInspectionEnabled = session.preferences.payloadInspectionEnabled
        payloadConsentGranted = session.preferences.payloadInspectionEnabled

        isRestoringPreferences = true
        if let mode = CaptureMode(rawValue: session.preferences.captureMode) {
            selectedCaptureMode = mode
        }
        windowSeconds = session.preferences.windowSeconds
        zThreshold = session.preferences.zThreshold
        selectedTimeRange = session.preferences.timeRange
        if let algorithm = AnalyzerAlgorithm(rawValue: session.preferences.algorithm) {
            selectedAlgorithm = algorithm
        }
        ewmaAlpha = session.preferences.ewmaAlpha
        isRestoringPreferences = false
        persistPreferences()

        updateTagAvailability()
        applyFilters()
        scheduleStreamingAnalysis()
        captureState = .completed(session.summary.interfaceName ?? "Saved Session")
    }

    private func buildMetricsCSV() -> String {
        var rows: [String] = ["timestamp,bytesPerSecond,packetsPerSecond,flowsPerSecond"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        for metric in perSecondMetrics {
            rows.append("\(formatter.string(from: metric.timestamp)),\(metric.bytesPerSecond),\(metric.packetsPerSecond),\(metric.flowsPerSecond)")
        }
        return rows.joined(separator: "\n")
    }

    private func buildReportPDF() throws -> Data {
        let session = makeSessionSnapshot()
        let content = buildReportText(for: session)
        let pageSize = NSSize(width: 612, height: 792)
        let textView = NSTextView(frame: NSRect(origin: .zero, size: pageSize))
        textView.string = content
        textView.isEditable = false
        textView.drawsBackground = false
        textView.font = NSFont.monospacedSystemFont(ofSize: 11, weight: .regular)
        return textView.dataWithPDF(inside: textView.bounds)
    }

    private func buildReportText(for session: AnalyzerSession) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        var lines: [String] = []
        lines.append("Aman Network Analyzer Report")
        lines.append("Generated: \(formatter.string(from: session.createdAt))")
        lines.append("")
        lines.append("Capture Summary")
        lines.append("Packets: \(session.summary.packetCount)")
        lines.append("Bytes: \(session.summary.totalBytes)")
        if let start = session.summary.start {
            lines.append("Start: \(formatter.string(from: start))")
        }
        if let end = session.summary.end {
            lines.append("End: \(formatter.string(from: end))")
        }
        lines.append("")

        if let result = session.analyzerResult {
            lines.append("Analyzer Summary")
            lines.append("Mean Bytes/s: \(String(format: "%.2f", result.summary.meanBytesPerSecond))")
            lines.append("Mean Packets/s: \(String(format: "%.2f", result.summary.meanPacketsPerSecond))")
            lines.append("Window: \(result.summary.windowSeconds)s")
            lines.append("Threshold: \(String(format: "%.2f", result.summary.zThreshold))")
            if let payload = result.payloadSummary, !payload.isEmpty {
                lines.append("")
                lines.append("Payload Summary")
                for (key, value) in payload.sorted(by: { $0.key < $1.key }) {
                    lines.append("\(key): \(String(format: "%.2f", value))")
                }
            }
            lines.append("")
            if result.anomalies.isEmpty {
                lines.append("Anomalies: none detected above threshold")
            } else {
                lines.append("Anomalies (\(result.anomalies.count))")
                for anomaly in result.anomalies.prefix(50) {
                    let time = formatter.string(from: anomaly.timestamp)
                    lines.append("- [\(time)] \(anomaly.metric) = \(String(format: "%.2f", anomaly.value)) (z=\(String(format: "%.2f", anomaly.zScore)))")
                    if let tagType = anomaly.tagType, let tagValue = anomaly.tagValue {
                        lines.append("  Tag: \(tagType) = \(tagValue)")
                    }
                }
                if result.anomalies.count > 50 {
                    lines.append("… \(result.anomalies.count - 50) more anomalies")
                }
            }
        } else if !session.streamingAnomalies.isEmpty {
            lines.append("Streaming Anomalies (\(session.streamingAnomalies.count))")
            for anomaly in session.streamingAnomalies.prefix(50) {
                let time = formatter.string(from: anomaly.timestamp)
                lines.append("- [\(time)] \(anomaly.metric) = \(String(format: "%.2f", anomaly.value)) (z=\(String(format: "%.2f", anomaly.zScore)))")
            }
            if session.streamingAnomalies.count > 50 {
                lines.append("… \(session.streamingAnomalies.count - 50) more anomalies")
            }
        }

        lines.append("")
        lines.append("Preferences")
        lines.append("Capture Mode: \(session.preferences.captureMode)")
        lines.append("Algorithm: \(session.preferences.algorithm.uppercased())")
        lines.append("Window Seconds: \(session.preferences.windowSeconds)")
        lines.append("Threshold: \(String(format: "%.2f", session.preferences.zThreshold))")
        lines.append("Time Range: \(String(format: "%.0f", session.preferences.timeRange))s")
        lines.append("EWMA Alpha: \(String(format: "%.2f", session.preferences.ewmaAlpha))")
        lines.append("Payload Inspection: \(session.preferences.payloadInspectionEnabled ? "Enabled" : "Disabled")")

        return lines.joined(separator: "\n")
    }

    // MARK: - Capture controls

    func startCapture() {
        guard let ifaceName = selectedInterfaceName,
              let iface = interfaces.first(where: { $0.name == ifaceName }) else {
            errorMessage = "Select an interface before starting capture."
            return
        }
        guard !captureControllerIsRunning else {
            errorMessage = "Capture already running."
            return
        }

        guard let adapter = selectedCaptureAdapter else {
            errorMessage = "Capture mode unavailable."
            return
        }

        guard adapter.isAvailable else {
            errorMessage = adapter.availabilityMessage
            capabilityBannerMessage = adapter.availabilityMessage
            captureState = .failed(adapter.availabilityMessage)
            return
        }

        stopFallbackSampling()
        resetCaptureState(label: iface.name, interface: iface.name, clearPackets: true)
        captureState = .capturing(iface.name)
        errorMessage = nil

        let configMode: PcapCaptureController.Config.Mode = adapter.mode == .privileged ? .privileged : .standard
        let shouldCapturePayload = payloadInspectionEnabled && adapter.supportsPayloadInspection
        let config = PcapCaptureController.Config(
            interface: iface.name,
            bpfFilter: bpfFilter,
            mode: configMode,
            capturePayload: shouldCapturePayload
        )
        do {
            try captureController.start(config: config)
        } catch {
            captureState = .failed(error.localizedDescription)
            errorMessage = error.localizedDescription
            startFallbackSampling(interfaceName: iface.name)
        }
    }

    func stopCapture() {
        if captureControllerIsRunning {
            captureController.stop()
        }
        stopFallbackSampling()
        flushPendingBuckets()
        if let label = activeCaptureLabel {
            captureState = .completed(label)
        } else {
            captureState = .completed("Capture")
        }
        finalizeCaptureWindow()
    }

    func clearCapture() {
        resetCaptureState(label: nil, interface: selectedInterfaceName, clearPackets: true)
        analyzerResult = nil
        streamingAnomalies = []
        seenAnomalyKeys.removeAll()
        analyzerState = .idle
        stopFallbackSampling()
    }

    func setProtocolFilter(_ value: String?) {
        selectedProtocolFilter = value
        applyFilters()
    }

    func setDestinationFilter(_ value: String?) {
        selectedDestinationFilter = value
        applyFilters()
    }

    func setPortFilter(_ value: String?) {
        selectedPortFilter = value
        applyFilters()
    }

    func setTimeRange(_ value: TimeInterval) {
        selectedTimeRange = max(10, value)
    }

    // MARK: - Offline capture loading

    func loadSampleCapture(index: Int) {
        let filename: String
        let ext: String
        switch index {
        case 1:
            filename = "pcap1"
            ext = "pcapng"
        case 2:
            filename = "pcap2"
            ext = "pcap"
        default:
            return
        }

        guard let url = Bundle.main.url(forResource: filename, withExtension: ext) else {
            errorMessage = "Sample \(filename).\(ext) not found in bundle."
            captureState = .failed("Missing sample")
            return
        }

        loadCapture(from: url, label: "\(filename).\(ext)")
    }

    func importCaptureFromDisk() {
        let panel = NSOpenPanel()
        panel.title = "Import Capture"
        panel.allowedContentTypes = [
            UTType(filenameExtension: "pcapng") ?? .data,
            UTType(filenameExtension: "pcap") ?? .data
        ]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        loadCapture(from: url, label: url.lastPathComponent)
    }

    private func loadCapture(from url: URL, label: String) {
        captureState = .loading(label)
        errorMessage = nil
        resetCaptureState(label: label, interface: nil, clearPackets: true)

        Task.detached { [weak self] in
            guard let self else { return }
            do {
                let parsed = try Self.parseOfflineCapture(at: url)
                await MainActor.run {
                    self.applyParsedCapture(parsed, label: label)
                }
            } catch {
                await MainActor.run {
                    self.captureState = .failed(label)
                    self.errorMessage = error.localizedDescription
                }
            }
        }
    }

    // MARK: - Session persistence & export

    func saveSessionToDisk() {
        let panel = NSSavePanel()
        panel.title = "Save Analyzer Session"
        panel.allowedContentTypes = [UTType(filenameExtension: "amanSession") ?? .json]
        panel.nameFieldStringValue = "AmanSession.amanSession"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let session = makeSessionSnapshot()
            let encoder = JSONEncoder.iso8601Fractional()
            let data = try encoder.encode(session)
            try data.write(to: url)
        } catch {
            errorMessage = "Failed to save session: \(error.localizedDescription)"
        }
    }

    func loadSessionFromDisk() {
        let panel = NSOpenPanel()
        panel.title = "Open Analyzer Session"
        panel.allowedContentTypes = [UTType(filenameExtension: "amanSession") ?? .json]
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder.iso8601Fractional()
            let session = try decoder.decode(AnalyzerSession.self, from: data)
            restore(from: session)
        } catch {
            errorMessage = "Failed to load session: \(error.localizedDescription)"
        }
    }

    func exportMetricsCSV() {
        let panel = NSSavePanel()
        panel.title = "Export Metrics (CSV)"
        panel.allowedContentTypes = [UTType.commaSeparatedText]
        panel.nameFieldStringValue = "AmanMetrics.csv"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let csv = buildMetricsCSV()
            try csv.data(using: .utf8)?.write(to: url)
        } catch {
            errorMessage = "Failed to export CSV: \(error.localizedDescription)"
        }
    }

    func exportSessionJSON() {
        let panel = NSSavePanel()
        panel.title = "Export Session (JSON)"
        panel.allowedContentTypes = [UTType.json]
        panel.nameFieldStringValue = "AmanSession.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let session = makeSessionSnapshot()
            let encoder = JSONEncoder.iso8601Fractional()
            encoder.outputFormatting.insert(.prettyPrinted)
            let data = try encoder.encode(session)
            try data.write(to: url)
        } catch {
            errorMessage = "Failed to export JSON: \(error.localizedDescription)"
        }
    }

    func exportReportPDF() {
        let panel = NSSavePanel()
        panel.title = "Export Report (PDF)"
        panel.allowedContentTypes = [UTType.pdf]
        panel.nameFieldStringValue = "AmanReport.pdf"
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let data = try buildReportPDF()
            try data.write(to: url)
        } catch {
            errorMessage = "Failed to export PDF: \(error.localizedDescription)"
        }
    }

    // MARK: - Analyzer (manual)

    func runAnalyzer() {
        guard !perSecondSeries.isEmpty else {
            errorMessage = "No metric points available. Start a capture first."
            return
        }
        guard let scriptURL = Bundle.main.url(forResource: "analyzer", withExtension: "py") else {
            errorMessage = PythonRunnerError.scriptNotFound("analyzer.py").localizedDescription
            return
        }

        analyzerState = .running
        errorMessage = nil
        analysisWorkItem?.cancel()
        let metricsSnapshot = perSecondSeries
        let packetSnapshot = packets
        let params = AnalyzerParams(windowSeconds: windowSeconds, zThreshold: zThreshold, algorithm: selectedAlgorithm.rawValue, ewmaAlpha: ewmaAlpha)
        let payloadConfig = currentPayloadConfig

        analysisQueue.async { [weak self] in
            self?.executeAnalysis(scriptURL: scriptURL, metrics: metricsSnapshot, packets: packetSnapshot, params: params, payloadConfig: payloadConfig, markState: true, isStreaming: false)
        }
    }

    // MARK: - Live capture callbacks

    private var captureControllerIsRunning: Bool {
        if case .capturing = captureState { return true }
        return false
    }

    private func configureCaptureCallbacks() {
        captureController.onPacketLine = { [weak self] line in
            guard let self, let packet = Self.parsePacketLine(line) else { return }
            Task { @MainActor in
                self.insert(packet: packet)
            }
        }

        captureController.onError = { [weak self] error in
            guard let self else { return }
            Task { @MainActor in
                self.captureState = .failed(error.localizedDescription)
                self.errorMessage = error.localizedDescription
                self.captureController.stop()
                self.startFallbackSampling(interfaceName: self.selectedInterfaceName)
            }
        }
    }

    // MARK: - Packet ingestion & metrics

    private func insert(packet parsed: ParsedPacket) {
        if captureStart == nil { captureStart = parsed.timestamp }

        packetCounter += 1
        let relative = parsed.timestamp.timeIntervalSince(captureStart ?? parsed.timestamp)
        let sample = PacketSample(
            id: packetCounter,
            timestamp: parsed.timestamp,
            relativeTime: relative,
            source: parsed.source,
            destination: parsed.destination,
            sourceIP: parsed.sourceIP,
            sourcePort: parsed.sourcePort,
            destinationIP: parsed.destinationIP,
            destinationPort: parsed.destinationPort,
            protocolName: parsed.l4Protocol,
            processName: nil,
            length: parsed.length,
            info: parsed.info
        )

        packets.append(sample)
        if packets.count > maxPacketBuffer {
            packets.removeFirst(packets.count - maxPacketBuffer)
        }

        totalBytes += parsed.length
        captureEnd = parsed.timestamp

        accumulate(sample: sample, protocolName: parsed.l4Protocol)
        finalizeBuckets(before: sample.timestamp)
        updateSummary(interface: activeInterfaceName)
    }

    private func accumulate(sample: PacketSample, protocolName: String, bucketSize: TimeInterval = 1.0) {
        let epoch = floor(sample.timestamp.timeIntervalSince1970 / bucketSize) * bucketSize
        let bucketDate = Date(timeIntervalSince1970: epoch)
        var bucket = secondBuckets[bucketDate] ?? SecondBucket()
        bucket.bytes += sample.length
        bucket.packets += 1
        if !sample.source.isEmpty || !sample.destination.isEmpty {
            let flow = "\(protocolName)|\(sample.source)=>\(sample.destination)"
            bucket.flows.insert(flow)
        }
        if !protocolName.isEmpty {
            var accumulator = bucket.protocols[protocolName] ?? TagAccumulator()
            accumulator.add(bytes: sample.length)
            bucket.protocols[protocolName] = accumulator
        }
        let destinationKey: String = {
            if let ip = sample.destinationIP, !ip.isEmpty { return ip }
            return sample.destination
        }()
        if !destinationKey.isEmpty {
            var accumulator = bucket.destinations[destinationKey] ?? TagAccumulator()
            accumulator.add(bytes: sample.length)
            bucket.destinations[destinationKey] = accumulator
        }
        if let port = sample.destinationPort, !port.isEmpty {
            var accumulator = bucket.destinationPorts[port] ?? TagAccumulator()
            accumulator.add(bytes: sample.length)
            bucket.destinationPorts[port] = accumulator
        }
        secondBuckets[bucketDate] = bucket
    }

    private func finalizeBuckets(before timestamp: Date) {
        let cutoffEpoch = floor(timestamp.timeIntervalSince1970)
        let readyKeys = secondBuckets.keys.filter { $0.timeIntervalSince1970 < cutoffEpoch }
        guard !readyKeys.isEmpty else { return }
        for key in readyKeys.sorted() {
            guard let bucket = secondBuckets.removeValue(forKey: key) else { continue }
            emitMetric(for: key, bucket: bucket)
        }
        scheduleStreamingAnalysis()
    }

    private func emitMetric(for timestamp: Date, bucket: SecondBucket) {
        let protocolHistogram = Dictionary(uniqueKeysWithValues: bucket.protocols.map { ($0.key, $0.value.packets) })
        let metric = MetricPoint(
            timestamp: timestamp,
            window: .perSecond,
            bytesPerSecond: Double(bucket.bytes),
            packetsPerSecond: Double(bucket.packets),
            flowsPerSecond: Double(bucket.flows.count),
            protocolHistogram: protocolHistogram,
            tagMetrics: buildTagMetrics(from: bucket)
        )

        perSecondSeries.append(metric)
        if perSecondSeries.count > maxPerSecondPoints {
            perSecondSeries.removeFirst(perSecondSeries.count - maxPerSecondPoints)
        }
        perSecondMetrics = perSecondSeries

        updateMinuteSeries(with: metric, flows: bucket.flows)
    }

    private func buildTagMetrics(from bucket: SecondBucket) -> [String: [String: TagMetric]] {
        func top(_ dictionary: [String: TagAccumulator], limit: Int = 8) -> [String: TagMetric] {
            dictionary
                .sorted { $0.value.bytes > $1.value.bytes }
                .prefix(limit)
                .reduce(into: [String: TagMetric]()) { result, entry in
                    result[entry.key] = TagMetric(bytes: Double(entry.value.bytes), packets: Double(entry.value.packets))
                }
        }

        var result: [String: [String: TagMetric]] = [:]
        let protocols = top(bucket.protocols)
        if !protocols.isEmpty { result["protocol"] = protocols }
        let destinations = top(bucket.destinations)
        if !destinations.isEmpty { result["destination"] = destinations }
        let ports = top(bucket.destinationPorts)
        if !ports.isEmpty { result["port"] = ports }
        return result
    }

    private func buildMinuteTagMetrics(limit: Int = 10) -> [String: [String: TagMetric]] {
        var result: [String: [String: TagMetric]] = [:]
        for (tagType, entries) in minuteTagTotals {
            let topEntries = entries
                .sorted { $0.value.bytes > $1.value.bytes }
                .prefix(limit)
                .reduce(into: [String: TagMetric]()) { dict, entry in
                    dict[entry.key] = TagMetric(bytes: entry.value.bytes, packets: entry.value.packets)
                }
            if !topEntries.isEmpty {
                result[tagType] = topEntries
            }
        }
        return result
    }

    private func updateTagAvailability() {
        func sortedKeys<T>(_ dictionary: [String: T]) -> [String] {
            dictionary.keys.sorted()
        }

        availableProtocols = sortedKeys(minuteTagTotals["protocol"] ?? [:])
        availableDestinations = sortedKeys(minuteTagTotals["destination"] ?? [:])
        availablePorts = sortedKeys(minuteTagTotals["port"] ?? [:])

        topProtocols = makeTopRanks(from: minuteTagTotals["protocol"], tagType: "protocol")
        topDestinations = makeTopRanks(from: minuteTagTotals["destination"], tagType: "destination")
        topPorts = makeTopRanks(from: minuteTagTotals["port"], tagType: "port")
    }

    private func makeTopRanks(from totals: [String: TagTotals]?, tagType: String, limit: Int = 8) -> [TagRank] {
        guard let totals else { return [] }
        return totals
            .sorted { $0.value.bytes > $1.value.bytes }
            .prefix(limit)
            .map { TagRank(tagType: tagType, value: $0.key, bytes: $0.value.bytes, packets: $0.value.packets) }
    }

    private func applyFilters() {
        let referenceTime = perSecondSeries.last?.timestamp ?? Date()
        let cutoff = referenceTime.addingTimeInterval(-selectedTimeRange)
        let protocolFilter = selectedProtocolFilter?.isEmpty == false ? selectedProtocolFilter : nil
        let destinationFilter = selectedDestinationFilter?.isEmpty == false ? selectedDestinationFilter : nil
        let portFilter = selectedPortFilter?.isEmpty == false ? selectedPortFilter : nil

        filteredPerSecondMetrics = perSecondSeries.filter { metricMatches($0, cutoff: cutoff, protocolFilter: protocolFilter, destinationFilter: destinationFilter, portFilter: portFilter) }
        filteredPerMinuteMetrics = perMinuteSeriesStorage.filter { metricMatches($0, cutoff: cutoff, protocolFilter: protocolFilter, destinationFilter: destinationFilter, portFilter: portFilter) }

        filteredPackets = packets.filter { packet in
            guard packet.timestamp >= cutoff else { return false }
            if let protocolFilter = protocolFilter, packet.protocolName != protocolFilter { return false }
            if let destinationFilter = destinationFilter {
                let candidate = (packet.destinationIP?.isEmpty == false ? packet.destinationIP! : packet.destination)
                if candidate != destinationFilter { return false }
            }
            if let portFilter = portFilter, packet.destinationPort != portFilter { return false }
            return true
        }

        if let selectedID = selectedPacketID,
           !filteredPackets.contains(where: { $0.id == selectedID }) {
            selectedPacketID = filteredPackets.last?.id
        }

        rebuildInsights()
    }

    private func metricMatches(_ metric: MetricPoint, cutoff: Date, protocolFilter: String?, destinationFilter: String?, portFilter: String?) -> Bool {
        guard metric.timestamp >= cutoff else { return false }
        if let protocolFilter = protocolFilter {
            let protocols = metric.tagMetrics["protocol"] ?? [:]
            if protocols[protocolFilter] == nil { return false }
        }
        if let destinationFilter = destinationFilter {
            let destinations = metric.tagMetrics["destination"] ?? [:]
            if destinations[destinationFilter] == nil { return false }
        }
        if let portFilter = portFilter {
            let ports = metric.tagMetrics["port"] ?? [:]
            if ports[portFilter] == nil { return false }
        }
        return true
    }

    private func updateMinuteSeries(with metric: MetricPoint, flows: Set<String>) {
        minuteWindow.append(metric)
        minuteBytesSum += metric.bytesPerSecond
        minutePacketsSum += metric.packetsPerSecond
        for (proto, count) in metric.protocolHistogram {
            minuteProtocolHistogram[proto, default: 0] += count
        }
        for (tagType, entries) in metric.tagMetrics {
            var totals = minuteTagTotals[tagType] ?? [:]
            for (value, tagMetric) in entries {
                var total = totals[value] ?? TagTotals()
                total.add(bytes: tagMetric.bytes, packets: tagMetric.packets)
                totals[value] = total
            }
            minuteTagTotals[tagType] = totals
        }

        let threshold = metric.timestamp.addingTimeInterval(-59)
        while let first = minuteWindow.first, first.timestamp < threshold {
            minuteWindow.removeFirst()
            minuteBytesSum -= first.bytesPerSecond
            minutePacketsSum -= first.packetsPerSecond
            for (proto, count) in first.protocolHistogram {
                let remaining = (minuteProtocolHistogram[proto] ?? 0) - count
                if remaining <= 0 {
                    minuteProtocolHistogram.removeValue(forKey: proto)
                } else {
                    minuteProtocolHistogram[proto] = remaining
                }
            }
            for (tagType, entries) in first.tagMetrics {
                guard var totals = minuteTagTotals[tagType] else { continue }
                for (value, tagMetric) in entries {
                    if var total = totals[value] {
                        total.subtract(bytes: tagMetric.bytes, packets: tagMetric.packets)
                        if total.bytes <= 0.1 && total.packets <= 0.1 {
                            totals.removeValue(forKey: value)
                        } else {
                            totals[value] = total
                        }
                    }
                }
                minuteTagTotals[tagType] = totals
            }
        }

        for flow in flows {
            flowLastSeen[flow] = metric.timestamp
        }
        let flowThreshold = metric.timestamp.addingTimeInterval(-59)
        flowLastSeen = flowLastSeen.filter { $0.value >= flowThreshold }

        guard !minuteWindow.isEmpty else { return }
        let duration = Double(minuteWindow.count)
        let avgBytes = minuteBytesSum / duration
        let avgPackets = minutePacketsSum / duration
        let flowCount = Double(flowLastSeen.count)
        let minuteTagMetrics = buildMinuteTagMetrics()
        let minuteMetric = MetricPoint(
            timestamp: metric.timestamp,
            window: .perMinute,
            bytesPerSecond: avgBytes,
            packetsPerSecond: avgPackets,
            flowsPerSecond: flowCount,
            protocolHistogram: minuteProtocolHistogram,
            tagMetrics: minuteTagMetrics
        )
        perMinuteSeriesStorage.append(minuteMetric)
        if perMinuteSeriesStorage.count > maxPerMinutePoints {
            perMinuteSeriesStorage.removeFirst(perMinuteSeriesStorage.count - maxPerMinutePoints)
        }
        perMinuteMetrics = perMinuteSeriesStorage
        updateTagAvailability()
        applyFilters()
    }

    private func flushPendingBuckets() {
        guard !secondBuckets.isEmpty else { return }
        for key in secondBuckets.keys.sorted() {
            if let bucket = secondBuckets.removeValue(forKey: key) {
                emitMetric(for: key, bucket: bucket)
            }
        }
        scheduleStreamingAnalysis()
    }

    private func scheduleStreamingAnalysis() {
        guard !perSecondSeries.isEmpty else { return }
        analysisWorkItem?.cancel()
        let metricsSlice = Array(perSecondSeries.suffix(streamingWindowSeconds))
        let packetSlice = Array(packets.suffix(maxPacketBuffer))
        let params = AnalyzerParams(windowSeconds: windowSeconds, zThreshold: zThreshold, algorithm: selectedAlgorithm.rawValue, ewmaAlpha: ewmaAlpha)
        let payloadConfig = currentPayloadConfig

        guard let scriptURL = Bundle.main.url(forResource: "analyzer", withExtension: "py") else { return }

        let work = DispatchWorkItem { [weak self] in
            self?.executeAnalysis(scriptURL: scriptURL, metrics: metricsSlice, packets: packetSlice, params: params, payloadConfig: payloadConfig, markState: false, isStreaming: true)
        }
        analysisWorkItem = work
        analysisQueue.asyncAfter(deadline: .now() + analysisDebounceInterval, execute: work)
    }

    private func executeAnalysis(scriptURL: URL, metrics: [MetricPoint], packets: [PacketSample], params: AnalyzerParams, payloadConfig: AnalyzerPayloadConfig, markState: Bool, isStreaming: Bool) {
        guard !metrics.isEmpty else { return }
        do {
            let encoder = JSONEncoder.iso8601Fractional()
            let request = AnalyzerRequest(packets: packets, metrics: metrics, params: params, payloadConfig: payloadConfig)
            let payload = try encoder.encode(request)
            let output: AnalyzerResult = try pythonRunner.runJSONScript(scriptURL: scriptURL, requestJSON: payload, responseType: AnalyzerResult.self)

            Task { @MainActor in
                if markState { self.analyzerState = .ready }
                self.handleAnalyzerOutput(output, isStreaming: isStreaming)
            }
        } catch {
            Task { @MainActor in
                if markState {
                    self.analyzerState = .idle
                }
                self.errorMessage = error.localizedDescription
            }
        }
    }

    private func handleAnalyzerOutput(_ result: AnalyzerResult, isStreaming: Bool) {
        analyzerResult = result
        if isStreaming {
            var fresh: [Anomaly] = []
            for anomaly in result.anomalies {
                let key = anomalyKey(for: anomaly)
                if seenAnomalyKeys.insert(key).inserted {
                    fresh.append(anomaly)
                }
            }
            if !fresh.isEmpty {
                streamingAnomalies.append(contentsOf: fresh)
                if streamingAnomalies.count > 200 {
                    streamingAnomalies.removeFirst(streamingAnomalies.count - 200)
                }
            }
        } else {
            streamingAnomalies = result.anomalies
            seenAnomalyKeys = Set(result.anomalies.map(anomalyKey))
        }
        rebuildInsights()
    }

    private func anomalyKey(for anomaly: Anomaly) -> String {
        let tagComponent = "\(anomaly.tagType ?? "_")|\(anomaly.tagValue ?? "_")"
        return "\(anomaly.timestamp.timeIntervalSince1970)-\(anomaly.metric)-\(anomaly.direction.rawValue)-\(tagComponent)"
    }

    // MARK: - Narrative insights

    func setTimelineCursor(_ value: Double) {
        let clamped = max(0.0, min(1.0, value))
        if timelineCursorProgress != clamped {
            timelineCursorProgress = clamped
        } else {
            updateTimelineCursorTimestamp()
        }
    }

    func selectCluster(_ cluster: CorrelationCluster?) {
        selectedClusterID = cluster?.id
        if let cluster, let representative = cluster.anomalyIDs.first {
            selectedAnomalyID = representative
        } else if cluster == nil {
            selectedAnomalyID = nil
        }
    }

    func selectAnomaly(_ anomaly: Anomaly) {
        selectedAnomalyID = anomaly.id
        if let cluster = correlationClusters.first(where: { $0.anomalyIDs.contains(anomaly.id) }) {
            selectedClusterID = cluster.id
        } else {
            selectedClusterID = nil
        }
    }

    private func rebuildInsights() {
        let remoteClusters = filteredClusters(analyzerResult?.clusters ?? [])
        let clusters = remoteClusters.isEmpty ? computeCorrelationClusters() : remoteClusters
        correlationClusters = clusters
        rebuildTimelineAnnotations(with: clusters)
        if let selectedClusterID,
           !clusters.contains(where: { $0.id == selectedClusterID }) {
            self.selectedClusterID = clusters.first?.id
        } else {
            updateActiveClusterContext()
        }
        updateTimelineCursorTimestamp()
    }

    private func computeCorrelationClusters() -> [CorrelationCluster] {
        let sourceAnomalies = streamingAnomalies.isEmpty ? (analyzerResult?.anomalies ?? []) : streamingAnomalies
        guard !sourceAnomalies.isEmpty else { return [] }

        let referenceTime = filteredPerSecondMetrics.last?.timestamp ??
            perSecondSeries.last?.timestamp ??
            captureEnd ??
            Date()
        let cutoff = referenceTime.addingTimeInterval(-selectedTimeRange)

        let protocolFilter = selectedProtocolFilter
        let destinationFilter = selectedDestinationFilter
        let portFilter = selectedPortFilter

        struct ClusterAccumulation {
            var tagType: String?
            var tagValue: String?
            var metric: String
            var anomalies: [Anomaly] = []
        }

        var buckets: [String: ClusterAccumulation] = [:]

        for anomaly in sourceAnomalies {
            guard anomaly.timestamp >= cutoff else { continue }
            if let protocolFilter,
               anomaly.tagType != "protocol" || anomaly.tagValue != protocolFilter {
                continue
            }
            if let destinationFilter,
               anomaly.tagType != "destination" || anomaly.tagValue != destinationFilter {
                continue
            }
            if let portFilter,
               anomaly.tagType != "port" || anomaly.tagValue != portFilter {
                continue
            }

            let keyType = anomaly.tagType ?? "metric"
            let keyValue = anomaly.tagValue ?? anomaly.metric
            let bucketKey = "\(keyType)|\(keyValue)"
            var bucket = buckets[bucketKey] ?? ClusterAccumulation(tagType: anomaly.tagType, tagValue: anomaly.tagValue, metric: anomaly.metric)
            bucket.anomalies.append(anomaly)
            buckets[bucketKey] = bucket
        }

        var clusters: [CorrelationCluster] = []
        clusters.reserveCapacity(buckets.count)

        for (_, bucket) in buckets {
            guard !bucket.anomalies.isEmpty else { continue }
            let sorted = bucket.anomalies.sorted { $0.timestamp < $1.timestamp }
            guard let first = sorted.first, let last = sorted.last else { continue }
            let peakAnomaly = sorted.max(by: { abs($0.zScore) < abs($1.zScore) }) ?? first
            let peakBytes = sorted.compactMap { anomalyBytes($0) }.max()
            let totalBytes = sorted.compactMap { anomalyBytes($0) }.reduce(0, +)
            let confidence = min(1.0, Double(sorted.count) / 6.0)
            let narrative: String = {
                let actor = bucket.tagValue ?? bucket.metric
                let highlighted = peakBytes.map { formatBytes($0) } ?? String(format: "%.1f", peakAnomaly.value)
                let direction = peakAnomaly.direction == .spike ? "spike" : "drop"
                if let type = bucket.tagType, let value = bucket.tagValue {
                    return "\(type.capitalized) \(value) saw a \(direction) peaking at \(highlighted) (\(String(format: "%.1fσ", abs(peakAnomaly.zScore))))"
                } else {
                    return "\(actor) registered a \(direction) peaking at \(highlighted) (\(String(format: "%.1fσ", abs(peakAnomaly.zScore))))"
                }
            }()

            let cluster = CorrelationCluster(
                id: UUID(),
                tagType: bucket.tagType,
                tagValue: bucket.tagValue,
                metric: bucket.metric,
                window: first.timestamp ... last.timestamp,
                peakTimestamp: peakAnomaly.timestamp,
                peakValue: peakAnomaly.value,
                peakZScore: abs(peakAnomaly.zScore),
                totalAnomalies: sorted.count,
                totalBytes: totalBytes > 0 ? totalBytes : nil,
                confidence: confidence,
                narrative: narrative,
                anomalyIDs: sorted.map(\.id)
            )
            clusters.append(cluster)
        }

        clusters.sort { lhs, rhs in
            if lhs.peakZScore == rhs.peakZScore {
                return lhs.peakTimestamp < rhs.peakTimestamp
            }
            return lhs.peakZScore > rhs.peakZScore
        }
        return clusters
    }

    private func filteredClusters(_ clusters: [CorrelationCluster]) -> [CorrelationCluster] {
        guard !clusters.isEmpty else { return [] }
        let referenceTime = filteredPerSecondMetrics.last?.timestamp ??
            perSecondSeries.last?.timestamp ??
            captureEnd ??
            Date()
        let cutoff = referenceTime.addingTimeInterval(-selectedTimeRange)

        return clusters.filter { cluster in
            guard cluster.window.upperBound >= cutoff else { return false }
            if let protocolFilter = selectedProtocolFilter {
                guard cluster.tagType == "protocol", cluster.tagValue == protocolFilter else { return false }
            }
            if let destinationFilter = selectedDestinationFilter {
                guard cluster.tagType == "destination", cluster.tagValue == destinationFilter else { return false }
            }
            if let portFilter = selectedPortFilter {
                guard cluster.tagType == "port", cluster.tagValue == portFilter else { return false }
            }
            return true
        }
    }

    private func rebuildTimelineAnnotations(with clusters: [CorrelationCluster]) {
        guard !clusters.isEmpty else {
            timelineAnnotations = []
            return
        }

        let maxAnnotations = 40
        let selection = clusters.prefix(maxAnnotations)
        let annotations = selection.map { cluster in
            TimelineAnnotation(
                id: UUID(),
                timestamp: cluster.peakTimestamp,
                window: cluster.window,
                title: cluster.displayTag,
                subtitle: cluster.narrative,
                severity: TimelineAnnotation.Severity(zScore: cluster.peakZScore),
                tagType: cluster.tagType,
                tagValue: cluster.tagValue,
                clusterID: cluster.id,
                anomalyIDs: cluster.anomalyIDs
            )
        }
        timelineAnnotations = annotations.sorted { $0.timestamp < $1.timestamp }
    }

    private func anomalyBytes(_ anomaly: Anomaly) -> Double? {
        guard let context = anomaly.context else { return nil }
        if let raw = context["bytes"], let parsed = Double(raw) { return parsed }
        if let raw = context["value"], let parsed = Double(raw) { return parsed }
        return nil
    }

    private func updateActiveClusterContext() {
        guard let selectedClusterID else {
            activeClusterContext = nil
            return
        }
        activeClusterContext = correlationClusters.first(where: { $0.id == selectedClusterID })
    }

    private func updateTimelineCursorTimestamp() {
        guard !filteredPerSecondMetrics.isEmpty else {
            timelineCursorTimestamp = nil
            return
        }
        let metrics = filteredPerSecondMetrics
        guard let first = metrics.first?.timestamp,
              let last = metrics.last?.timestamp,
              last > first else {
            timelineCursorTimestamp = metrics.first?.timestamp
            return
        }
        let progress = min(max(timelineCursorProgress, 0.0), 1.0)
        let interval = last.timeIntervalSince(first)
        let target = first.addingTimeInterval(interval * progress)
        timelineCursorTimestamp = target

        if let selectedClusterID,
           let selected = correlationClusters.first(where: { $0.id == selectedClusterID }) {
            activeClusterContext = selected
            return
        }

        if let cluster = correlationClusters.first(where: { $0.window.contains(target) }) {
            activeClusterContext = cluster
        } else {
            activeClusterContext = nil
        }
    }

    private func formatBytes(_ value: Double) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .binary
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.includesActualByteCount = false
        formatter.isAdaptive = true
        return formatter.string(fromByteCount: Int64(value))
    }

    private struct StoredPreferences: Codable {
        let captureMode: String
        let windowSeconds: Int
        let zThreshold: Double
        let timeRange: TimeInterval
        let algorithm: String
        let ewmaAlpha: Double
        let payloadInspectionEnabled: Bool
    }

    // MARK: - Summary updates

    private func resetCaptureState(label: String?, interface: String?, clearPackets: Bool) {
        analysisWorkItem?.cancel()
        activeCaptureLabel = label
        activeInterfaceName = interface
        analyzerState = .idle
        seenAnomalyKeys.removeAll()
        streamingAnomalies = []
        captureStart = nil
        captureEnd = nil
        totalBytes = 0
        packetCounter = 0
        secondBuckets.removeAll()
        perSecondSeries.removeAll()
        perMinuteSeriesStorage.removeAll()
        minuteWindow.removeAll()
        minuteBytesSum = 0
        minutePacketsSum = 0
        minuteProtocolHistogram.removeAll()
        minuteTagTotals.removeAll()
        flowLastSeen.removeAll()
        perSecondMetrics = []
        perMinuteMetrics = []
        filteredPerSecondMetrics = []
        filteredPerMinuteMetrics = []
        filteredPackets = packets
        availableProtocols = []
        availableDestinations = []
        availablePorts = []
        topDestinations = []
        topPorts = []
        topProtocols = []
        if clearPackets {
            packets.removeAll()
            selectedPacketID = nil
        }
        timelineAnnotations = []
        correlationClusters = []
        activeClusterContext = nil
        timelineCursorTimestamp = nil
        selectedClusterID = nil
        selectedAnomalyID = nil
        timelineCursorProgress = 1.0
        updateSummary(interface: interface)
        applyFilters()
    }

    private func finalizeCaptureWindow() {
        captureEnd = captureEnd ?? captureStart
        updateSummary(interface: activeInterfaceName)
    }

    private func updateSummary(interface: String?) {
        let duration: TimeInterval
        if let start = captureStart, let end = captureEnd {
            duration = max(0, end.timeIntervalSince(start))
        } else {
            duration = 0
        }
        captureSummary = CaptureSummary(
            interfaceName: interface,
            packetCount: packetCounter,
            totalBytes: totalBytes,
            duration: duration,
            start: captureStart,
            end: captureEnd
        )
    }

    private func applyParsedCapture(_ result: ParsedCaptureResult, label: String) {
        resetCaptureState(label: label, interface: nil, clearPackets: true)
        packets = Array(result.packets.suffix(maxPacketBuffer))
        packetCounter = result.packets.last?.id ?? packetCounter
        captureStart = result.start
        captureEnd = result.end
        totalBytes = result.totalBytes
        updateSummary(interface: nil)

        for (timestamp, bucket) in result.secondBuckets.sorted(by: { $0.key < $1.key }) {
            emitMetric(for: timestamp, bucket: bucket)
        }
        captureState = .ready(label)
        analyzerResult = nil
        updateTagAvailability()
        applyFilters()
        scheduleStreamingAnalysis()
    }

    // MARK: - Fallback sampling

    private func startFallbackSampling(interfaceName: String?) {
        stopFallbackSampling()
        captureState = .capturing(interfaceName ?? "netstat")
        fallbackSnapshot = nil

        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue.global(qos: .utility))
        timer.schedule(deadline: .now(), repeating: .seconds(2))
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            if let snapshot = self.collectNetstatSnapshot(interface: interfaceName ?? self.selectedInterfaceName) {
                Task { @MainActor in
                    self.consumeNetstatSnapshot(snapshot)
                }
            }
        }
        fallbackTimer = timer
        timer.resume()
    }

    private func stopFallbackSampling() {
        fallbackTimer?.cancel()
        fallbackTimer = nil
        fallbackSnapshot = nil
    }

    private func collectNetstatSnapshot(interface: String?) -> NetstatSnapshot? {
        let netstatPath = "/usr/sbin/netstat"
        guard FileManager.default.isExecutableFile(atPath: netstatPath) else { return nil }
        do {
            let result = try shellRunner.run(executableURL: URL(fileURLWithPath: netstatPath), arguments: ["-ibn"])
            let lines = result.stdout.components(separatedBy: .newlines)
            let targetInterface = interface ?? "en0"
            for line in lines {
                let tokens = line.split(whereSeparator: { $0.isWhitespace })
                guard tokens.count >= 11 else { continue }
                if tokens[0] == Substring(targetInterface) {
                    let ipkts = Double(tokens[4]) ?? 0
                    let opkts = Double(tokens[6]) ?? 0
                    let ibytes = Double(tokens[10]) ?? 0
                    let obytes = Double(tokens.count > 11 ? tokens[11] : "0") ?? 0
                    return NetstatSnapshot(timestamp: Date(), packets: ipkts + opkts, bytes: ibytes + obytes)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    private func consumeNetstatSnapshot(_ snapshot: NetstatSnapshot) {
        defer { fallbackSnapshot = snapshot }
        if captureStart == nil { captureStart = snapshot.timestamp }
        captureEnd = snapshot.timestamp
        if let previous = fallbackSnapshot {
            let deltaTime = snapshot.timestamp.timeIntervalSince(previous.timestamp)
            guard deltaTime > 0 else { return }
            let deltaBytes = max(0, snapshot.bytes - previous.bytes)
            let deltaPackets = max(0, snapshot.packets - previous.packets)
            packetCounter += Int(deltaPackets.rounded())

            let synthetic = MetricPoint(
                timestamp: snapshot.timestamp,
                window: .perSecond,
                bytesPerSecond: deltaBytes / deltaTime,
                packetsPerSecond: deltaPackets / deltaTime,
                flowsPerSecond: 0,
                protocolHistogram: [:],
                tagMetrics: [:]
            )
            perSecondSeries.append(synthetic)
            if perSecondSeries.count > maxPerSecondPoints {
                perSecondSeries.removeFirst(perSecondSeries.count - maxPerSecondPoints)
            }
            perSecondMetrics = perSecondSeries

            updateMinuteSeries(with: synthetic, flows: [])
            scheduleStreamingAnalysis()
        }
        updateSummary(interface: activeInterfaceName)
    }

    // MARK: - Parsing helpers

    private struct TagAccumulator {
        var bytes: Int = 0
        var packets: Int = 0

        mutating func add(bytes: Int, packets: Int = 1) {
            self.bytes += bytes
            self.packets += packets
        }
    }

    private struct TagTotals {
        var bytes: Double = 0
        var packets: Double = 0

        mutating func add(bytes: Double, packets: Double) {
            self.bytes += bytes
            self.packets += packets
        }

        mutating func subtract(bytes: Double, packets: Double) {
            self.bytes -= bytes
            self.packets -= packets
        }
    }

    private struct SecondBucket {
        var bytes: Int = 0
        var packets: Int = 0
        var flows: Set<String> = []
        var protocols: [String: TagAccumulator] = [:]
        var destinations: [String: TagAccumulator] = [:]
        var destinationPorts: [String: TagAccumulator] = [:]
    }

    private struct ParsedPacket {
        let timestamp: Date
        let l4Protocol: String
        let source: String
        let sourceIP: String?
        let sourcePort: String?
        let destination: String
        let destinationIP: String?
        let destinationPort: String?
        let length: Int
        let info: String
    }

    private struct ParsedCaptureResult {
        let packets: [PacketSample]
        let secondBuckets: [Date: SecondBucket]
        let totalBytes: Int
        let start: Date?
        let end: Date?
    }

    private struct NetstatSnapshot {
        let timestamp: Date
        let packets: Double
        let bytes: Double
    }

    nonisolated private static func parsePacketLine(_ line: String) -> ParsedPacket? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if trimmed.hasPrefix("reading from") { return nil }

        guard let spaceIndex = trimmed.firstIndex(of: " ") else { return nil }
        let tsString = trimmed[..<spaceIndex]
        guard let epoch = Double(tsString) else { return nil }
        let timestamp = Date(timeIntervalSince1970: epoch)

        let restStart = trimmed.index(after: spaceIndex)
        guard restStart < trimmed.endIndex else { return nil }
        let rest = trimmed[restStart...]

        guard let protoEnd = rest.firstIndex(of: " ") else {
            return ParsedPacket(
                timestamp: timestamp,
                l4Protocol: rest.uppercased(),
                source: "",
                sourceIP: nil,
                sourcePort: nil,
                destination: "",
                destinationIP: nil,
                destinationPort: nil,
                length: 0,
                info: ""
            )
        }

        let proto = String(rest[..<protoEnd]).uppercased()
        let remainder = rest[rest.index(after: protoEnd)...].trimmingCharacters(in: .whitespaces)

        var info = ""
        var addressesPart = remainder[...]
        if let colon = remainder.firstIndex(of: ":") {
            info = remainder[remainder.index(after: colon)...].trimmingCharacters(in: .whitespaces)
            addressesPart = remainder[..<colon]
        } else if proto == "ARP" || proto == "ICMP" || proto == "ICMP6" {
            info = remainder.trimmingCharacters(in: .whitespaces)
        }

        let cleanedAddresses = addressesPart.trimmingCharacters(in: .whitespacesAndNewlines)
        var source = ""
        var destination = ""
        if let arrowRange = cleanedAddresses.range(of: ">") {
            source = cleanedAddresses[..<arrowRange.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
            destination = cleanedAddresses[arrowRange.upperBound...].trimmingCharacters(in: .whitespacesAndNewlines)
            if destination.hasSuffix(",") {
                destination.removeLast()
                destination = destination.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        } else {
            source = cleanedAddresses
        }

        if info.isEmpty {
            info = remainder.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let length = parsedLength(from: info)
        let splitSource = splitAddress(source)
        let splitDestination = splitAddress(destination)

        return ParsedPacket(
            timestamp: timestamp,
            l4Protocol: proto,
            source: source,
            sourceIP: splitSource.host,
            sourcePort: splitSource.port,
            destination: destination,
            destinationIP: splitDestination.host,
            destinationPort: splitDestination.port,
            length: length,
            info: info
        )
    }

    nonisolated private static func parsedLength(from info: String) -> Int {
        guard !info.isEmpty else { return 0 }
        let tokens = info.split(whereSeparator: { $0 == " " || $0 == "," })
        if let lengthIndex = tokens.firstIndex(where: { $0.lowercased() == "length" }),
           tokens.indices.contains(tokens.index(after: lengthIndex)) {
            let candidate = tokens[tokens.index(after: lengthIndex)]
            return Int(candidate) ?? 0
        }
        if let last = tokens.last, let value = Int(last) {
            return value
        }
        return 0
    }

    nonisolated private static func splitAddress(_ value: String) -> (host: String?, port: String?) {
        guard !value.isEmpty else { return (nil, nil) }
        if let lastDot = value.lastIndex(of: ".") {
            let portCandidate = value[value.index(after: lastDot)...]
            if !portCandidate.isEmpty, portCandidate.allSatisfy({ $0.isNumber }) {
                let host = value[..<lastDot]
                return (String(host), String(portCandidate))
            }
        }
        if let lastColon = value.lastIndex(of: ":") {
            let portCandidate = value[value.index(after: lastColon)...]
            if !portCandidate.isEmpty, portCandidate.allSatisfy({ $0.isNumber }) {
                let host = value[..<lastColon]
                return (String(host), String(portCandidate))
            }
        }
        return (value, nil)
    }

    nonisolated private static func parseOfflineCapture(at url: URL) throws -> ParsedCaptureResult {
        guard let tcpdump = locateTcpdump() else {
            throw PythonRunnerError.scriptNotFound("tcpdump")
        }

        let process = Process()
        process.executableURL = tcpdump
        process.arguments = ["-tt", "-n", "-q", "-r", url.path]

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        try process.run()
        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let err = String(data: errorData, encoding: .utf8) ?? "tcpdump error"
            throw PcapCaptureError.startFailed(err)
        }

        guard let text = String(data: outputData, encoding: .utf8) else {
            throw PcapCaptureError.unknown("Failed to decode tcpdump output.")
        }

        var packets: [PacketSample] = []
        var buckets: [Date: SecondBucket] = [:]
        var packetCounter = 0
        var firstTimestamp: Date?
        var lastTimestamp: Date?
        var totalBytes = 0

        text.enumerateLines { line, _ in
            guard let parsed = parsePacketLine(line) else { return }
            if firstTimestamp == nil { firstTimestamp = parsed.timestamp }
            packetCounter += 1
            let start = firstTimestamp ?? parsed.timestamp
            let sample = PacketSample(
                id: packetCounter,
                timestamp: parsed.timestamp,
                relativeTime: parsed.timestamp.timeIntervalSince(start),
                source: parsed.source,
                destination: parsed.destination,
                sourceIP: parsed.sourceIP,
                sourcePort: parsed.sourcePort,
                destinationIP: parsed.destinationIP,
                destinationPort: parsed.destinationPort,
                protocolName: parsed.l4Protocol,
                processName: nil,
                length: parsed.length,
                info: parsed.info
            )
            packets.append(sample)
            totalBytes += parsed.length
            lastTimestamp = parsed.timestamp

            let epoch = floor(parsed.timestamp.timeIntervalSince1970)
            let bucketDate = Date(timeIntervalSince1970: epoch)
            var bucket = buckets[bucketDate] ?? SecondBucket()
            bucket.bytes += parsed.length
            bucket.packets += 1
            if !parsed.source.isEmpty || !parsed.destination.isEmpty {
                let flow = "\(parsed.l4Protocol)|\(parsed.source)=>\(parsed.destination)"
                bucket.flows.insert(flow)
            }
            if !parsed.l4Protocol.isEmpty {
                var accumulator = bucket.protocols[parsed.l4Protocol] ?? TagAccumulator()
                accumulator.add(bytes: parsed.length)
                bucket.protocols[parsed.l4Protocol] = accumulator
            }
            let destinationKey: String = {
                if let ip = parsed.destinationIP, !ip.isEmpty { return ip }
                return parsed.destination
            }()
            if !destinationKey.isEmpty {
                var accumulator = bucket.destinations[destinationKey] ?? TagAccumulator()
                accumulator.add(bytes: parsed.length)
                bucket.destinations[destinationKey] = accumulator
            }
            if let port = parsed.destinationPort, !port.isEmpty {
                var accumulator = bucket.destinationPorts[port] ?? TagAccumulator()
                accumulator.add(bytes: parsed.length)
                bucket.destinationPorts[port] = accumulator
            }
            buckets[bucketDate] = bucket
        }

        return ParsedCaptureResult(
            packets: packets,
            secondBuckets: buckets,
            totalBytes: totalBytes,
            start: firstTimestamp,
            end: lastTimestamp
        )
    }

    nonisolated private static func locateTcpdump() -> URL? {
        let candidates = [
            "/usr/sbin/tcpdump",
            "/usr/bin/tcpdump",
            "/opt/homebrew/sbin/tcpdump",
            "/opt/homebrew/bin/tcpdump",
            "/usr/local/sbin/tcpdump",
            "/usr/local/bin/tcpdump"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
    typealias TagRank = AnalyzerTagRank
