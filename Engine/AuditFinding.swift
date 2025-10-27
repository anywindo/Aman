//
//  AuditFinding.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

/// Immutable representation of a single security check outcome shown in the UI.
struct AuditFinding: Identifiable, Hashable {
    struct Metadata: Hashable {
        let title: String
        let synopsis: String
        let categories: [String]
        let remediation: String
        let rationale: String
        let referenceURL: URL?
        let docReference: Int32
        let severity: Severity
        let severityLabel: String
        let benchmarks: [String]
    }

    enum Verdict: String, Hashable {
        case pass
        case investigate
        case actionRequired
        case unknown

        init(legacyLabel: String?) {
            guard let raw = legacyLabel?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
                self = .unknown
                return
            }
            switch raw {
            case "green", "pass", "ok":
                self = .pass
            case "yellow", "review", "warn":
                self = .investigate
            case "red", "fail":
                self = .actionRequired
            default:
                self = .unknown
            }
        }

        var displayLabel: String {
            switch self {
            case .pass: return "Pass"
            case .investigate: return "Review"
            case .actionRequired: return "Action"
            case .unknown: return "Unknown"
            }
        }
    }

    enum Severity: String, Hashable {
        case low
        case medium
        case high
        case critical
        case informational
        case unknown

        init(legacyLabel: String) {
            switch legacyLabel.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
            case "low": self = .low
            case "medium": self = .medium
            case "high": self = .high
            case "critical": self = .critical
            case "info", "informational": self = .informational
            default: self = .unknown
            }
        }

        var displayLabel: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            case .critical: return "Critical"
            case .informational: return "Info"
            case .unknown: return "Unknown"
            }
        }
    }

    let id: UUID
    let metadata: Metadata
    let verdict: Verdict
    let statusSummary: String?
    let rawVerdictLabel: String?
    let rawSeverityLabel: String
    let runtimeError: String?

    // Convenience surface used heavily by SwiftUI views.
    var title: String { metadata.title }
    var synopsis: String { metadata.synopsis }
    var categories: [String] { metadata.categories }
    var category: String { metadata.categories.first ?? "Uncategorized" }
    var categoryDisplay: String {
        let joined = metadata.categories.joined(separator: " • ")
        return joined.isEmpty ? "Uncategorized" : joined
    }
    var benchmarks: [String] { metadata.benchmarks }
    var remediation: String { metadata.remediation }
    var rationale: String { metadata.rationale }
    var docReference: Int32 { metadata.docReference }
    var referenceURL: URL? { metadata.referenceURL }
    var severity: Severity { metadata.severity }
    var severityDisplay: String { metadata.severity.displayLabel }
}
