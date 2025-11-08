//
//  NetworkAnalyzerModels.swift
//  Aman - view 
//
//  Created by Aman Team on 08/11/25
//

import Foundation

struct PacketSample: Codable, Identifiable, Hashable {
    let id: Int
    let timestamp: Date
    let relativeTime: TimeInterval
    let source: String
    let destination: String
    let sourceIP: String?
    let sourcePort: String?
    let destinationIP: String?
    let destinationPort: String?
    let protocolName: String
    let processName: String?
    let length: Int
    let info: String

    init(
        id: Int,
        timestamp: Date,
        relativeTime: TimeInterval,
        source: String,
        destination: String,
        sourceIP: String?,
        sourcePort: String?,
        destinationIP: String?,
        destinationPort: String?,
        protocolName: String,
        processName: String?,
        length: Int,
        info: String
    ) {
        self.id = id
        self.timestamp = timestamp
        self.relativeTime = relativeTime
        self.source = source
        self.destination = destination
        self.sourceIP = sourceIP
        self.sourcePort = sourcePort
        self.destinationIP = destinationIP
        self.destinationPort = destinationPort
        self.protocolName = protocolName
        self.processName = processName
        self.length = length
        self.info = info
    }
}

struct TagMetric: Codable, Hashable {
    let bytes: Double
    let packets: Double
}

struct MetricPoint: Codable, Identifiable, Hashable {
    enum Window: String, Codable, Hashable { case perSecond, perMinute }

    let timestamp: Date
    let window: Window
    let bytesPerSecond: Double
    let packetsPerSecond: Double
    let flowsPerSecond: Double
    let protocolHistogram: [String: Int]
    let tagMetrics: [String: [String: TagMetric]]

    var id: Date { timestamp }
}

struct BaselinePoint: Codable, Identifiable, Hashable {
    let timestamp: Date
    let window: MetricPoint.Window
    let bytesPerSecond: Double
    let packetsPerSecond: Double
    let flowsPerSecond: Double
    let tagMetrics: [String: [String: TagMetric]]
    var id: Date { timestamp }
}

struct Anomaly: Codable, Identifiable, Hashable {
    enum Direction: String, Codable { case spike, drop }
    let id: UUID
    let timestamp: Date
    let metric: String
    let value: Double
    let baseline: Double
    let zScore: Double
    let direction: Direction
    let tagType: String?
    let tagValue: String?
    let context: [String: String]?
}

struct AnalyzerSummary: Codable, Hashable {
    let totalPackets: Int
    let totalBytes: Double
    let meanBytesPerSecond: Double
    let meanPacketsPerSecond: Double
    let meanFlowsPerSecond: Double
    let windowSeconds: Int
    let zThreshold: Double
}

struct AnalyzerResult: Codable, Hashable {
    let metrics: [MetricPoint]
    let baseline: [BaselinePoint]
    let anomalies: [Anomaly]
    let summary: AnalyzerSummary
    let clusters: [CorrelationCluster]?
    let payloadSummary: [String: Double]?
    let advancedDetection: AdvancedDetectionResult?
    let changePoints: [ChangePointEvent]?
    let multivariateScores: [MultivariateScore]?
    let multivariateDiagnostics: MultivariateDiagnostics?
    let newTalkers: [NewTalker]?
    let newTalkerDiagnostics: NewTalkerDiagnostics?
    let alerts: AdvancedAlertPayload?

    private enum CodingKeys: String, CodingKey {
        case metrics
        case baseline
        case anomalies
        case summary
        case clusters
        case payloadSummary
        case advancedDetection
        case changePoints
        case multivariateScores
        case multivariateDiagnostics
        case newTalkers
        case newTalkerDiagnostics
        case alerts
    }

