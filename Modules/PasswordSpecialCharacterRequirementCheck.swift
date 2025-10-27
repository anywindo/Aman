//
//  PasswordSpecialCharacterRequirementCheck.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

final class PasswordSpecialCharacterRequirementCheck: SystemCheck {
    init() {
        super.init(
            name: "Require Password Special Characters",
            description: "Checks whether the password policy enforces at least one special character (minComplexChars ≥ 1 or equivalent regex).",
            category: "Compliance",
            categories: ["Accounts", "Security"],
            remediation: "Deploy a password policy profile (com.apple.mobiledevice.passwordpolicy) setting minComplexChars = 1 (or an equivalent custom regex).",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Requiring special characters strengthens passwords and fulfils CMMC Level 2 composition rules.",
            docID: 226
        )
    }

    override func check() {
        guard let plist = PasswordPolicyInspector.loadPolicyPlist() else {
            status = "Unable to load password policy information."
            checkstatus = "Yellow"
            return
        }

        let complexValues = collectValues(forKey: "minComplexChars", in: plist)
        if complexValues.contains(where: valueIndicatesComplexChars(_:)) {
            status = "Password policy requires special characters."
            checkstatus = "Green"
            return
        }

        if let xml = PasswordPolicyInspector.loadPolicyXML(),
           xml.range(of: "[^a-zA-Z0-9]") != nil && xml.contains("policyAttributePassword matches") {
            status = "Password policy enforces special characters via custom regex."
            checkstatus = "Green"
            return
        }

        status = "No special-character requirement detected in the password policy."
        checkstatus = "Red"
    }

    private func valueIndicatesComplexChars(_ value: Any) -> Bool {
        if let numberValue = value as? NSNumber {
            return numberValue.intValue >= 1
        }
        if let stringValue = value as? String, let intValue = Int(stringValue) {
            return intValue >= 1
        }
        return false
    }

    private func collectValues(forKey key: String, in object: Any) -> [Any] {
        var results: [Any] = []
        if let dict = object as? [String: Any] {
            for (k, v) in dict {
                if k == key {
                    results.append(v)
                }
                results.append(contentsOf: collectValues(forKey: key, in: v))
            }
        } else if let array = object as? [Any] {
            for item in array {
                results.append(contentsOf: collectValues(forKey: key, in: item))
            }
        }
        return results
    }
}
