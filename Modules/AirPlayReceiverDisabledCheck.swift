//
//  AirPlayReceiverDisabledCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//


import Foundation

class AirPlayReceiverDisabledCheck: SystemCheck {
    init() {
        super.init(
            name: "Check AirPlay Receiver Is Disabled",
            description: "AirPlay Receiver allows you to mirror your Mac's screen on other devices, like Apple TV. This check verifies if AirPlay Receiver is disabled.",
            category: "CIS Benchmark",
            remediation: "Disable AirPlay Receiver via System Settings ▸ General ▸ AirDrop & Handoff by turning off 'AirPlay Receiver'.",
            severity: "Medium",
            documentation: "For more information about AirPlay Receiver and how to disable it, visit: https://support.apple.com/guide/mac-help/mirror-the-screen-on-a-mac-with-mirroring-display-preferences-mh14127/mac",
            mitigation: "Disabling AirPlay Receiver reduces the risk of unauthorized access to your computer by preventing unauthorized users from mirroring your Mac's screen on their devices. It is recommended to disable AirPlay Receiver when not in use.",
            checkstatus: "",
            docID: 14
        )
    }

    override func check() {
        let defaultsTask = Process()
        defaultsTask.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        defaultsTask.arguments = ["-currentHost", "read", "com.apple.controlcenter", "AirplayReceiverEnabled"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        defaultsTask.standardOutput = outputPipe
        defaultsTask.standardError = errorPipe

        do {
            try defaultsTask.run()
            defaultsTask.waitUntilExit()

            if defaultsTask.terminationStatus == 0 {
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let value = String(data: outputData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .lowercased() ?? ""

                if value == "1" || value == "true" {
                    status = "AirPlay Receiver is enabled."
                    checkstatus = "Red"
                } else {
                    status = "AirPlay Receiver is disabled."
                    checkstatus = "Green"
                }
                return
            } else {
                let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if stderr.contains("does not exist") || stderr.contains("No such key") {
                    status = "AirPlay Receiver appears to be disabled."
                    checkstatus = "Green"
                    return
                }
            }
        } catch {
            // fall through to process-based detection
        }

        // Fallback: detect helper process as last resort
        let psTask = Process()
        psTask.executableURL = URL(fileURLWithPath: "/bin/ps")
        psTask.arguments = ["axo", "comm"]

        let psPipe = Pipe()
        psTask.standardOutput = psPipe

        do {
            try psTask.run()
            psTask.waitUntilExit()

            let outputData = psPipe.fileHandleForReading.readDataToEndOfFile()
            let helperRunning = String(data: outputData, encoding: .utf8)?
                .contains("AirPlayXPCHelper") ?? false

            if helperRunning {
                status = "AirPlay Receiver helper process is running."
                checkstatus = "Red"
            } else {
                status = "AirPlay Receiver helper is not running."
                checkstatus = "Green"
            }
        } catch let error {
            print("Error checking \(name): \(error)")
            status = "Error checking AirPlay Receiver status."
            checkstatus = "Yellow"
            self.error = error
        }
    }
}
