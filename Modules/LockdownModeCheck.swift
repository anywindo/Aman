//
//  LockdownModeCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class LockdownModeCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Lockdown Mode Status",
            description: "Lockdown Mode helps protect high-risk users by hardening the system; CIS guidance expects organisations to audit its status.",
            category: "CIS Benchmark",
            categories: ["Security"],
            remediation: "Review Lockdown Mode in System Settings ▸ Privacy & Security ▸ Lockdown Mode.",
            severity: "Medium",
            documentation: "https://support.apple.com/HT212650",
            mitigation: "Enable or disable Lockdown Mode according to your organisation's policy and threat model.",
            docID: 101
        )
    }

    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["-currentHost", "read", "com.apple.LockdownMode", "LockdownModeEnabled"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch let error {
            print("Error checking Lockdown Mode: \(error)")
            status = "Unable to query Lockdown Mode status."
            checkstatus = "Yellow"
            self.error = error
            return
        }

        if task.terminationStatus != 0 {
            let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if stderr.contains("does not exist") || stderr.contains("No such key") {
                status = "Lockdown Mode is not configured (treated as disabled)."
                checkstatus = "Green"
            } else {
                status = "Unable to determine Lockdown Mode status."
                checkstatus = "Yellow"
            }
            return
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""

        if output == "1" || output == "true" {
            status = "Lockdown Mode is enabled."
            checkstatus = "Red"
        } else {
            status = "Lockdown Mode is disabled."
            checkstatus = "Green"
        }
    }
}
