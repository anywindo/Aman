//
//  CredentialFlowsCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class CredentialFlowsCheck: SystemCheck {
    private struct PolicyValue {
        let key: String
        let value: Bool
        let source: String
    }

    private struct TouchIDStatus {
        let permitted: Bool?
        let effective: Bool?
        let output: String
        let error: String?
    }

    private struct AutoUnlockStatus {
        let enabled: Bool?
        let details: [String: Any]
        let error: String?
        let source: String?
    }

    init() {
        super.init(
            name: "Check Touch ID and Auto Unlock Policies",
            description: "Compares Touch ID and Apple Watch unlock states against managed restrictions.",
            category: "Accounts",
            remediation: "Set allowFingerprintForUnlock/allowWatchUnlock in com.apple.applicationaccess and ensure biometric or watch unlock aligns with policy.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/mdm/restrictions-mdm38df53dd/1/web/1.0",
            mitigation: "Validating biometric and watch unlock posture ensures authentication flows match benchmark requirements for privileged access.",
            docID: 216
        )
    }

    override func check() {
        let touchStatus = readTouchIDStatus()
        let autoUnlockStatus = readAutoUnlockStatus()
        let policies = loadApplicationAccessPolicies()

        var lines: [String] = []
        var issues: [String] = []
        var warnings: [String] = []

        // Touch ID state
        if let permitted = touchStatus.permitted {
            lines.append("Touch ID biometrics for unlock: \(permitted ? "enabled" : "disabled")")
        } else {
            warnings.append("Unable to parse Touch ID unlock setting.")
        }

        if let effective = touchStatus.effective {
            lines.append("Touch ID effective unlock policy: \(effective ? "enabled" : "disabled")")
        }

        if let error = touchStatus.error {
            warnings.append("bioutil error: \(error)")
        }

        // Touch ID policy comparison
        if let policy = policies.touchID {
            lines.append("Managed Touch ID policy \(policy.key)=\(policy.value ? "allow" : "deny") (\(policy.source))")
            if let effective = touchStatus.effective, policy.value == false && effective {
                issues.append("Touch ID unlock enabled while policy forbids it.")
            }
            if let effective = touchStatus.effective, policy.value == true && !effective {
                issues.append("Touch ID unlock disabled despite policy allowing it.")
            }
        } else {
            warnings.append("No explicit Touch ID policy found.")
        }

        // Auto Unlock state
        if let enabled = autoUnlockStatus.enabled {
            lines.append("Apple Watch Auto Unlock: \(enabled ? "enabled" : "disabled")")
        } else if autoUnlockStatus.details.isEmpty {
            lines.append("Apple Watch Auto Unlock: not configured.")
        }

        if !autoUnlockStatus.details.isEmpty {
            let summary = autoUnlockStatus.details
                .map { "\($0.key)=\(stringifyPreference($0.value))" }
                .sorted()
                .joined(separator: ", ")
            lines.append("Auto Unlock preference snapshot: \(summary)")
        }

        if let autoError = autoUnlockStatus.error {
            warnings.append("Auto Unlock query: \(autoError)")
        }

        if let policy = policies.autoUnlock {
            lines.append("Managed Watch unlock policy \(policy.key)=\(policy.value ? "allow" : "deny") (\(policy.source))")
            if let enabled = autoUnlockStatus.enabled, policy.value == false && enabled {
                issues.append("Apple Watch unlock enabled while policy forbids it.")
            }
            if let enabled = autoUnlockStatus.enabled, policy.value == true && !enabled {
                issues.append("Apple Watch unlock disabled despite policy allowing it.")
            }
        } else {
            warnings.append("No explicit Apple Watch unlock policy found.")
        }

        status = (lines + issues.map { "Issue: \($0)" } + (warnings.isEmpty ? [] : ["Notes: " + warnings.joined(separator: "; ")])).joined(separator: "\n")

        if !issues.isEmpty {
            checkstatus = "Red"
        } else if warnings.count > 1 || (warnings.count == 1 && autoUnlockStatus.enabled == nil) {
            checkstatus = "Yellow"
        } else {
            checkstatus = "Green"
        }
    }

    private func readTouchIDStatus() -> TouchIDStatus {
        let result = runCommand(executable: "/usr/bin/bioutil", arguments: ["-r"])
        guard result.exitCode == 0 else {
            return TouchIDStatus(permitted: nil, effective: nil, output: result.stdout, error: result.stderr.isEmpty ? "bioutil exited with status \(result.exitCode)" : result.stderr)
        }

        let lines = result.stdout.split(separator: "\n").map { String($0).trimmingCharacters(in: .whitespaces) }
        let permitted = parseBiometricFlag(label: "Biometrics for unlock", in: lines)
        let effective = parseBiometricFlag(label: "Effective biometrics for unlock", in: lines)

        return TouchIDStatus(permitted: permitted, effective: effective, output: result.stdout, error: nil)
    }

    private func parseBiometricFlag(label: String, in lines: [String]) -> Bool? {
        for line in lines {
            let lower = line.lowercased()
            if lower.hasPrefix(label.lowercased()) {
                let components = line.split(separator: ":")
                guard let value = components.last?.trimmingCharacters(in: .whitespaces) else {
                    return nil
                }
                if value == "1" || value.caseInsensitiveCompare("true") == .orderedSame {
                    return true
                }
                if value == "0" || value.caseInsensitiveCompare("false") == .orderedSame {
                    return false
                }
            }
        }
        return nil
    }

    private func readAutoUnlockStatus() -> AutoUnlockStatus {
        let result = runCommand(
            executable: "/usr/bin/defaults",
            arguments: ["-currentHost", "read", "com.apple.AutoUnlock"]
        )

        guard result.exitCode == 0 else {
            let loweredError = result.stderr.lowercased()
            if loweredError.contains("does not exist") {
                return AutoUnlockStatus(enabled: nil, details: [:], error: nil, source: nil)
            }
            let error = result.stderr.isEmpty ? "defaults exited with status \(result.exitCode)" : result.stderr
            return AutoUnlockStatus(enabled: nil, details: [:], error: error.trimmingCharacters(in: .whitespacesAndNewlines), source: nil)
        }

        guard let data = result.stdout.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
        else {
            return AutoUnlockStatus(enabled: nil, details: [:], error: "Unable to parse AutoUnlock defaults output.", source: nil)
        }

        let dict = plist as? [String: Any] ?? [:]
        let stateCandidate = [
            dict["AutoUnlockState"],
            dict["AutoUnlockEnabled"],
            dict["Enabled"]
        ].compactMap { value -> Bool? in
            if let number = value as? NSNumber {
                return number.intValue != 0
            }
            if let string = value as? String {
                let lowered = string.lowercased()
                if lowered == "1" || lowered == "true" {
                    return true
                }
                if lowered == "0" || lowered == "false" {
                    return false
                }
            }
            return nil
        }.first

        return AutoUnlockStatus(enabled: stateCandidate, details: dict, error: nil, source: "defaults -currentHost read com.apple.AutoUnlock")
    }

    private func loadApplicationAccessPolicies() -> (touchID: PolicyValue?, autoUnlock: PolicyValue?) {
        let candidates = [
            "/Library/Managed Preferences/com.apple.applicationaccess.plist",
            "/Library/Preferences/com.apple.applicationaccess.plist",
            ("~/Library/Managed Preferences/com.apple.applicationaccess.plist" as NSString).expandingTildeInPath,
            ("~/Library/Preferences/com.apple.applicationaccess.plist" as NSString).expandingTildeInPath
        ]

        let fm = FileManager.default
        var touchPolicy: PolicyValue?
        var watchPolicy: PolicyValue?

        for path in candidates {
            var isDir: ObjCBool = false
            guard fm.fileExists(atPath: path, isDirectory: &isDir), !isDir.boolValue else {
                continue
            }
            guard let dict = NSDictionary(contentsOfFile: path) as? [String: Any], !dict.isEmpty else {
                continue
            }

            if touchPolicy == nil {
                if let value = extractBool(forKeys: ["allowFingerprintForUnlock", "allowTouchIDForUnlock", "forceFingerprintForUnlock"], in: dict) {
                    touchPolicy = PolicyValue(key: value.key, value: value.value, source: path)
                }
            }

            if watchPolicy == nil {
                if let value = extractBool(forKeys: ["allowWatchUnlock", "allowAutoUnlock", "forceWatchUnlock"], in: dict) {
                    watchPolicy = PolicyValue(key: value.key, value: value.value, source: path)
                }
            }
        }

        return (touchPolicy, watchPolicy)
    }

    private func extractBool(forKeys keys: [String], in dictionary: [String: Any]) -> (key: String, value: Bool)? {
        for key in keys {
            if let value = dictionary[key] as? Bool {
                return (key, value)
            }
            if let number = dictionary[key] as? NSNumber {
                return (key, number.boolValue)
            }
        }
        return nil
    }

    private func stringifyPreference(_ value: Any) -> String {
        switch value {
        case let number as NSNumber:
            return number.stringValue
        case let string as String:
            return string
        case let dict as [String: Any]:
            return dict
                .map { "\($0.key): \(stringifyPreference($0.value))" }
                .sorted()
                .joined(separator: ", ")
        case let array as [Any]:
            return array.map { stringifyPreference($0) }.joined(separator: ", ")
        default:
            return String(describing: value)
        }
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
}