    init(
        metrics: [MetricPoint],
        baseline: [BaselinePoint],
        anomalies: [Anomaly],
        summary: AnalyzerSummary,
        clusters: [CorrelationCluster]?,
        payloadSummary: [String: Double]?,
        advancedDetection: AdvancedDetectionResult?,
        changePoints: [ChangePointEvent]?,
        multivariateScores: [MultivariateScore]?,
        multivariateDiagnostics: MultivariateDiagnostics?,
        newTalkers: [NewTalker]?,
        newTalkerDiagnostics: NewTalkerDiagnostics?,
        alerts: AdvancedAlertPayload?
    ) {
        self.metrics = metrics
        self.baseline = baseline
        self.anomalies = anomalies
        self.summary = summary
        self.clusters = clusters
        self.payloadSummary = payloadSummary
        self.advancedDetection = advancedDetection
        self.changePoints = changePoints
        self.multivariateScores = multivariateScores
        self.multivariateDiagnostics = multivariateDiagnostics
        self.newTalkers = newTalkers
        self.newTalkerDiagnostics = newTalkerDiagnostics
        self.alerts = alerts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        metrics = try container.decodeIfPresent([MetricPoint].self, forKey: .metrics) ?? []
        baseline = try container.decodeIfPresent([BaselinePoint].self, forKey: .baseline) ?? []
        anomalies = try container.decodeIfPresent([Anomaly].self, forKey: .anomalies) ?? []
        summary = try container.decode(AnalyzerSummary.self, forKey: .summary)
        clusters = try container.decodeIfPresent([CorrelationCluster].self, forKey: .clusters)
        payloadSummary = try container.decodeIfPresent([String: Double].self, forKey: .payloadSummary)
        advancedDetection = try container.decodeIfPresent(AdvancedDetectionResult.self, forKey: .advancedDetection)
        changePoints = try container.decodeIfPresent([ChangePointEvent].self, forKey: .changePoints)
        multivariateScores = try container.decodeIfPresent([MultivariateScore].self, forKey: .multivariateScores)
        multivariateDiagnostics = try container.decodeIfPresent(MultivariateDiagnostics.self, forKey: .multivariateDiagnostics)
        newTalkers = try container.decodeIfPresent([NewTalker].self, forKey: .newTalkers)
        newTalkerDiagnostics = try container.decodeIfPresent(NewTalkerDiagnostics.self, forKey: .newTalkerDiagnostics)
        alerts = try container.decodeIfPresent(AdvancedAlertPayload.self, forKey: .alerts)
    }
}

struct AnalyzerPayloadConfig: Codable, Hashable {
    let captureMode: String
    let payloadInspectionEnabled: Bool
}

struct TimelineAnnotation: Identifiable, Hashable, Codable {
    enum Severity: String, Codable {
        case info
        case notice
        case warning
        case critical

        init(zScore: Double) {
            let magnitude = abs(zScore)
            switch magnitude {
            case ..<2.0:
                self = .info
            case 2.0..<3.0:
                self = .notice
            case 3.0..<4.0:
                self = .warning
            default:
                self = .critical
            }
        }
    }

    let id: UUID
    let timestamp: Date
    let window: ClosedRange<Date>
    let title: String
    let subtitle: String?
    let severity: Severity
    let tagType: String?
    let tagValue: String?
    let clusterID: UUID?
    let anomalyIDs: [UUID]
}

struct CorrelationCluster: Identifiable, Hashable, Codable {
    let id: UUID
    let tagType: String?
    let tagValue: String?
    let metric: String
    let window: ClosedRange<Date>
    let peakTimestamp: Date
    let peakValue: Double
    let peakZScore: Double
    let totalAnomalies: Int
    let totalBytes: Double?
    let confidence: Double
    let narrative: String
    let anomalyIDs: [UUID]

    var displayTag: String {
        if let type = tagType, let value = tagValue {
            return "\(type): \(value)"
        } else {
            return metric
        }
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case tagType
        case tagValue
        case metric
        case window
        case peakTimestamp
        case peakValue
        case peakZScore
        case totalAnomalies
        case totalBytes
        case confidence
        case narrative
        case anomalyIDs
    }

    private enum WindowKeys: String, CodingKey {
        case lowerBound
        case upperBound
    }

