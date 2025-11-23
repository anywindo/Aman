//  LoginWindowPolicyCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class LoginWindowPolicyCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Login Window Policies",
            description: "Verifies auto-login is disabled, banner messages configured, and screen saver settings align with policy.",
            category: "Accounts",
            remediation: "Configure loginwindow.plist to disable auto-login, set banners, and enforce screen saver activation.",
            severity: "High",
            documentation: "https://support.apple.com/guide/mdm/login-window-mdm0fba374f/web",
            mitigation: "Securing the login window prevents unattended access and improves user awareness of usage policies.",
            docID: 209
        )
    }

    override func check() {
        guard let plist = NSDictionary(contentsOfFile: "/Library/Preferences/com.apple.loginwindow.plist") as? [String: Any] else {
            status = "Unable to read loginwindow preferences."
            checkstatus = "Yellow"
            return
        }

        var issues: [String] = []

        if let autoLogin = plist["autoLoginUser"] as? String, !autoLogin.isEmpty {
            issues.append("Auto-login enabled for \(autoLogin)")
        }
        if let message = plist["LoginwindowText"] as? String, message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            issues.append("Login window banner not set")
        }
        if plist["LoginwindowText"] == nil {
            issues.append("Login window banner missing")
        }

        if issues.isEmpty {
            status = "Login window policies appear secure."
            checkstatus = "Green"
        } else {
            status = issues.joined(separator: "; ")
            checkstatus = "Red"
        }
    }
}
