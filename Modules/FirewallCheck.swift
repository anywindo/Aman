//
//  FirewallCheck.swift
//  Aman
//
//  Created by Samet Sazak
//

//Tested in 13-inch, 2020, Four Thunderbolt 3 ports 13.2.1 (22D68)

import Foundation

class FirewallCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Firewall Status",
            description: "The firewall helps protect your device from unauthorized access. This check verifies if the firewall is enabled and configured correctly.",
            category: "CIS Benchmark",
            remediation: "Enable and configure the firewall from System Settings ▸ Network ▸ Firewall, then choose Options… to review trusted services.",
            severity: "High",
            documentation: "For more information on configuring your firewall, visit: https://support.apple.com/en-us/HT201642",
            mitigation: "Enabling and configuring the firewall helps prevent unauthorized access to your device and increases overall security. A properly configured firewall can block incoming connections and minimize the risk of unauthorized access.",
            checkstatus: "",
            docID: 5
        )
    }
    
    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/libexec/ApplicationFirewall/socketfilterfw")
        task.arguments = ["--getglobalstate"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe
        
        do {
            try task.run()
            task.waitUntilExit()
            
            guard task.terminationStatus == 0 else {
                status = "Unable to determine firewall state."
                checkstatus = "Yellow"
                return
            }
            
            let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .lowercased() ?? ""
            
            if output.contains("state = 1") || output.contains("state = 2") || output.contains("enabled") {
                status = "Firewall is enabled."
                checkstatus = "Green"
            } else {
                status = "Firewall is not enabled."
                checkstatus = "Red"
            }
        } catch let e {
            print("Error checking \(name): \(e)")
            self.error = e
            status = "Error checking firewall state."
            checkstatus = "Yellow"
        }
    }
}
