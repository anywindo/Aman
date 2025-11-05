import Foundation

struct DetectionComponentBreakdown: Codable, Hashable, Identifiable {
    let detector: String
    let score: Double
    let weight: Double?
    let label: String?
    let reasonCodes: [String]?

    var id: String {
        if let label = label, !label.isEmpty {
            return "\(detector):\(label)"
        }
        return detector
    }
}

struct AdvancedDetectionResult: Codable, Hashable {
    let phase: String?
    let scores: [DetectionComponentBreakdown]
    let reasonCodes: [String]
    let seasonalityConfidence: Double?
    let processingLatencyMs: Double?
    let seasonality: AdvancedSeasonalityPayload?
    let changePoints: [ChangePointEvent]?
    let changePointDiagnostics: ChangePointDiagnostics?
    let multivariate: MultivariateAnalysis?
    let newTalkers: NewTalkerPayload?
    let alerts: AdvancedAlertPayload?

    var highestScore: DetectionComponentBreakdown? {
        scores.max(by: { $0.score < $1.score })
    }
}

struct SeasonalityBandPoint: Codable, Hashable, Identifiable {
    let timestamp: Date
    let baseline: Double
    let lower: Double
    let upper: Double

    var id: Date { timestamp }
}

struct SeasonalityMetricBands: Codable, Hashable {
    let confidence: Double?
    let residualStdDev: Double?
    let band: [SeasonalityBandPoint]
}

struct AdvancedSeasonalityPayload: Codable, Hashable {
    let periodSeconds: Double?
    let sampleIntervalSeconds: Double?
    let metrics: [String: SeasonalityMetricBands]
    let diagnostics: SeasonalityDiagnostics?
}

struct SeasonalityDiagnostics: Codable, Hashable {
    let candidates: [SeasonalityCandidate]
    let selected: SeasonalityCandidate?
}

struct SeasonalityCandidate: Codable, Hashable {
    let periodSeconds: Double?
    let cycles: Double?
    let explained: Double?
    let status: String?
}

struct ChangePointEvent: Codable, Hashable, Identifiable {
    let id: UUID
    let timestamp: Date
    let metric: String
    let direction: String
    let beforeMean: Double
    let afterMean: Double
    let meanDelta: Double
    let score: Double
}

struct ChangePointDiagnostics: Codable, Hashable {
    let sampleIntervalSeconds: Double?
    let windowSteps: Int?
    let thresholdStdDevs: Double?
    let windowSeconds: Double?
    let detected: Int?
}

struct MultivariateAnalysis: Codable, Hashable {
    let scores: [MultivariateScore]
    let diagnostics: MultivariateDiagnostics?
}

struct MultivariateScore: Codable, Hashable, Identifiable {
    let id: UUID
    let timestamp: Date
    let score: Double
    let features: [String: Double]?
    let zScores: [String: Double]?
    let contributions: [FeatureContribution]
}

struct FeatureContribution: Codable, Hashable, Identifiable {
    let feature: String
    let weight: Double
    let zScore: Double
    let direction: String

    var id: String { feature }
}

struct MultivariateDiagnostics: Codable, Hashable {
    let sampleIntervalSeconds: Double?
    let windowSteps: Int?
    let evaluatedPoints: Int?
}

struct NewTalkerPayload: Codable, Hashable {
    let entries: [NewTalker]
    let diagnostics: NewTalkerDiagnostics?
}

struct NewTalker: Codable, Hashable, Identifiable {
    let id: UUID
    let tagType: String
    let tagValue: String
    let firstSeen: Date
    let lastSeen: Date
    let totalBytes: Double
    let samples: Int
    let entropyDelta: Double?
}

struct NewTalkerDiagnostics: Codable, Hashable {
    let uniqueTagsEvaluated: Int?
    let detected: Int?
    let returned: Int?
}

struct AdvancedAlertPayload: Codable, Hashable {
    let events: [AlertEvent]
    let config: AlertConfig?
}

struct AlertEvent: Codable, Hashable, Identifiable {
    let id: UUID
    let detector: String
    let score: Double
    let severity: String
    let message: String
    let timestamp: Date
    let destinations: [String]?

    private enum CodingKeys: String, CodingKey {
        case id
        case detector
        case score
        case severity
        case message
        case timestamp
        case destinations
    }

    init(
        id: UUID,
        detector: String,
        score: Double,
        severity: String,
        message: String,
        timestamp: Date,
        destinations: [String]?
    ) {
        self.id = id
        self.detector = detector
        self.score = score
        self.severity = severity
        self.message = message
        self.timestamp = timestamp
        self.destinations = destinations
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let idString = try container.decodeIfPresent(String.self, forKey: .id)
        if let idString, let uuid = UUID(uuidString: idString) {
            id = uuid
        } else {
            id = UUID()
        }
        detector = try container.decodeIfPresent(String.self, forKey: .detector) ?? "unknown"
        score = try container.decodeIfPresent(Double.self, forKey: .score) ?? 0.0
        severity = try container.decodeIfPresent(String.self, forKey: .severity) ?? "info"
        message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        if let rawTimestamp = try container.decodeIfPresent(Date.self, forKey: .timestamp) {
            timestamp = rawTimestamp
        } else if let stringTimestamp = try container.decodeIfPresent(String.self, forKey: .timestamp), let parsed = ISO8601DateFormatter().date(from: stringTimestamp) {
            timestamp = parsed
        } else {
            timestamp = Date()
        }
        destinations = try container.decodeIfPresent([String].self, forKey: .destinations)
    }
}

struct AlertConfig: Codable, Hashable {
    let scoreThreshold: Double?
    let notificationsEnabled: Bool?
    let webhookEnabled: Bool?
    let webhookURL: String?
    let destinations: [String]?
}
