//
//  CheckAuditDisEnabled.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//


import Foundation


class SecurityAuditingCheck: SystemCheck {

    init() {
        super.init(
            name: "Check Security Auditing Is Enabled",
            description: "This checks if security auditing is enabled on your computer. Security auditing helps detect unauthorized access and protect sensitive data.",
            category: "CIS Benchmark",
            remediation: "Enable security auditing.",
            severity: "Low",
            documentation: "Security auditing helps detect unauthorized access to a user's system and sensitive data. This code checks if the com.apple.auditd service is running, which indicates security auditing is enabled.",
            mitigation: "Enable security auditing to ensure security events are logged and monitored.",
            docID: 59
        )
    }

    override func check() {
        let task = Process()
        task.launchPath = "/bin/launchctl"
        task.arguments = ["list", "com.apple.auditd"]
        
        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
            
            if task.terminationStatus == 0 {
                status = "Security auditing is enabled."
                checkstatus = "Green"
            } else {
                let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if stderr.contains("Could not find service") || stderr.contains("No such service") {
                    status = "Security auditing service is not available on this system."
                    checkstatus = "Yellow"
                } else {
                    status = "Security auditing is not enabled."
                    checkstatus = "Red"
                }
            }
        } catch let e {
            print("Error checking \(name): \(e)")
            checkstatus = "Yellow"
            status = "Error checking security auditing status."
            self.error = e
        }
    }
}
