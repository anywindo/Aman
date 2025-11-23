//
//  CriticalUpdateInstallCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class CriticalUpdateInstallCheck: SystemCheck {
    init() {
        super.init(
            name: "Check 'Install system data files and security updates' Is Enabled",
            description: "Check if 'Install system data files and security updates' is enabled in the Software Update preferences",
            category: "CIS Benchmark",
            remediation: "Enable 'Install system data files and security updates' in the Software Update preferences",
            severity: "Medium",
            documentation: "https://support.apple.com/en-us/HT202180",
            mitigation: "Enabling the installation of system data files and security updates helps ensure that critical updates are installed in a timely manner.",
            docID: 12
        )
    }

    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "/Library/Preferences/com.apple.SoftwareUpdate", "CriticalUpdateInstall"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe

        do {
            try task.run()
            task.waitUntilExit()

            let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

            if output.lowercased() == "1" {
                status = "'Install system data files and security updates' is enabled"
                checkstatus = "Green"
            } else {
                status = "'Install system data files and security updates' is not enabled"
                checkstatus = "Red"
            }
        } catch let e {
            print("Error checking \(name): \(e)")
            checkstatus = "Yellow"
            status = "Error checking critical update install status"
            self.error = e
        }
    }
}
