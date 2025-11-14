//
//  LocationServicesCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class LocationServicesCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Location Services Is Enabled",
            description: "Location Services is essential for various applications on your system to function properly. This check ensures that Location Services is enabled on your system.",
            category: "Privacy",
            remediation: "Enable Location Services via System Settings ▸ Privacy & Security ▸ Location Services.",
            severity: "Low",
            documentation: "This code checks the status of the com.apple.locationd launchctl service. If the locationd service is running, it means that Location Services is enabled; if not, it means that Location Services is disabled.",
            mitigation: "Enabling Location Services allows applications to provide location-based features and services.",
            docID: 50
        )
    }

    override func check() {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["-currentHost", "read", "com.apple.locationd", "LocationServicesEnabled"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let outputString = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

                if outputString == "1" || outputString == "true" {
                    status = "Location Services is Enabled"
                    checkstatus = "Green"
                } else {
                    status = "Location Services is Disabled"
                    checkstatus = "Red"
                }
            } else {
                status = "Unable to query Location Services without administrator privileges."
                checkstatus = "Yellow"
            }
        } catch let e {
            print("Error checking \(name): \(e)")
            checkstatus = "Yellow"
            status = "Error checking Location Services status"
            self.error = e
        }
    }
}
