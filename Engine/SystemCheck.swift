// 
//  [SystemCheck].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation


class SystemCheck: Identifiable, Hashable {
    private let titleValue: String
    private let synopsisValue: String
    private var categoriesValue: [String]
    private var benchmarkIdentifiersValue: [String]
    private let remediationValue: String
    private let severityValue: String
    private let documentationValue: String?
    private let rationaleValue: String
    private let referenceValue: Int32
    private let baselineVerdict: String?

    var status: String?
    var checkstatus: String?
    var error: Error?

    let id = UUID()

    init(
        name: String,
        description: String,
        category: String,
        categories additionalCategories: [String] = [],
        benchmarks additionalBenchmarks: [String] = [],
        remediation: String,
        severity: String,
        documentation: String,
        mitigation: String,
        checkstatus: String? = nil,
        docID: Int32
    ) {
        self.titleValue = name
        self.synopsisValue = description
        let originalCategory = category
        self.categoriesValue = Self.normalizedCategories(primary: category, additional: additionalCategories)
        self.remediationValue = remediation
        self.severityValue = severity
        let trimmedDocumentation = documentation.trimmingCharacters(in: .whitespacesAndNewlines)
        self.documentationValue = trimmedDocumentation.isEmpty ? nil : trimmedDocumentation
        self.rationaleValue = mitigation
        self.referenceValue = docID
        self.baselineVerdict = checkstatus
        self.checkstatus = checkstatus

        var benchmarkTags = additionalBenchmarks.map(Self.normalizedBenchmarkLabel)
        if originalCategory.trimmingCharacters(in: .whitespacesAndNewlines).caseInsensitiveCompare("CIS Benchmark") == .orderedSame {
            benchmarkTags.append("CIS Benchmark")
        }
        self.benchmarkIdentifiersValue = Self.mergeIdentifiers(existing: [], additional: benchmarkTags)
    }

    // MARK: - Execution

    func prepareForExecution() {
        status = nil
        error = nil
        checkstatus = baselineVerdict
    }

    func evaluate() {
        check()
    }

    func check() {
        fatalError("Subclasses must override `check()` in \(String(describing: Self.self)).")
    }

    func makeFinding(timedOut: Bool, timeoutDescription: String?) -> AuditFinding {
        let metadata = AuditFinding.Metadata(
            title: titleValue,
            synopsis: synopsisValue,
            categories: categoriesValue,
            remediation: remediationValue,
            rationale: rationaleValue,
            referenceURL: documentationValue.flatMap(URL.init(string:)),
            docReference: referenceValue,
            severity: AuditFinding.Severity(legacyLabel: severityValue),
            severityLabel: severityValue,
            benchmarks: benchmarkIdentifiersValue
        )

        let summary = resolvedStatusSummary(timedOut: timedOut, timeoutDescription: timeoutDescription)
        let verdictLabel = checkstatus
        let runtimeError = error?.localizedDescription

        return AuditFinding(
            id: id,
            metadata: metadata,
            verdict: AuditFinding.Verdict(legacyLabel: verdictLabel),
            statusSummary: summary,
            rawVerdictLabel: verdictLabel,
            rawSeverityLabel: severityValue,
            runtimeError: runtimeError
        )
    }

    private func resolvedStatusSummary(timedOut: Bool, timeoutDescription: String?) -> String? {
        if let status, !status.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return status
        }
        if timedOut {
            return timeoutDescription ?? "Evaluation timed out."
        }
        if let runtimeError = error?.localizedDescription {
            return runtimeError
        }
        return nil
    }

    // MARK: - Legacy Accessors

    var name: String { titleValue }
    var description: String { synopsisValue }
    var category: String { categoriesValue.first ?? "Uncategorized" }
    var categories: [String] { categoriesValue }
    var benchmarks: [String] { benchmarkIdentifiersValue }
    var remediation: String { remediationValue }
    var severity: String { severityValue }
    var documentation: String? { documentationValue }
    var mitigation: String { rationaleValue }
    var docID: Int32 { referenceValue }

    // MARK: - Hashable

    static func == (lhs: SystemCheck, rhs: SystemCheck) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }

    func appendCategories(_ categories: [String]) {
        categoriesValue = Self.mergeCategories(existing: categoriesValue, additional: categories)
    }

    func appendBenchmarks(_ benchmarks: [String]) {
        benchmarkIdentifiersValue = Self.mergeIdentifiers(existing: benchmarkIdentifiersValue, additional: benchmarks.map(Self.normalizedBenchmarkLabel))
    }
}

private extension SystemCheck {
    static func normalizedCategories(primary: String, additional: [String]) -> [String] {
        let primaryTrimmed = normalizedLabel(for: primary)
        let seed = primaryTrimmed.isEmpty ? [] : [primaryTrimmed]
        return mergeCategories(existing: seed, additional: additional)
    }

    static func mergeCategories(existing: [String], additional: [String]) -> [String] {
        var ordered = existing
        for raw in additional {
            let trimmed = normalizedLabel(for: raw)
            guard !trimmed.isEmpty else { continue }
            if !ordered.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                ordered.append(trimmed)
            }
        }
        if ordered.count > 1 {
            ordered.removeAll { $0.caseInsensitiveCompare("Uncategorized") == .orderedSame }
        }
        if ordered.isEmpty {
            ordered.append("Uncategorized")
        }
        return ordered
    }

    static func normalizedLabel(for label: String) -> String {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.caseInsensitiveCompare("CIS Benchmark") == .orderedSame {
            return "Compliance"
        }
        return trimmed
    }

    static func mergeIdentifiers(existing: [String], additional: [String]) -> [String] {
        var ordered = existing
        for raw in additional {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !ordered.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                ordered.append(trimmed)
            }
        }
        return ordered
    }

    static func normalizedBenchmarkLabel(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
