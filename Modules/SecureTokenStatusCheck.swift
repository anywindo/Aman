//  SecureTokenStatusCheck.swift
//  Aman - Modules
//
// Created by Aman Team on 08/11/25
//

import Foundation

class SecureTokenStatusCheck: SystemCheck {
    init() {
        super.init(
            name: "Check SecureToken Status",
            description: "Reports SecureToken status for local users to ensure FileVault and bootstrap operations succeed.",
            category: "Accounts",
            remediation: "Grant SecureToken to required admin accounts using sysadminctl or configuration profiles.",
            severity: "High",
            documentation: "https://support.apple.com/HT208171",
            mitigation: "Ensuring necessary admins have SecureToken prevents FileVault and bootstrap failures.",
            docID: 210
        )
    }

    override func check() {
        guard let usersOutput = runCommand(path: "/usr/bin/dscl", arguments: [".", "-list", "/Users", "UniqueID"]) else {
            status = "Unable to enumerate local users."
            checkstatus = "Yellow"
            return
        }

        let lines = usersOutput.split(separator: "\n")
        let users = lines.compactMap { line -> (String, Int)? in
            let parts = line.split(separator: " ")
            guard parts.count == 2, let uid = Int(parts[1]) else { return nil }
            let user = String(parts[0])
            if uid >= 500 && !user.hasPrefix("_") && user != "daemon" && user != "nobody" {
                return (user, uid)
            }
            return nil
        }

        if users.isEmpty {
            status = "No local users found to evaluate."
            checkstatus = "Yellow"
            return
        }

        var missing: [String] = []
        var report: [String] = []

        for (user, _) in users {
            let output = runCommand(path: "/usr/sbin/sysadminctl", arguments: ["-secureTokenStatus", user]) ?? ""
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                report.append(trimmed)
            }
            if !trimmed.lowercased().contains("secure token is enabled") {
                missing.append(user)
            }
        }

        let summary = report.isEmpty ? "No SecureToken status information returned." : report.joined(separator: "\n\n")
        status = summary
        if !missing.isEmpty {
            status = (status ?? "") + "\n\nUsers without SecureToken: \(missing.joined(separator: ", "))"
            checkstatus = "Red"
        } else {
            checkstatus = "Green"
        }
    }

    private func runCommand(path: String, arguments: [String]) -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: path)
        task.arguments = arguments
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)
        } catch {
            return nil
        }
    }
}
