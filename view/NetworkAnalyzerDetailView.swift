import SwiftUI
#if canImport(Charts)
import Charts
#endif

struct NetworkAnalyzerDetailView: View {
    @ObservedObject var viewModel: NetworkAnalyzerViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                captureSummarySection
                timelineSection
                analyzerSection
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func correlationPanel(clusters: [CorrelationCluster]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Correlation View")
                    .font(.headline)
                Spacer()
                Toggle("Debug overlay", isOn: $viewModel.isDebugOverlayEnabled)
                    .toggleStyle(.switch)
                    .font(.caption)
                    .help("Show raw narrative metadata for QA.")
            }
            if clusters.isEmpty {
                Text("No correlated spikes in the current window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(clusters) { cluster in
                        let isSelected = viewModel.selectedClusterID == cluster.id
                        Button {
                            viewModel.selectCluster(cluster)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(cluster.displayTag)
                                        .font(.subheadline.weight(.semibold))
                                    Spacer()
                                    Text(String(format: "%.1fσ", cluster.peakZScore))
                                        .font(.caption.monospacedDigit())
                                        .padding(4)
                                        .background(RoundedRectangle(cornerRadius: 4).fill(Color.primary.opacity(0.08)))
                                }
                                Text(cluster.narrative)
                                    .font(.caption)
                                    .foregroundStyle(.primary)
                                HStack(spacing: 12) {
                                    Text("Anomalies: \(cluster.totalAnomalies)")
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                    if let bytes = cluster.totalBytes {
                                        Text("Burst: \(NetworkAnalyzerView.byteFormatter(Int(bytes)))")
                                            .font(.caption2)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                if viewModel.isDebugOverlayEnabled {
                                    Text("Window \(NetworkAnalyzerView.timeFormatter.string(from: cluster.window.lowerBound)) → \(NetworkAnalyzerView.timeFormatter.string(from: cluster.window.upperBound)) • Confidence \(String(format: "%.2f", cluster.confidence))")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var timelineChart: some View {
        #if canImport(Charts)
        if #available(macOS 13.0, *) {
            let perSecondMetrics = decimatedMetrics(sortedMetrics(viewModel.filteredPerSecondMetrics), maxPoints: 600)
            let perMinuteMetrics = sortedMetrics(viewModel.filteredPerMinuteMetrics)
            let annotations = viewModel.timelineAnnotations.sorted { $0.timestamp < $1.timestamp }
            let maxValue = max(
                perSecondMetrics.map(\.bytesPerSecond).max() ?? 0,
                perMinuteMetrics.map(\.bytesPerSecond).max() ?? 0
            )
            let yUpperBound = max(maxValue, 1)

            Chart {
                ForEach(perSecondMetrics) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Bytes/sec", point.bytesPerSecond)
                    )
                    .foregroundStyle(Color.blue.opacity(0.7))
                    .interpolationMethod(.monotone)
                }
                ForEach(perMinuteMetrics) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Bytes/sec (avg)", point.bytesPerSecond)
                    )
                    .foregroundStyle(Color.gray.opacity(0.6))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [5, 7]))
                    .interpolationMethod(.monotone)
                }
                ForEach(annotations) { annotation in
                    RuleMark(x: .value("Annotation", annotation.timestamp))
                        .foregroundStyle(severityColor(annotation.severity).opacity(0.55))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [3, 3]))
                    if yUpperBound > 0 {
                        PointMark(
                            x: .value("Annotation", annotation.timestamp),
                            y: .value("Bytes/sec", yUpperBound)
                        )
                        .symbolSize(50)
                        .foregroundStyle(severityColor(annotation.severity))
                    }
                }
            }
            .frame(minHeight: 220)
            .chartYScale(domain: 0...yUpperBound)
        } else {
            chartUnavailable
        }
        #else
        chartUnavailable
        #endif
    }

    @ViewBuilder
    private var timelineAnnotationsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Timeline Events")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(viewModel.timelineAnnotations.sorted { $0.timestamp < $1.timestamp }) { annotation in
                    annotationCallout(for: annotation)
                }
            }
        }
    }

    @ViewBuilder
    private func annotationCallout(for annotation: TimelineAnnotation) -> some View {
        let severity = severityColor(annotation.severity)
        let isSelected = annotation.clusterID != nil && viewModel.selectedClusterID == annotation.clusterID
        let backgroundOpacity: Double = 0.12
        let strokeOpacity: Double = 0.3

        let content = VStack(alignment: .leading, spacing: 4) {
            Text(annotation.title)
                .font(.caption.weight(.semibold))
            if let subtitle = annotation.subtitle {
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(nil)
            }
            Text(NetworkAnalyzerView.timeFormatter.string(from: annotation.timestamp))
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(severity.opacity(backgroundOpacity))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isSelected ? Color.accentColor : severity.opacity(strokeOpacity), lineWidth: 1)
        )

        if let clusterID = annotation.clusterID,
           let cluster = viewModel.correlationClusters.first(where: { $0.id == clusterID }) {
            Button {
                viewModel.selectCluster(cluster)
            } label: {
                content
            }
            .buttonStyle(.plain)
        } else {
            content
        }
    }

    private func sortedMetrics(_ metrics: [MetricPoint]) -> [MetricPoint] {
        metrics.sorted { $0.timestamp < $1.timestamp }
    }

    private func sortedBaseline(_ metrics: [BaselinePoint]) -> [BaselinePoint] {
        metrics.sorted { $0.timestamp < $1.timestamp }
    }

    private func decimatedMetrics(_ metrics: [MetricPoint], maxPoints: Int) -> [MetricPoint] {
        guard metrics.count > maxPoints, maxPoints > 0 else { return metrics }
        var sampled: [MetricPoint] = []
        let step = Double(metrics.count - 1) / Double(maxPoints - 1)
        var nextIndex: Double = 0
        var current = 0
        for point in metrics {
            if Double(current) >= nextIndex {
                sampled.append(point)
                nextIndex += step
            }
            current += 1
        }
        if sampled.last != metrics.last {
            sampled.append(metrics.last!)
        }
        return sampled
    }

    private func severityColor(_ severity: TimelineAnnotation.Severity) -> Color {
        switch severity {
        case .info:
            return Color.blue
        case .notice:
            return Color.green
        case .warning:
            return Color.orange
        case .critical:
            return Color.red
        }
    }

    private func clusterNarrativeCard(_ cluster: CorrelationCluster) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(cluster.displayTag)
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(String(format: "%.1fσ", cluster.peakZScore))
                    .font(.caption.monospacedDigit())
                    .padding(4)
                    .background(RoundedRectangle(cornerRadius: 4).fill(Color.accentColor.opacity(0.1)))
            }
            Text(cluster.narrative)
                .font(.caption)
            HStack(spacing: 12) {
                Text("Anomalies: \(cluster.totalAnomalies)")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                if let bytes = cluster.totalBytes {
                    Text("Burst: \(NetworkAnalyzerView.byteFormatter(Int(bytes)))")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if viewModel.isDebugOverlayEnabled {
                Text("Window: \(NetworkAnalyzerView.timeFormatter.string(from: cluster.window.lowerBound)) → \(NetworkAnalyzerView.timeFormatter.string(from: cluster.window.upperBound))")
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.gray.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.accentColor.opacity(0.4), lineWidth: 1)
        )
    }

    private var captureSummarySection: some View {
        let summary = viewModel.captureSummary
        return VStack(alignment: .leading, spacing: 10) {
            Text("Capture Summary")
                .font(.title3.bold())
            Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
                summaryRow(label: "Interface", value: summary.interfaceName ?? "Offline")
                summaryRow(label: "Packets", value: "\(summary.packetCount)")
                summaryRow(label: "Bytes", value: NetworkAnalyzerView.byteFormatter(summary.totalBytes))
                summaryRow(label: "Duration", value: NetworkAnalyzerView.durationFormatter(summary.duration))
                if let start = summary.start {
                    summaryRow(label: "Started", value: NetworkAnalyzerView.timeFormatter.string(from: start))
                }
                if let end = summary.end {
                    summaryRow(label: "Last packet", value: NetworkAnalyzerView.timeFormatter.string(from: end))
                }
            }
            .font(.caption)
        }
    }

    @ViewBuilder
    private var timelineSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Traffic Timeline")
                .font(.headline)
            timelineChart
            if let active = viewModel.activeClusterContext {
                clusterNarrativeCard(active)
            }
            if !viewModel.timelineAnnotations.isEmpty {
                timelineAnnotationsList
            }
        }
        tagBreakdownSection(title: "Top Destinations", entries: viewModel.topDestinations)
        tagBreakdownSection(title: "Top Ports", entries: viewModel.topPorts)
        tagBreakdownSection(title: "Top Protocols", entries: viewModel.topProtocols)
    }

    @ViewBuilder
    private var analyzerSection: some View {
        if let result = viewModel.analyzerResult {
            VStack(alignment: .leading, spacing: 18) {
                Text("Anomaly Detection")
                    .font(.headline)
                detectorControlsPanel
                alertControlsPanel
                analyzerVisualization(for: result)
                if let advanced = result.advancedDetection {
                    if let multivariateScores = advanced.multivariate?.scores, !multivariateScores.isEmpty {
                        multivariatePanel(scores: multivariateScores, diagnostics: advanced.multivariate?.diagnostics)
                    } else if let fallbackScores = result.multivariateScores, !fallbackScores.isEmpty {
                        multivariatePanel(scores: fallbackScores, diagnostics: result.multivariateDiagnostics)
                    }
                    if let changePoints = advanced.changePoints ?? result.changePoints, !changePoints.isEmpty {
                        changePointPanel(changePoints: changePoints, diagnostics: advanced.changePointDiagnostics)
                    }
                    if let newTalkers = advanced.newTalkers?.entries, !newTalkers.isEmpty {
                        newTalkerPanel(entries: newTalkers, diagnostics: advanced.newTalkers?.diagnostics)
                    } else if let fallbackTalkers = result.newTalkers, !fallbackTalkers.isEmpty {
                        newTalkerPanel(entries: fallbackTalkers, diagnostics: result.newTalkerDiagnostics)
                    }
                    if let alerts = advanced.alerts?.events, !alerts.isEmpty {
                        alertPanel(events: alerts)
                    } else if let fallbackAlerts = result.alerts?.events, !fallbackAlerts.isEmpty {
                        alertPanel(events: fallbackAlerts)
                    }
                } else {
                    if let multivariateScores = result.multivariateScores, !multivariateScores.isEmpty {
                        multivariatePanel(scores: multivariateScores, diagnostics: result.multivariateDiagnostics)
                    }
                    if let changePoints = result.changePoints, !changePoints.isEmpty {
                        changePointPanel(changePoints: changePoints, diagnostics: nil)
                    }
                    if let newTalkers = result.newTalkers, !newTalkers.isEmpty {
                        newTalkerPanel(entries: newTalkers, diagnostics: result.newTalkerDiagnostics)
                    }
                    if let alerts = result.alerts?.events, !alerts.isEmpty {
                        alertPanel(events: alerts)
                    }
                }
                if let payload = result.payloadSummary, !payload.isEmpty {
                    payloadSummary(payload)
                }
                correlationPanel(clusters: viewModel.correlationClusters)
                anomaliesList(viewModel.streamingAnomalies.isEmpty ? result.anomalies : viewModel.streamingAnomalies)
            }
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("Run Analyzer")
                    .font(.headline)
                Text("Execute the analyzer to overlay rolling baselines and anomaly markers on the capture.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private func analyzerVisualization(for result: AnalyzerResult) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 20) {
                analyzerChart(result: result)
                    .frame(maxWidth: .infinity)
                analyzerSummary(result.summary)
                    .frame(minWidth: 180, alignment: .leading)
            }
            VStack(alignment: .leading, spacing: 12) {
                analyzerChart(result: result)
                analyzerSummary(result.summary)
            }
        }
    }

    private func analyzerSummary(_ summary: AnalyzerSummary) -> some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 6) {
            summaryRow(label: "Total Packets", value: "\(summary.totalPackets)")
            summaryRow(label: "Total Bytes", value: NetworkAnalyzerView.byteFormatter(Int(summary.totalBytes)))
            summaryRow(label: "Mean Throughput", value: String(format: "%.1f B/s", summary.meanBytesPerSecond))
            summaryRow(label: "Mean Packets/s", value: String(format: "%.2f", summary.meanPacketsPerSecond))
            summaryRow(label: "Mean Flows/s", value: String(format: "%.2f", summary.meanFlowsPerSecond))
            summaryRow(label: "Window", value: "\(summary.windowSeconds) s")
            summaryRow(label: "Z Threshold", value: String(format: "%.1f", summary.zThreshold))
        }
        .font(.caption)
    }

    private func payloadSummary(_ payload: [String: Double]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Payload Summary")
                .font(.subheadline.weight(.semibold))
            ForEach(payload.sorted(by: { $0.key < $1.key }), id: \.key) { entry in
                HStack {
                    Text(entry.key)
                        .font(.caption)
                    Spacer()
                    Text(String(format: "%.2f", entry.value))
                        .font(.caption.monospacedDigit())
                }
            }
        }
    }

    private func changePointPanel(changePoints: [ChangePointEvent], diagnostics: ChangePointDiagnostics?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Change Points")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(changePoints.prefix(5)) { point in
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text(NetworkAnalyzerView.timeFormatter.string(from: point.timestamp))
                            .font(.caption.weight(.semibold))
                        Text(changePointLabel(point))
                            .font(.caption)
                        Spacer()
                        Text(String(format: "%+.1f", point.meanDelta))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(point.direction == "increase" ? Color.green : Color.purple)
                    }
                }
                if changePoints.count > 5 {
                    Text("+\(changePoints.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let diagnostics {
                HStack(spacing: 12) {
                    if let window = diagnostics.windowSeconds {
                        Text(String(format: "Window %.0fs", window))
                            .font(.caption2)
                    }
                    if let threshold = diagnostics.thresholdStdDevs {
                        Text(String(format: "Threshold %.1fσ", threshold))
                            .font(.caption2)
                    }
                    if let detected = diagnostics.detected {
                        Text("Detected: \(detected)")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }

private func changePointLabel(_ point: ChangePointEvent) -> String {
    let directionArrow = point.direction == "increase" ? "↑" : "↓"
    return "\(point.metric) \(directionArrow)"
}

    private func multivariatePanel(scores: [MultivariateScore], diagnostics: MultivariateDiagnostics?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Multivariate Outliers")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(scores.prefix(5)) { score in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Text(NetworkAnalyzerView.timeFormatter.string(from: score.timestamp))
                                .font(.caption.weight(.semibold))
                            Text(String(format: "%.1fσ", score.score))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(Color.pink)
                        }
                        if !score.contributions.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(score.contributions.prefix(3)) { contribution in
                                    Text(multivariateContributionLabel(contribution))
                                        .font(.caption2)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill((contribution.direction == "increase" ? Color.green : Color.purple).opacity(0.15))
                                        )
                                }
                            }
                        }
                    }
                }
                if scores.count > 5 {
                    Text("+\(scores.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let diagnostics {
                HStack(spacing: 12) {
                    if let windowSteps = diagnostics.windowSteps {
                        Text("Window: \(windowSteps) samples")
                            .font(.caption2)
                    }
                    if let evaluated = diagnostics.evaluatedPoints {
                        Text("Evaluated: \(evaluated)")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func multivariateContributionLabel(_ contribution: FeatureContribution) -> String {
        let arrow = contribution.direction == "increase" ? "↑" : "↓"
        return "\(contribution.feature) \(arrow) \(String(format: "%.0f%%", contribution.weight * 100))"
    }

    private var detectorControlsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Detector Controls")
                .font(.subheadline.weight(.semibold))
            HStack(spacing: 16) {
                Toggle("Legacy", isOn: $viewModel.detectorLegacyEnabled)
                Toggle("Seasonality", isOn: $viewModel.detectorSeasonalityEnabled)
                Toggle("Change-Point", isOn: $viewModel.detectorChangePointEnabled)
            }
            .toggleStyle(.switch)
            HStack(spacing: 16) {
                Toggle("Multivariate", isOn: $viewModel.detectorMultivariateEnabled)
                Toggle("New Talker", isOn: $viewModel.detectorNewTalkerEnabled)
            }
            .toggleStyle(.switch)
        }
    }

    private var alertControlsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alerting")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(String(format: "Threshold %.2f", viewModel.alertScoreThreshold))
                        .font(.caption)
                    Slider(value: $viewModel.alertScoreThreshold, in: 0.5...1.0, step: 0.05)
                        .frame(maxWidth: 180)
                }
                HStack(spacing: 16) {
                    Toggle("Notifications", isOn: $viewModel.alertNotificationsEnabled)
                    Toggle("Webhook", isOn: $viewModel.alertWebhookEnabled)
                }
                .toggleStyle(.switch)
                if viewModel.alertWebhookEnabled {
                    TextField("Webhook URL", text: $viewModel.alertWebhookURL)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                        .frame(maxWidth: 320)
                }
            }
        }
    }

    private func newTalkerPanel(entries: [NewTalker], diagnostics: NewTalkerDiagnostics?) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("New Talkers")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(entries.prefix(5)) { entry in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Text("\(entry.tagType): \(entry.tagValue)")
                                .font(.caption.weight(.semibold))
                            Text(NetworkAnalyzerView.timeFormatter.string(from: entry.firstSeen))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        HStack(spacing: 12) {
                            Text("Bytes \(NetworkAnalyzerView.byteFormatter(Int(entry.totalBytes)))")
                                .font(.caption2)
                            Text("Samples \(entry.samples)")
                                .font(.caption2)
                            if let delta = entry.entropyDelta {
                                Text(String(format: "ΔH %.2f", delta))
                                    .font(.caption2)
                            }
                        }
                        .foregroundStyle(.secondary)
                    }
                }
                if entries.count > 5 {
                    Text("+\(entries.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            if let diagnostics {
                HStack(spacing: 12) {
                    if let detected = diagnostics.detected {
                        Text("Detected: \(detected)")
                            .font(.caption2)
                    }
                    if let evaluated = diagnostics.uniqueTagsEvaluated {
                        Text("Tags seen: \(evaluated)")
                            .font(.caption2)
                    }
                }
                .foregroundStyle(.secondary)
            }
        }
    }

    private func alertPanel(events: [AlertEvent]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Alerts")
                .font(.subheadline.weight(.semibold))
            VStack(alignment: .leading, spacing: 6) {
                ForEach(events.prefix(5)) { event in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 12) {
                            Text(NetworkAnalyzerView.timeFormatter.string(from: event.timestamp))
                                .font(.caption.weight(.semibold))
                            Text(event.detector.uppercased())
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Text(event.message)
                            .font(.caption)
                        HStack(spacing: 12) {
                            Text(String(format: "Score %.2f", event.score))
                                .font(.caption2)
                                .foregroundStyle(event.severity == "critical" ? Color.red : Color.orange)
                            if let destinations = event.destinations, !destinations.isEmpty {
                                Text(destinations.joined(separator: ", "))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(event.severity == "critical" ? Color.red.opacity(0.08) : Color.orange.opacity(0.08))
                    )
                }
                if events.count > 5 {
                    Text("+\(events.count - 5) more")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private func analyzerChart(result: AnalyzerResult) -> some View {
        #if canImport(Charts)
        if #available(macOS 13.0, *) {
            let perSecondMetrics = decimatedMetrics(sortedMetrics(result.metrics.filter { $0.window == .perSecond }), maxPoints: 600)
            let baselineMetrics = sortedBaseline(result.baseline.filter { $0.window == .perSecond })
            let anomalies = (viewModel.streamingAnomalies.isEmpty ? result.anomalies : viewModel.streamingAnomalies)
                .sorted { $0.timestamp < $1.timestamp }
            let maxValue = max(
                perSecondMetrics.map(\.bytesPerSecond).max() ?? 0,
                baselineMetrics.map(\.bytesPerSecond).max() ?? 0,
                anomalies.map(\.value).max() ?? 0
            )
            let yUpperBound = max(maxValue, 1)
            let seasonalityBand = result.advancedDetection?
                .seasonality?
                .metrics["bytesPerSecond"]?
                .band ?? []

            let changePoints = result.advancedDetection?.changePoints ?? result.changePoints ?? []
            let multivariateScores = result.advancedDetection?.multivariate?.scores ?? result.multivariateScores ?? []

            Chart {
                if !seasonalityBand.isEmpty {
                    ForEach(seasonalityBand) { band in
                        AreaMark(
                            x: .value("Time", band.timestamp),
                            yStart: .value("Seasonality Lower", max(0, band.lower)),
                            yEnd: .value("Seasonality Upper", band.upper)
                        )
                        .foregroundStyle(Color.cyan.opacity(0.18))
                        .interpolationMethod(.monotone)
                    }
                }
                ForEach(perSecondMetrics) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Observed", point.bytesPerSecond)
                    )
                    .foregroundStyle(Color.blue)
                    .interpolationMethod(.monotone)
                }
                ForEach(baselineMetrics) { point in
                    LineMark(
                        x: .value("Time", point.timestamp),
                        y: .value("Baseline", point.bytesPerSecond)
                    )
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 4]))
                    .foregroundStyle(.secondary)
                }
                ForEach(anomalies) { anomaly in
                    PointMark(
                        x: .value("Time", anomaly.timestamp),
                        y: .value("Value", anomaly.value)
                    )
                    .foregroundStyle(anomaly.direction == .spike ? Color.red : Color.orange)
                    .symbolSize(36)
                }
                if yUpperBound > 0 {
                    ForEach(anomalies) { anomaly in
                        PointMark(
                            x: .value("Time", anomaly.timestamp),
                            y: .value("Value", yUpperBound)
                        )
                        .symbolSize(36)
                        .foregroundStyle(anomaly.direction == .spike ? Color.red.opacity(0.5) : Color.orange.opacity(0.5))
                    }
                }
                if !changePoints.isEmpty {
                    ForEach(changePoints) { changePoint in
                        RuleMark(x: .value("Time", changePoint.timestamp))
                            .lineStyle(StrokeStyle(lineWidth: 1, dash: [2, 3]))
                            .foregroundStyle(changePoint.direction == "increase" ? Color.green : Color.purple)
                            .annotation(position: .top, alignment: .leading) {
                                Text(changePointLabel(changePoint))
                                    .font(.caption2)
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 2)
                                    .background(
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(Color.black.opacity(0.5))
                                    )
                                    .foregroundStyle(Color.white)
                            }
                    }
                }
                if !multivariateScores.isEmpty {
                    ForEach(multivariateScores) { score in
                        PointMark(
                            x: .value("Time", score.timestamp),
                            y: .value("Value", yUpperBound * 0.95)
                        )
                        .symbolSize(24)
                        .foregroundStyle(Color.pink)
                        .annotation(position: .topTrailing) {
                            Text(String(format: "%.1fσ", score.score))
                                .font(.caption2)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(Color.pink.opacity(0.2))
                                )
                        }
                    }
                }
            }
            .chartYScale(domain: 0...yUpperBound)
            .frame(minHeight: 220)
        } else {
            chartUnavailable
        }
        #else
        chartUnavailable
        #endif
    }

    private func anomaliesList(_ anomalies: [Anomaly]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Anomalies (\(anomalies.count))")
                .font(.headline)
            if anomalies.isEmpty {
                Text("No anomalies detected above the configured threshold.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) {
                    ForEach(anomalies) { anomaly in
                        let isSelected = viewModel.selectedAnomalyID == anomaly.id
                        Button {
                            viewModel.selectAnomaly(anomaly)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(NetworkAnalyzerView.timeFormatter.string(from: anomaly.timestamp))
                                    .font(.caption.weight(.semibold))
                                Text("\(anomaly.metric) = \(String(format: "%.1f", anomaly.value)) (baseline \(String(format: "%.1f", anomaly.baseline)))")
                                    .font(.caption2)
                                Text("z-score \(String(format: "%.2f", anomaly.zScore)) • \(anomaly.direction == .spike ? "Spike" : "Drop")")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                if let tagType = anomaly.tagType, let tagValue = anomaly.tagValue {
                                    Text("Tag: \(tagType) = \(tagValue)")
                                        .font(.caption2)
                                }
                                if let cluster = viewModel.correlationClusters.first(where: { $0.anomalyIDs.contains(anomaly.id) }) {
                                    Text("Cluster: \(cluster.displayTag)")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(Color.accentColor)
                                }
                                if let context = anomaly.context, !context.isEmpty {
                                    Text(context.map { "\($0.key): \($0.value)" }.joined(separator: ", "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                                if viewModel.isDebugOverlayEnabled {
                                    Text(anomaly.id.uuidString)
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(RoundedRectangle(cornerRadius: 8, style: .continuous).fill(isSelected ? Color.accentColor.opacity(0.15) : Color.gray.opacity(0.08)))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func tagBreakdownSection(title: String, entries: [AnalyzerTagRank]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.headline)
            if entries.isEmpty {
                Text("No data available for this window.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(entries) { entry in
                        HStack {
                            Text(entry.value)
                                .font(.caption.weight(.semibold))
                            Spacer()
                            Text(NetworkAnalyzerView.byteFormatter(Int(entry.bytes)))
                                .font(.caption.monospacedDigit())
                            Text(String(format: "%.0f pkts", entry.packets))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private func summaryRow(label: String, value: String) -> some View {
        GridRow {
            Text(label)
                .font(.caption.weight(.semibold))
            Text(value)
                .font(.caption.monospaced())
        }
    }

    private var chartUnavailable: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Charts Unavailable")
                .font(.caption.weight(.semibold))
            Text("Install macOS 13 or newer to view inline charts.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
