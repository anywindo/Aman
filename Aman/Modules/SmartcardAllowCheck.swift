//
//  SmartcardAllowCheck.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

final class SmartcardAllowCheck: SystemCheck {
    init() {
        super.init(
            name: "Allow Smartcard Authentication",
            description: "Verifies that macOS is configured to permit smartcard authentication according to CMMC guidance.",
            category: "Compliance",
            categories: ["Accounts"],
            remediation: "Deploy a configuration profile with payload identifier com.apple.security.smartcard setting allowSmartCard = true.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Allowing smartcard authentication enables organizations to meet strong authentication requirements when accompanied by supporting policies.",
            docID: 217
        )
    }

    override func check() {
        let value = readSmartcardFlag("allowSmartCard")

        switch value {
        case .some(true):
            status = "Smartcard authentication is allowed on this Mac."
            checkstatus = "Green"
        case .some(false):
            status = "Smartcard authentication is explicitly disallowed."
            checkstatus = "Red"
        case .none:
            status = "Smartcard allowance is not configured (defaults vary by OS version)."
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
