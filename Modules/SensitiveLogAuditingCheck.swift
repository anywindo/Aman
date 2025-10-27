//
//  SensitiveLogAuditingCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class SensitiveLogAuditingCheck: SystemCheck {
    private let sensitiveTokens: [String] = [
        "com.apple.locationd",
        "com.apple.securityd",
        "com.apple.identityservices",
        "com.apple.tccd",
        "com.apple.icloud",
        "com.apple.contactsd",
        "com.apple.imagent",
        "com.apple.cored"
    ]

    private let privacyKeys: [String] = [
        "EnablePrivateData",
        "EnableSensitiveData",
        "EnableInternalDebug",
        "FilterType",
        "Mode"
    ]

    private struct LogSource {
        let label: String
        let matches: [String]
        let flags: [String: String]
    }

    init() {
        super.init(
            name: "Audit Sensitive Unified Logging Filters",
            description: "Detects managed logging payloads targeting privacy-critical subsystems and summarises their filter settings.",
            category: "Privacy",
            remediation: "Deploy a com.apple.system.logging payload that filters sensitive subsystems (e.g. locationd, securityd) and enforces private data redaction.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/mdm/logging-settings-mdmb51960f0/web",
            mitigation: "Ensuring unified logging filters capture sensitive domains without exposing private data helps meet privacy auditing mandates while limiting disclosure risk.",
            docID: 215
        )
    }

    override func check() {
        var sources: [LogSource] = []
        var warnings: [String] = []

        let prefResult = gatherPreferencePolicies()
        sources.append(contentsOf: prefResult.sources)
        warnings.append(contentsOf: prefResult.warnings)

        let profileResult = gatherProfilePolicies()
        sources.append(contentsOf: profileResult.sources)
        warnings.append(contentsOf: profileResult.warnings)

        guard !sources.isEmpty else {
            if warnings.isEmpty {
                status = "No unified logging privacy filters were located in managed preferences or installed profiles."
                checkstatus = "Red"
            } else {
                status = "Unable to locate logging filters: " + warnings.joined(separator: "; ")
                checkstatus = "Yellow"
            }
            return
        }

        var sections: [String] = []
        var hasSensitiveCoverage = false

        for source in sources {
            var lines: [String] = []
            lines.append(source.label)

            if source.matches.isEmpty {
                lines.append("  • No sensitive subsystem tokens detected.")
            } else {
                hasSensitiveCoverage = true
                lines.append("  • Targets: \(source.matches.joined(separator: ", "))")
            }

            if source.flags.isEmpty {
                lines.append("  • No privacy flags found.")
            } else {
                for entry in source.flags.sorted(by: { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }) {
                    lines.append("  • \(entry.key): \(entry.value)")
                }
            }

            sections.append(lines.joined(separator: "\n"))
        }

        if !warnings.isEmpty {
            sections.append("Notes: " + warnings.joined(separator: "; "))
        }

        status = sections.joined(separator: "\n\n")
        checkstatus = hasSensitiveCoverage ? "Green" : "Yellow"
    }

    private func gatherPreferencePolicies() -> (sources: [LogSource], warnings: [String]) {
        var collected: [LogSource] = []
        var warnings: [String] = []

        let candidates = [
            "/Library/Preferences/com.apple.system.logging.plist",
            "/Library/Managed Preferences/com.apple.system.logging.plist",
            ("~/Library/Preferences/com.apple.system.logging.plist" as NSString).expandingTildeInPath,
            ("~/Library/Managed Preferences/com.apple.system.logging.plist" as NSString).expandingTildeInPath
        ]

        let fm = FileManager.default
        for path in candidates {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }
            guard fm.isReadableFile(atPath: path) else {
                warnings.append("Cannot read \(path)")
                continue
            }
            guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any], !dict.isEmpty else {
                continue
            }
            if let source = buildLogSource(from: dict, label: "Managed Preferences: \(path)") {
                collected.append(source)
            }
        }

        return (collected, warnings)
    }

    private func gatherProfilePolicies() -> (sources: [LogSource], warnings: [String]) {
        switch runProfilesXML() {
        case .failure(let error):
            return ([], [error])
        case .success(let data):
            guard
                let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
                let root = plist as? [String: Any]
            else {
                return ([], [])
            }

            var sources: [LogSource] = []
            collectLoggingPayloads(from: root, into: &sources)
            return (sources, [])
        }
    }

    private func collectLoggingPayloads(from object: Any, into sources: inout [LogSource]) {
        if let dict = object as? [String: Any] {
            if let payloadType = dict["PayloadType"] as? String, payloadType == "com.apple.system.logging" {
                let content = dict["PayloadContent"] ?? dict
                if let sourceDict = content as? [String: Any], let source = buildLogSource(from: sourceDict, label: payloadLabel(from: dict)) {
                    sources.append(source)
                } else if let source = buildLogSource(from: dict, label: payloadLabel(from: dict)) {
                    sources.append(source)
                }
            }

            for value in dict.values {
                collectLoggingPayloads(from: value, into: &sources)
            }
        } else if let array = object as? [Any] {
            for element in array {
                collectLoggingPayloads(from: element, into: &sources)
            }
        }
    }

    private func payloadLabel(from dictionary: [String: Any]) -> String {
        var parts: [String] = []
        if let display = dictionary["PayloadDisplayName"] as? String, !display.isEmpty {
            parts.append(display)
        }
        if let identifier = dictionary["PayloadIdentifier"] as? String, !identifier.isEmpty {
            parts.append(identifier)
        }
        if let org = dictionary["PayloadOrganization"] as? String, !org.isEmpty {
            parts.append(org)
        }
        if parts.isEmpty, let uuid = dictionary["PayloadUUID"] as? String {
            parts.append(uuid)
        }
        return "Profile Payload: " + parts.joined(separator: " / ")
    }

    private func buildLogSource(from dictionary: [String: Any], label: String) -> LogSource? {
        var matches = Set<String>()
        collectMatches(from: dictionary, into: &matches)

        var flags: [String: String] = [:]
        for key in privacyKeys {
            if let value = dictionary[key] {
                flags[key] = describe(value)
            }
        }

        if matches.isEmpty && flags.isEmpty {
            return nil
        }

        return LogSource(
            label: label,
            matches: matches.sorted(),
            flags: flags
        )
    }

    private func collectMatches(from object: Any, into store: inout Set<String>) {
        if let dict = object as? [String: Any] {
            for (key, value) in dict {
                for token in sensitiveTokens {
                    let loweredToken = token.lowercased()
                    if key.lowercased().contains(loweredToken) {
                        store.insert(token)
                    }
                }
                collectMatches(from: value, into: &store)

                if let stringValue = value as? String {
                    for token in sensitiveTokens where stringValue.lowercased().contains(token.lowercased()) {
                        store.insert(token)
                    }
                }
            }
        } else if let array = object as? [Any] {
            for element in array {
                collectMatches(from: element, into: &store)
            }
        } else if let string = object as? String {
            for token in sensitiveTokens where string.lowercased().contains(token.lowercased()) {
                store.insert(token)
            }
        }
    }

    private func describe(_ value: Any) -> String {
        switch value {
        case let number as NSNumber:
            return number.stringValue
        case let string as String:
            return string
        case let array as [Any]:
            return array.map { describe($0) }.joined(separator: ", ")
        case let dict as [String: Any]:
            let parts = dict
                .map { "\($0.key): \(describe($0.value))" }
                .sorted()
                .joined(separator: ", ")
            return "{\(parts)}"
        default:
            return String(describing: value)
        }
    }

    private enum ProfilesResult {
        case success(Data)
        case failure(String)
    }

    private func runProfilesXML() -> ProfilesResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/profiles")
        task.arguments = ["-C", "-o", "stdout-xml"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return .failure("profiles command failed: \(error.localizedDescription)")
        }

        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard task.terminationStatus == 0 else {
            if stderr.isEmpty {
                return .failure("profiles command exited with status \(task.terminationStatus)")
            }
            return .failure(stderr)
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        if data.isEmpty {
            return .failure("profiles returned empty XML output")
        }

        return .success(data)
    }
}
