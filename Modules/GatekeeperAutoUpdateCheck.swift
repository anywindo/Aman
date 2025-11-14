//
//  GatekeeperAutoUpdateCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class GatekeeperAutoUpdateCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Gatekeeper Data Auto-Update",
            description: "Ensures Gatekeeper and notarization data files update automatically.",
            category: "Security",
            remediation: "Enable Gatekeeper auto-update in System Settings ▸ Privacy & Security ▸ Security.",
            severity: "Medium",
            documentation: "https://support.apple.com/HT202491",
            mitigation: "Keeping Gatekeeper data current ensures notarization and malware signatures are refreshed frequently.",
            docID: 212
        )
    }

    override func check() {
        guard let prefs = NSDictionary(contentsOfFile: "/Library/Preferences/com.apple.security.plist") as? [String: Any] else {
            status = "Unable to read Gatekeeper preferences."
            checkstatus = "Yellow"
            return
        }

        let autoUpdate = (prefs["GKAutoUpdate"] as? Bool) ?? true
        if autoUpdate {
            status = "Gatekeeper data auto-update is enabled."
            checkstatus = "Green"
        } else {
            status = "Gatekeeper data auto-update is disabled."
            checkstatus = "Red"
        }
    }
}
