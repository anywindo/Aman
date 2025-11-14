//
//  ExternalIntelligenceSignInDisableCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

final class ExternalIntelligenceSignInDisableCheck: SystemCheck {
    init() {
        super.init(
            name: "Disable External Intelligence Integration Sign In",
            description: "Verifies that sign-in to External Intelligence integrations is disabled per CMMC control requirements.",
            category: "Compliance",
            categories: ["Security"],
            remediation: "Deploy a configuration profile with payload identifier com.apple.applicationaccess setting allowExternalIntelligenceIntegrationsSignIn = false.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Blocking sign-in prevents users from connecting Apple Intelligence or third-party AI features when organizational policy forbids it.",
            docID: 220
        )
    }

    override func check() {
        switch readRestrictionFlag("allowExternalIntelligenceIntegrationsSignIn") {
        case .some(false):
            status = "External Intelligence integration sign-in is disabled."
            checkstatus = "Green"
        case .some(true):
            status = "External Intelligence integration sign-in is currently allowed."
            checkstatus = "Red"
        case .none:
            status = "External Intelligence integration sign-in setting is not configured."
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
