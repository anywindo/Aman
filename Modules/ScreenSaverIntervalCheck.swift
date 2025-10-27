//
//  ScreenSaverIntervalCheck.swift
//  Aman
//
//  Created by Samet Sazak
//


import Foundation

class ScreenSaverInactivityCheck: SystemCheck {

    init() {
        super.init(
            name: "Check an Inactivity Interval of 20 Minutes or Less for the Screen Saver Is Enabled",
            description: "This checks if the computer screen saver activates within 20 minutes of inactivity. A shorter inactivity period helps protect your computer from unauthorized access.",
            category: "CIS Benchmark",
            remediation: "Set the screen saver inactivity interval to 20 minutes or less.",
            severity: "Low",
            documentation: "A longer inactivity interval increases the risk of unauthorized access to a user's system and potentially sensitive data. This code checks if the screen saver activates within 20 minutes of inactivity.",
            mitigation: "Set the screen saver inactivity interval to 20 minutes or less to minimize the risk of unauthorized access.",
            docID: 57
        )
    }

    override func check() {
        let task = Process()
        task.launchPath = "/usr/bin/defaults"
        task.arguments = ["-currentHost", "read", "com.apple.screensaver", "idleTime"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            guard task.terminationStatus == 0, let output = String(data: data, encoding: .utf8) else {
                status = "Error checking screen saver inactivity interval"
                checkstatus = "Yellow"
                return
            }

            if let value = Int(output.trimmingCharacters(in: .whitespacesAndNewlines)) {
                if value > 0 && value <= 1200 {
                    status = "Screen saver activates within 20 minutes of inactivity."
                    checkstatus = "Green"
                } else {
                    status = "Screen saver is configured to wait longer than 20 minutes (or is disabled)."
                    checkstatus = "Red"
                }
            } else {
                status = "Error parsing screen saver interval."
                checkstatus = "Yellow"
            }
        } catch let e {
            print("Error checking \(name): \(e)")
            checkstatus = "Yellow"
            status = "Error checking screen saver inactivity interval"
            self.error = e
        }
    }
}
