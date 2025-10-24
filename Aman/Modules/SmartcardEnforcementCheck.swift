//
//  SmartcardEnforcementCheck.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

final class SmartcardEnforcementCheck: SystemCheck {
    init() {
        super.init(
            name: "Enforce Smartcard Authentication",
            description: "Confirms that smartcard authentication is enforced (password-only logins are blocked) per CMMC guidance.",
            category: "Compliance",
            categories: ["Accounts"],
            remediation: "Deploy a configuration profile with payload identifier com.apple.security.smartcard setting enforceSmartCard = true and allowSmartCard = true.",
            severity: "High",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Enforcing smartcard authentication ensures only multi-factor credentials are accepted for console and screen unlock logins.",
            docID: 218
        )
    }

    override func check() {
        let allow = readSmartcardFlag("allowSmartCard")
        let enforce = readSmartcardFlag("enforceSmartCard")

        guard let allowValue = allow else {
            status = "Smartcard allowance is not configured; unable to confirm enforcement."
            checkstatus = "Yellow"
            return
        }

        guard allowValue else {
            status = "Smartcard authentication is not allowed, so enforcement cannot apply."
            checkstatus = "Red"
            return
        }

        switch enforce {
        case .some(true):
            status = "Smartcard authentication is enforced for local logins."
            checkstatus = "Green"
        case .some(false):
            status = "Smartcard authentication is allowed but not enforced."
            checkstatus = "Red"
        case .none:
            status = "Smartcard enforcement is not configured."
            checkstatus = "Yellow"
        }
    }

    private func readSmartcardFlag(_ key: String) -> Bool? {
        guard let value = CFPreferencesCopyValue(
            key as CFString,
            "com.apple.security.smartcard" as CFString,
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
