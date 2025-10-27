//
//  FirewallStealthModeCheck.swift
//  Aman
//
//  Created by Samet Sazak
//

//Tested in 13-inch, 2020, Four Thunderbolt 3 ports 13.2.1 (22D68)

import Foundation

class FirewallStealthModeCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Firewall Stealth Mode Is Enabled",
            description: "Firewall Stealth Mode makes your computer less visible on public networks by ignoring incoming requests. This check verifies if Firewall Stealth Mode is enabled.",
            category: "CIS Benchmark",
            remediation: "Enable firewall stealth mode via System Settings ▸ Network ▸ Firewall ▸ Options… and turn on ‘Enable stealth mode’.",
            severity: "Medium",
            documentation: "For more information about Firewall Stealth Mode and how to enable it, visit: https://support.apple.com/guide/mac-help/use-stealth-mode-to-secure-your-mac-mh17131/mac",
            mitigation: "Enabling Firewall Stealth Mode helps prevent unauthorized access to your computer by making it less visible on public networks. It is recommended to enable Stealth Mode, especially when connected to untrusted networks.",
            checkstatus: "",
            docID: 12
        )
    }

    override func check() {
        var isEnabled: Bool?

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/libexec/ApplicationFirewall/socketfilterfw")
        task.arguments = ["--getstealthmode"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()

            if task.terminationStatus == 0 {
                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.lowercased() ?? ""
                if output.contains("enabled") || output.contains("state = 1") {
                    isEnabled = true
                } else if output.contains("disabled") || output.contains("state = 0") {
                    isEnabled = false
                }
            }
        } catch {
            // ignore, fall back below
        }

        if isEnabled == nil {
            let fallback = Process()
            fallback.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
            fallback.arguments = ["read", "/Library/Preferences/com.apple.alf", "stealthenabled"]

            let pipe = Pipe()
            fallback.standardOutput = pipe
            fallback.standardError = pipe

            do {
                try fallback.run()
                fallback.waitUntilExit()

                if fallback.terminationStatus == 0 {
                    let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
                    if output == "1" || output == "true" {
                        isEnabled = true
                    } else if output == "0" || output == "false" {
                        isEnabled = false
                    }
                }
            } catch {
                // ignore
            }
        }

        if let enabled = isEnabled {
            if enabled {
                status = "Firewall stealth mode is enabled."
                checkstatus = "Green"
            } else {
                status = "Firewall stealth mode is disabled."
                checkstatus = "Red"
            }
        } else {
            status = "Unable to determine stealth mode state without administrator privileges."
            checkstatus = "Yellow"
        }
    }
}
