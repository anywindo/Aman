//  FirmwareSecurityCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class FirmwareSecurityCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Firmware Security",
            description: "Verifies secure boot policy and reports whether Apple T2/Secure Enclave protections are active.",
            category: "Security",
            remediation: "Use Startup Security Utility to enforce full security, enable secure boot, and require admin password for external media.",
            severity: "High",
            documentation: "https://support.apple.com/HT208330",
            mitigation: "Ensuring Secure Boot and hardware protections prevents tampered boot media or altered firmware from compromising the Mac.",
            docID: 202
        )
    }

    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/csrutil")
        task.arguments = ["authenticated-root", "status"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch let error {
            status = "Unable to query firmware security: \(error.localizedDescription)"
            checkstatus = "Yellow"
            self.error = error
            return
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.lowercased() ?? ""
        if output.contains("enabled") {
            status = "Authenticated Root (full secure boot) is enabled."
            checkstatus = "Green"
        } else if output.contains("disabled") {
            status = "Authenticated Root appears disabled."
            checkstatus = "Red"
        } else {
            status = "Unable to determine secure boot status."
            checkstatus = "Yellow"
        }
    }
}
