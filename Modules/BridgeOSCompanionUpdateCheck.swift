//
//  BridgeOSCompanionUpdateCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class BridgeOSCompanionUpdateCheck: SystemCheck {
    init() {
        super.init(
            name: "Check BridgeOS and Companion Update Status",
            description: "Reports the installed BridgeOS firmware version and flags pending bridgeOS/iOS/watchOS companion updates from softwareupdate.",
            category: "Continuity",
            remediation: "Install outstanding BridgeOS or companion device updates via Software Update or Apple Configurator.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/deployment-reference-macos/update-software-DEP809886fe4/web",
            mitigation: "Keeping BridgeOS and paired device firmware current reduces continuity failures and mitigates known vulnerabilities in the secure enclave stack.",
            docID: 214
        )
    }

    override func check() {
        var sections: [String] = []
        var issues: [String] = []
        var warnings: [String] = []

        if let bridgeSummary = bridgeVersionSummary() {
            sections.append(bridgeSummary)
        } else {
            warnings.append("Unable to read /System/Library/CoreServices/BridgeVersion.plist")
        }

        if let ibrideInfo = iBridgeSummary() {
            sections.append(ibrideInfo)
        }

        switch softwareUpdateCatalog() {
        case .success(let catalog):
            if !catalog.bridgeUpdates.isEmpty {
                issues.append("Pending BridgeOS updates:\n  • " + catalog.bridgeUpdates.joined(separator: "\n  • "))
            }
            if !catalog.companionUpdates.isEmpty {
                issues.append("Pending companion firmware updates:\n  • " + catalog.companionUpdates.joined(separator: "\n  • "))
            }
            if catalog.bridgeUpdates.isEmpty && catalog.companionUpdates.isEmpty {
                sections.append("softwareupdate reports no outstanding bridgeOS or companion updates.")
            }
        case .failure(let error):
            warnings.append(error)
        }

        let companions = detectedCompanionDevices()
        if !companions.isEmpty {
            sections.append("Recently seen companion devices:\n  • " + companions.joined(separator: "\n  • "))
        }

        var outputLines: [String] = []
        if !sections.isEmpty {
            outputLines.append(contentsOf: sections)
        }
        if !issues.isEmpty {
            outputLines.append(contentsOf: issues)
        }
        if !warnings.isEmpty {
            outputLines.append("Notes: " + warnings.joined(separator: "; "))
        }

        status = outputLines.joined(separator: "\n\n")

        if !issues.isEmpty {
            checkstatus = "Red"
        } else if !warnings.isEmpty {
            checkstatus = "Yellow"
        } else {
            checkstatus = "Green"
        }
    }

    private func bridgeVersionSummary() -> String? {
        let path = "/System/Library/CoreServices/BridgeVersion.plist"
        guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any], !dict.isEmpty else {
            return nil
        }

        var parts: [String] = []
        if let version = dict["BridgeVersion"] as? String {
            parts.append("version \(version)")
        }
        if let build = dict["BridgeProductBuildVersion"] as? String {
            parts.append("build \(build)")
        }
        if let seed = dict["IsSeed"] {
            parts.append("seed \(seed)")
        }

        if parts.isEmpty {
            return "BridgeOS firmware information could not be parsed from \(path)."
        }
        return "BridgeOS firmware: " + parts.joined(separator: ", ")
    }

    private func iBridgeSummary() -> String? {
        guard let data = runProfiler(dataType: "SPiBridgeDataType") else {
            return nil
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let root = json as? [String: Any],
            let entries = root["SPiBridgeDataType"] as? [[String: Any]]
        else {
            return nil
        }

        guard let info = entries.first else {
            return nil
        }

        let model = info["ibridge_model_name"] as? String
        let build = info["ibridge_build"] as? String
        if model == nil && build == nil {
            return nil
        }

        var fragments: [String] = []
        if let model {
            fragments.append(model)
        }
        if let build {
            fragments.append("build \(build)")
        }

        return "iBridge controller: " + fragments.joined(separator: ", ")
    }

    private enum CatalogResult {
        case success(CatalogSummary)
        case failure(String)
    }

    private struct CatalogSummary {
        let bridgeUpdates: [String]
        let companionUpdates: [String]
    }

    private func softwareUpdateCatalog() -> CatalogResult {
        let command = runCommand(
            executable: "/usr/sbin/softwareupdate",
            arguments: ["--list", "--no-scan"]
        )

        guard command.exitCode == 0 || command.stdout.contains("No new software available.") else {
            if !command.stderr.isEmpty {
                return .failure("softwareupdate failed: \(command.stderr.trimmingCharacters(in: .whitespacesAndNewlines))")
            }
            return .failure("softwareupdate exited with status \(command.exitCode)")
        }

        let summary = parseSoftwareUpdateCatalog(command.stdout)
        return .success(summary)
    }

    private func parseSoftwareUpdateCatalog(_ output: String) -> CatalogSummary {
        let lines = output
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var entries: [String] = []
        var current: String?

        for line in lines {
            if line.hasPrefix("*") {
                if let existing = current {
                    entries.append(existing)
                }
                current = line
            } else if var existing = current {
                existing.append(" \(line)")
                current = existing
            }
        }

        if let existing = current {
            entries.append(existing)
        }

        let bridgeTokens = ["bridgeos", "ibridge", "bridge firmware", "bridge"]
        let companionTokens = ["ios", "watchos", "ipados", "tvos", "visionos"]

        var bridge: [String] = []
        var companion: [String] = []

        for entry in entries {
            let lower = entry.lowercased()
            if bridgeTokens.contains(where: { lower.contains($0) }) {
                bridge.append(entry)
            }
            if companionTokens.contains(where: { lower.contains($0) }) {
                companion.append(entry)
            }
        }

        return CatalogSummary(bridgeUpdates: bridge, companionUpdates: companion)
    }

    private func detectedCompanionDevices() -> [String] {
        guard let data = runProfiler(dataType: "SPBluetoothDataType") else {
            return []
        }

        guard
            let json = try? JSONSerialization.jsonObject(with: data, options: []),
            let root = json as? [String: Any],
            let entries = root["SPBluetoothDataType"] as? [[String: Any]]
        else {
            return []
        }

        var devices: [String] = []
        for entry in entries {
            if let connected = entry["device_connected"] as? [[String: Any]] {
                devices.append(contentsOf: parseBluetoothDevices(list: connected, state: "connected"))
            }
            if let notConnected = entry["device_not_connected"] as? [[String: Any]] {
                devices.append(contentsOf: parseBluetoothDevices(list: notConnected, state: "seen"))
            }
        }

        return devices
    }

    private func parseBluetoothDevices(list: [[String: Any]], state: String) -> [String] {
        var output: [String] = []

        for wrapper in list {
            guard let nameEntry = wrapper.first(where: { $0.value is [String: Any] }) else {
                continue
            }
            let deviceName = nameEntry.key
            guard let details = nameEntry.value as? [String: Any] else {
                continue
            }

            let minor = (details["device_minorType"] as? String) ?? ""
            let vendor = (details["device_vendorID"] as? String) ?? ""
            if isCompanionDevice(name: deviceName, minorType: minor, vendor: vendor) {
                var descriptor = "\(deviceName) (\(state)"
                if let firmware = details["device_firmwareVersion"] as? String, !firmware.isEmpty {
                    descriptor += ", firmware \(firmware)"
                }
                descriptor += ")"
                output.append(descriptor)
            }
        }

        return output
    }

    private func isCompanionDevice(name: String, minorType: String, vendor: String) -> Bool {
        let loweredName = name.lowercased()
        let loweredMinor = minorType.lowercased()

        if loweredMinor.contains("phone") || loweredMinor.contains("watch") || loweredMinor.contains("tablet") {
            return true
        }

        if loweredName.contains("iphone") || loweredName.contains("ipad") || loweredName.contains("watch") {
            return true
        }

        // Treat Apple devices without explicit minor type as companions.
        if vendor.lowercased().contains("0x004c") && (loweredName.contains("apple") || loweredName.contains("ipad") || loweredName.contains("iphone")) {
            return true
        }

        return false
    }

    private struct CommandResult {
        let exitCode: Int32
        let stdout: String
        let stderr: String
    }

    private func runCommand(executable: String, arguments: [String]) -> CommandResult {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: executable)
        task.arguments = arguments

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return CommandResult(exitCode: -1, stdout: "", stderr: error.localizedDescription)
        }

        let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return CommandResult(exitCode: task.terminationStatus, stdout: stdout, stderr: stderr)
    }

    private func runProfiler(dataType: String) -> Data? {
        let result = runCommand(executable: "/usr/sbin/system_profiler", arguments: [dataType, "-json"])
        guard result.exitCode == 0 else {
            return nil
        }
        let data = result.stdout.data(using: .utf8)
        return data
    }
}
