//
//  ExternalIntelligenceDisableCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

final class ExternalIntelligenceDisableCheck: SystemCheck {
    init() {
        super.init(
            name: "Disable External Intelligence Integrations",
            description: "Ensures External Intelligence integrations within System Settings are disabled in accordance with CMMC requirements.",
            category: "Compliance",
            categories: ["Security"],
            remediation: "Deploy a configuration profile with payload identifier com.apple.applicationaccess setting allowExternalIntelligenceIntegrations = false.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Disabling External Intelligence integrations prevents unapproved data flows to third-party AI services.",
            docID: 219
        )
    }

    override func check() {
        switch readRestrictionFlag("allowExternalIntelligenceIntegrations") {
        case .some(false):
            status = "External Intelligence integrations are disabled."
            checkstatus = "Green"
        case .some(true):
            status = "External Intelligence integrations are currently enabled."
            checkstatus = "Red"
        case .none:
            status = "External Intelligence integration setting is not configured."
            checkstatus = "Yellow"
        }
    }

    private func readRestrictionFlag(_ key: String) -> Bool? {
        guard let value = CFPreferencesCopyValue(
            key as CFString,
            "com.apple.applicationaccess" as CFString,
            kCFPreferencesAnyUser,
            kCFPreferencesCurrentHost
        ) else {
            return nil
        }

        if let boolValue = value as? Bool {
            return boolValue
        }

        if let numberValue = value as? NSNumber {
            return numberValue.boolValue
        }

        return nil
    }
}
