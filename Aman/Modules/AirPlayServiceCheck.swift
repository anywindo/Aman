//  AirPlayServiceCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class AirPlayServiceCheck: SystemCheck {
    init() {
        super.init(
            name: "Check AirPlay Receiver Services",
            description: "Detects Apple TV/AirPlay services advertising from this Mac when not expected.",
            category: "Continuity",
            remediation: "Disable AirPlay Receiver and screen sharing features in System Settings.",
            severity: "Medium",
            documentation: "https://support.apple.com/HT204289",
            mitigation: "Reducing AirPlay surface prevents unapproved screen mirroring and access to shared displays.",
            docID: 207
        )
    }

    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.controlcenter", "AirplayReceiverEnabled"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch let error {
            status = "Unable to query AirPlay receiver setting: \(error.localizedDescription)"
            checkstatus = "Yellow"
            self.error = error
            return
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if output == "1" || output.lowercased() == "true" {
            status = "AirPlay receiver is enabled on this Mac."
            checkstatus = "Red"
        } else {
            status = "AirPlay receiver is disabled."
            checkstatus = "Green"
        }
    }
}
