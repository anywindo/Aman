//
//  SoftwareUpdateDeferralCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class SoftwareUpdateDeferralCheck: SystemCheck {
    private let deferralKeys: Set<String> = [
        "EnforcedSoftwareUpdateDelay",
        "enforcedSoftwareUpdateDelay",
        "EnforcedSoftwareUpdateMajorOSDeferredInstallDelay",
        "enforcedSoftwareUpdateMajorOSDeferredInstallDelay",
        "EnforcedSoftwareUpdateMinorOSDeferredInstallDelay",
        "enforcedSoftwareUpdateMinorOSDeferredInstallDelay",
        "EnforcedSoftwareUpdateNonOSDeferredInstallDelay",
        "enforcedSoftwareUpdateNonOSDeferredInstallDelay",
        "ForcedSoftwareUpdateDelay",
        "ForceDelayedSoftwareUpdates",
        "DelayMajorOSUpdates",
        "DelayMinorOSUpdates",
        "DelayNonOSUpdates",
        "MaxUserDeferrals",
        "MaxDeferrals",
        "AllowedOSVersions",
        "AllowedOSVersion",
        "AllowedOSBuildVersion"
    ]

    private struct DeferralSource {
        let label: String
        let entries: [String]
    }

    init() {
        super.init(
            name: "Check Software Update Deferrals",
            description: "Collects configured software update deferral windows from managed preferences and configuration profiles.",
            category: "Security",
            remediation: "Deploy an MDM configuration profile that sets the required software update deferral windows (major, minor, and non-OS).",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/mdm/allow-or-deny-software-updates-mdmcbf9e7a/web",
            mitigation: "Documenting deferral windows ensures managed Macs postpone updates according to policy while still receiving fixes in the expected time frame.",
            docID: 213
        )
    }

    override func check() {
        var sections: [String] = []
        var foundDeferrals = false
        var warnings: [String] = []

        for path in preferenceCandidates() {
            let (source, warning) = gatherDeferrals(fromPlistAt: path)
            if let source {
                foundDeferrals = true
                sections.append(format(source: source))
            }
            if let warning {
                warnings.append(warning)
            }
        }

        let profileSources = gatherDeferralsFromProfiles()
        if !profileSources.isEmpty {
            foundDeferrals = true
            profileSources.forEach { sections.append(format(source: $0)) }
        }

        if foundDeferrals {
            status = sections.joined(separator: "\n\n")
            checkstatus = "Green"
            if !warnings.isEmpty {
                status = (status ?? "") + "\n\nNotes: " + warnings.joined(separator: "; ")
            }
            return
        }

        if !warnings.isEmpty {
            status = "Unable to confirm deferral windows: " + warnings.joined(separator: "; ")
            checkstatus = "Yellow"
            return
        }

        status = "No software update deferral keys were located in managed preferences or configuration profiles."
        checkstatus = "Red"
    }

    private func preferenceCandidates() -> [String] {
        [
            "/Library/Preferences/com.apple.SoftwareUpdate.plist",
            "/Library/Managed Preferences/com.apple.SoftwareUpdate.plist",
            "/Library/Preferences/com.apple.applicationaccess.plist",
            "/Library/Managed Preferences/com.apple.applicationaccess.plist",
            ("~/Library/Preferences/com.apple.SoftwareUpdate.plist" as NSString).expandingTildeInPath,
            ("~/Library/Managed Preferences/com.apple.SoftwareUpdate.plist" as NSString).expandingTildeInPath,
            ("~/Library/Preferences/com.apple.applicationaccess.plist" as NSString).expandingTildeInPath,
            ("~/Library/Managed Preferences/com.apple.applicationaccess.plist" as NSString).expandingTildeInPath
        ]
    }

    private func gatherDeferrals(fromPlistAt path: String) -> (DeferralSource?, String?) {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
            return (nil, nil)
        }
        guard fm.isReadableFile(atPath: path) else {
            return (nil, "Cannot read \(path)")
        }
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any], !dict.isEmpty else {
            return (nil, nil)
        }

        let values = extractDeferralValues(from: dict)
        guard !values.isEmpty else {
            return (nil, nil)
        }

        let entries = formatValues(values)
        let label = "Preferences: \(path)"
        return (DeferralSource(label: label, entries: entries), nil)
    }

    private func gatherDeferralsFromProfiles() -> [DeferralSource] {
        guard let data = runProfilesXML() else {
            return []
        }

        guard let root = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil) else {
            return []
        }

        var sources: [DeferralSource] = []
        collectProfilePayloads(from: root, into: &sources)
        return sources
    }

    private func collectProfilePayloads(from object: Any, into sources: inout [DeferralSource]) {
        if let dict = object as? [String: Any] {
            if let payloadType = dict["PayloadType"] as? String,
               payloadType == "com.apple.SoftwareUpdate" || payloadType == "com.apple.applicationaccess" {
                let payloadObject = dict["PayloadContent"] ?? dict
                let values = extractDeferralValues(from: payloadObject)
                if !values.isEmpty {
                    let entries = formatValues(values)
                    let label = payloadLabel(from: dict)
                    sources.append(DeferralSource(label: "Profile Payload: \(label)", entries: entries))
                }
            }

            for value in dict.values {
                collectProfilePayloads(from: value, into: &sources)
            }
        } else if let array = object as? [Any] {
            for element in array {
                collectProfilePayloads(from: element, into: &sources)
            }
        }
    }

    private func payloadLabel(from dictionary: [String: Any]) -> String {
        var components: [String] = []
        if let displayName = dictionary["PayloadDisplayName"] as? String, !displayName.isEmpty {
            components.append(displayName)
        }
        if let identifier = dictionary["PayloadIdentifier"] as? String, !identifier.isEmpty {
            components.append(identifier)
        }
        if let organization = dictionary["PayloadOrganization"] as? String, !organization.isEmpty {
            components.append(organization)
        }
        if let type = dictionary["PayloadType"] as? String, components.isEmpty {
            components.append(type)
        }
        return components.joined(separator: " / ")
    }

    private func extractDeferralValues(from object: Any) -> [String: String] {
        var bag: [String: String] = [:]
        appendDeferralValues(from: object, into: &bag)
        return bag
    }

    private func appendDeferralValues(from object: Any, into bag: inout [String: String]) {
        if let dict = object as? [String: Any] {
            for (key, value) in dict {
                if deferralKeys.contains(key) {
                    bag[key] = describe(value)
                }
                appendDeferralValues(from: value, into: &bag)
            }
        } else if let array = object as? [Any] {
            for element in array {
                appendDeferralValues(from: element, into: &bag)
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

    private func formatValues(_ values: [String: String]) -> [String] {
        values
            .sorted { $0.key.localizedCaseInsensitiveCompare($1.key) == .orderedAscending }
            .map { "\($0.key): \($0.value)" }
    }

    private func format(source: DeferralSource) -> String {
        var lines: [String] = []
        lines.append(source.label)
        lines.append(contentsOf: source.entries.map { "  • \($0)" })
        return lines.joined(separator: "\n")
    }

    private func runProfilesXML() -> Data? {
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
            return nil
        }

        if task.terminationStatus != 0 {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        return data.isEmpty ? nil : data
    }
}
