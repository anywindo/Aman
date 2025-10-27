//  AdminPasswordForSecureSettingsCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class AdminPasswordForSecureSettingsCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Admin Password Required for Secure Settings",
            description: "Confirms that macOS requires an administrator password before modifying security-critical System Settings panes.",
            category: "CIS Benchmark",
            remediation: "Ensure System Settings ▸ Privacy & Security ▸ Advanced has “Require administrator authorization to access secure settings” enabled.",
            severity: "High",
            documentation: "https://support.apple.com/guide/mac-help/change-advanced-security-settings-mh40617",
            mitigation: "Requiring admin credentials helps control unauthorized modifications to security-sensitive preferences.",
            docID: 103
        )
    }

    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        task.arguments = ["authorizationdb", "read", "system.preferences.security"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch let error {
            print("Error checking secure settings authorization: \(error)")
            status = "Unable to read secure settings authorization policy."
            checkstatus = "Yellow"
            self.error = error
            return
        }

        if task.terminationStatus != 0 {
            status = "Could not determine secure settings authorization."
            checkstatus = "Yellow"
            return
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if output.contains("class = user") || output.contains("shared = 0") {
            status = "Secure settings require administrative authorization."
            checkstatus = "Green"
        } else {
            status = "Secure settings may be changeable without admin credentials."
            checkstatus = "Red"
        }
    }
}
