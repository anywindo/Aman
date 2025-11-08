//
//  TimeMachineVolumesEncryptedCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

class TimeMachineVolumesEncryptedCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Time Machine Volumes Are Encrypted If Time Machine Is Enabled",
            description: "Check if Time Machine volumes are encrypted when Time Machine is enabled",
            category: "CIS Benchmark",
            remediation: "Enable encryption for each Time Machine backup disk from System Settings ▸ General ▸ Time Machine ▸ Options.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/mac-help/encrypt-time-machine-backup-disks-mh15141/mac",
            mitigation: "Encrypting Time Machine volumes helps protect your backup data from unauthorized access in case your backup disk is lost or stolen.",
            docID: 47
        )
    }
    
    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        task.arguments = ["destinationinfo"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch let error {
            status = "Unable to query Time Machine destinations."
            checkstatus = "Yellow"
            self.error = error
            return
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if task.terminationStatus != 0 {
            if output.contains("No destinations configured") {
                status = "Time Machine destinations are not configured."
                checkstatus = "Green"
            } else {
                status = "Unable to determine Time Machine encryption state."
                checkstatus = "Yellow"
            }
            return
        }

        let encryptionLines = output
            .components(separatedBy: .newlines)
            .filter { $0.trimmingCharacters(in: .whitespaces).hasPrefix("Encryption") }

        guard !encryptionLines.isEmpty else {
            status = "Could not parse Time Machine destination encryption state."
            checkstatus = "Yellow"
            return
        }

        let hasUnencrypted = encryptionLines.contains { line in
            let lower = line.lowercased()
            return lower.contains("disabled") || lower.contains("none") || lower.contains("no") || lower.contains("0")
        }

        if hasUnencrypted {
            status = "One or more Time Machine destinations are not encrypted."
            checkstatus = "Red"
        } else {
            status = "All configured Time Machine destinations report encryption enabled."
            checkstatus = "Green"
        }
    }
}