    init(
        id: UUID,
        tagType: String?,
        tagValue: String?,
        metric: String,
        window: ClosedRange<Date>,
        peakTimestamp: Date,
        peakValue: Double,
        peakZScore: Double,
        totalAnomalies: Int,
        totalBytes: Double?,
        confidence: Double,
        narrative: String,
        anomalyIDs: [UUID]
    ) {
        self.id = id
        self.tagType = tagType
        self.tagValue = tagValue
        self.metric = metric
        self.window = window
        self.peakTimestamp = peakTimestamp
        self.peakValue = peakValue
        self.peakZScore = peakZScore
        self.totalAnomalies = totalAnomalies
        self.totalBytes = totalBytes
        self.confidence = confidence
        self.narrative = narrative
        self.anomalyIDs = anomalyIDs
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        tagType = try container.decodeIfPresent(String.self, forKey: .tagType)
        tagValue = try container.decodeIfPresent(String.self, forKey: .tagValue)
        metric = try container.decode(String.self, forKey: .metric)
        peakTimestamp = try container.decode(Date.self, forKey: .peakTimestamp)
        peakValue = try container.decode(Double.self, forKey: .peakValue)
        peakZScore = try container.decode(Double.self, forKey: .peakZScore)
        totalAnomalies = try container.decode(Int.self, forKey: .totalAnomalies)
        totalBytes = try container.decodeIfPresent(Double.self, forKey: .totalBytes)
        confidence = try container.decode(Double.self, forKey: .confidence)
        narrative = try container.decode(String.self, forKey: .narrative)
        anomalyIDs = try container.decode([UUID].self, forKey: .anomalyIDs)

        if let rangeArray = try? container.decode([Date].self, forKey: .window), rangeArray.count == 2 {
            window = rangeArray[0] ... rangeArray[1]
        } else {
            let nested = try container.nestedContainer(keyedBy: WindowKeys.self, forKey: .window)
            let lower = try nested.decode(Date.self, forKey: .lowerBound)
            let upper = try nested.decode(Date.self, forKey: .upperBound)
            window = lower ... upper
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(tagType, forKey: .tagType)
        try container.encodeIfPresent(tagValue, forKey: .tagValue)
        try container.encode(metric, forKey: .metric)
        try container.encode(peakTimestamp, forKey: .peakTimestamp)
        try container.encode(peakValue, forKey: .peakValue)
        try container.encode(peakZScore, forKey: .peakZScore)
        try container.encode(totalAnomalies, forKey: .totalAnomalies)
        try container.encodeIfPresent(totalBytes, forKey: .totalBytes)
        try container.encode(confidence, forKey: .confidence)
        try container.encode(narrative, forKey: .narrative)
        try container.encode(anomalyIDs, forKey: .anomalyIDs)
        var nested = container.nestedContainer(keyedBy: WindowKeys.self, forKey: .window)
        try nested.encode(window.lowerBound, forKey: .lowerBound)
        try nested.encode(window.upperBound, forKey: .upperBound)
    }
}

struct AnalyzerParams: Codable, Hashable {
    let windowSeconds: Int
    let zThreshold: Double
    let algorithm: String
    let ewmaAlpha: Double
}

struct AnalyzerRequest: Codable, Hashable {
    let packets: [PacketSample]
    let metrics: [MetricPoint]
    let params: AnalyzerParams
    let payloadConfig: AnalyzerPayloadConfig?
    let controls: AnalyzerControls?
}

struct AnalyzerControls: Codable, Hashable {
    let disableDetectors: [String]?
    let detectorParams: [String: [String: Double]]?
    let alerts: AnalyzerAlertConfig?
}

struct AnalyzerAlertConfig: Codable, Hashable {
    let scoreThreshold: Double
    let notificationsEnabled: Bool
    let webhookEnabled: Bool
    let webhookURL: String?
    let destinations: [String]?
}

struct AnalyzerPreferencesSnapshot: Codable, Hashable {
    let captureMode: String
    let windowSeconds: Int
    let zThreshold: Double
    let timeRange: TimeInterval
    let algorithm: String
    let ewmaAlpha: Double
    let payloadInspectionEnabled: Bool
    let detectorLegacyEnabled: Bool?
    let detectorSeasonalityEnabled: Bool?
    let detectorChangePointEnabled: Bool?
    let detectorMultivariateEnabled: Bool?
    let detectorNewTalkerEnabled: Bool?
    let alertScoreThreshold: Double?
    let alertNotificationsEnabled: Bool?
    let alertWebhookEnabled: Bool?
    let alertWebhookURL: String?
}

struct AnalyzerSession: Codable, Hashable {
    let createdAt: Date
    let summary: CaptureSummary
    let packets: [PacketSample]
    let perSecondMetrics: [MetricPoint]
    let perMinuteMetrics: [MetricPoint]
    let analyzerResult: AnalyzerResult?
    let streamingAnomalies: [Anomaly]
    let preferences: AnalyzerPreferencesSnapshot
}

struct CaptureSummary: Hashable, Codable {
    let interfaceName: String?
    let packetCount: Int
    let totalBytes: Int
    let duration: TimeInterval
    let start: Date?
    let end: Date?
}

struct AnalyzerTagRank: Identifiable, Hashable {
    let tagType: String
    let value: String
    let bytes: Double
    let packets: Double
    var id: String { "\(tagType)|\(value)" }
}

extension JSONDecoder {
    static func iso8601Fractional() -> JSONDecoder {
        let decoder = JSONDecoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        decoder.dateDecodingStrategy = .custom { decoder in
            let container = try decoder.singleValueContainer()
            let string = try container.decode(String.self)
            if let date = formatter.date(from: string) { return date }
            if let legacy = ISO8601DateFormatter().date(from: string) { return legacy }
            if let epoch = TimeInterval(string) { return Date(timeIntervalSince1970: epoch) }
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unrecognized date \(string)")
        }
        return decoder
    }
}

extension JSONEncoder {
    static func iso8601Fractional() -> JSONEncoder {
        let encoder = JSONEncoder()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        encoder.dateEncodingStrategy = .custom { date, encoder in
            var container = encoder.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        encoder.outputFormatting = [.withoutEscapingSlashes]
        return encoder
    }
}
