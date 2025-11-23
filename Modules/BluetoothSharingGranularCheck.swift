//
//  BluetoothSharingGranularCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class BluetoothSharingGranularCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Bluetooth Sharing Preferences",
            description: "Audits Bluetooth sharing settings such as file transfer and audio device permissions.",
            category: "Continuity",
            remediation: "Disable Bluetooth file sharing and restrict device pairing in System Settings ▸ Bluetooth.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/mac-help/use-bluetooth-devices-mchlpt1030/mac",
            mitigation: "Limiting Bluetooth sharing reduces the risk of unsolicited file transfers and malicious peripherals.",
            docID: 208
        )
    }

    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", "com.apple.BluetoothFileExchange", "PrefBluetoothSharingEnabled"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch let error {
            status = "Unable to query Bluetooth sharing settings: \(error.localizedDescription)"
            checkstatus = "Yellow"
            self.error = error
            return
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if output == "1" || output.lowercased() == "true" {
            status = "Bluetooth file sharing is enabled."
            checkstatus = "Red"
        } else {
            status = "Bluetooth file sharing is disabled."
            checkstatus = "Green"
        }
    }
}
