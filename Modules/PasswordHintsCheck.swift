//
//  PasswordHintsCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class PasswordHintsCheck: SystemCheck {
    init() {
        super.init(
            name: "Check 'Show Password Hints' Status",
            description: "This check verifies if the 'Show password hints' option is disabled on your system, which helps protect against unauthorized access to your computer.",
            category: "Security",
            remediation: "To disable password hints, open System Settings ▸ Users & Groups ▸ Login Options and turn off ‘Show password hints’.",
            severity: "Medium",
            documentation: "For more information on disabling 'Show password hints', visit: https://support.apple.com/guide/mac-help/change-password-preferences-mchlp2818/mac",
            mitigation: "By disabling 'Show password hints', you reduce the risk of unauthorized access to your computer, enhancing its security.",
            docID: 30
        )
    }

    override func check() {
        switch readOptionalInteger(domain: "/Library/Preferences/com.apple.loginwindow", key: "RetriesUntilHint") {
        case .some(let value) where value > 0:
            status = "Password hint is shown after \(value) failed attempts."
            checkstatus = "Red"
        case .some, .none:
            status = "Password hint is disabled."
            checkstatus = "Green"
        }
    }

    private func readOptionalInteger(domain: String, key: String) -> Int? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", domain, key]

        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        if task.terminationStatus != 0 {
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if errorOutput.contains("does not exist") || errorOutput.contains("The domain/default pair") {
                return nil
            }
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return Int(trimmed)
    }
}
