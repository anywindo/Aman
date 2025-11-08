//
//  TemporaryGuestSessionCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class TemporaryGuestSessionCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Temporary Guest Sessions",
            description: "Detects whether macOS temporary guest sessions are allowed, which can bypass persistent account controls.",
            category: "Accounts",
            remediation: "Disable temporary guest sessions via configuration profile or by turning off 'Allow guests to log in to this computer'.",
            severity: "Medium",
            documentation: "https://support.apple.com/HT208857",
            mitigation: "Restricting temporary sessions ensures device enrollment policies and audit logging remain intact.",
            docID: 205
        )
    }

    override func check() {
        guard let loginPrefs = NSDictionary(contentsOfFile: "/Library/Preferences/com.apple.loginwindow.plist") as? [String: Any] else {
            status = "Unable to read loginwindow preferences."
            checkstatus = "Yellow"
            return
        }

        let temporarySession = (loginPrefs["TemporarySession"] as? Bool) ?? false
        if temporarySession {
            status = "Temporary guest sessions are enabled."
            checkstatus = "Red"
        } else {
            status = "Temporary guest sessions are disabled."
            checkstatus = "Green"
        }
    }
}
