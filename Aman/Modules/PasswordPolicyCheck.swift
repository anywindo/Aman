//  PasswordPolicyCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class PasswordPolicyCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Local Password Policy",
            description: "Runs pwpolicy to audit minimum length, complexity, and history settings for local accounts.",
            category: "Security",
            remediation: "Apply a configuration profile or pwpolicy command that enforces CIS-aligned complexity requirements.",
            severity: "High",
            documentation: "https://support.apple.com/guide/mdm/pwpolicy-command-mdm0f879fb4/web",
            mitigation: "Strong password policies reduce successful brute-force attempts and reuse of weak credentials.",
            docID: 204
        )
    }

    override func check() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pwpolicy")
        task.arguments = ["getaccountpolicies"]

        let outputPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = outputPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch let error {
            status = "Unable to query password policy: \(error.localizedDescription)"
            checkstatus = "Yellow"
            self.error = error
            return
        }

        if task.terminationStatus != 0 {
            status = "pwpolicy exited with status \(task.terminationStatus)."
            checkstatus = "Yellow"
            return
        }

        let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        if output.isEmpty {
            status = "No explicit password policy detected."
            checkstatus = "Red"
            return
        }

        status = "Password policy retrieved. Review for compliance:\n" + output
        checkstatus = output.contains("minLength") ? "Green" : "Yellow"
    }
}
