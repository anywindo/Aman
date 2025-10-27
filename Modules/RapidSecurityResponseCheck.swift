//  RapidSecurityResponseCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class RapidSecurityResponseCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Rapid Security Responses Are Enabled",
            description: "Verifies that macOS is configured to install Security Responses and system files automatically.",
            category: "CIS Benchmark",
            categories: ["Security"],
            remediation: "Enable 'Install Security Responses and system files' in System Settings ▸ General ▸ Software Update ▸ Automatic Updates.",
            severity: "Medium",
            documentation: "https://support.apple.com/HT213825",
            mitigation: "Automatic Security Responses ensure critical fixes and system files are applied quickly, reducing exposure time after a vulnerability disclosure.",
            docID: 102
        )
    }

    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "/Library/Preferences/com.apple.SoftwareUpdate.plist", "AutomaticallyInstallSecurityUpdates"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch let error {
            print("Error checking Rapid Security Responses: \(error)")
            status = "Unable to query Security Responses setting."
            checkstatus = "Yellow"
            self.error = error
            return
        }

        if task.terminationStatus != 0 {
            status = "Security Responses auto-install setting is not accessible."
            checkstatus = "Yellow"
            return
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if output == "1" || output.lowercased() == "true" {
            status = "Rapid Security Responses and system files will install automatically."
            checkstatus = "Green"
        } else {
            status = "Automatic Security Responses are disabled."
            checkstatus = "Red"
        }
    }
}
