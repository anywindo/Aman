//
//  PasswordSimpleSequenceRestrictionCheck.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

final class PasswordSimpleSequenceRestrictionCheck: SystemCheck {
    init() {
        super.init(
            name: "Disallow Simple Password Sequences",
            description: "Checks whether the password policy prohibits simple repeating/ascending/descending sequences (allowSimple = false).",
            category: "Compliance",
            categories: ["Accounts", "Security"],
            remediation: "Deploy a password policy profile (com.apple.mobiledevice.passwordpolicy) setting allowSimple = false.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Blocking simple sequences stops users from selecting easily guessable passwords, aligning with CMMC Level 2 requirements.",
            docID: 225
        )
    }

    override func check() {
        guard let plist = PasswordPolicyInspector.loadPolicyPlist() else {
            status = "Unable to load password policy information."
            checkstatus = "Yellow"
            return
        }

        let values = collectValues(forKey: "allowSimple", in: plist)
        guard !values.isEmpty else {
            status = "Password policy does not define allowSimple."
            checkstatus = "Red"
            return
        }

        let containsFalse = values.contains { value in
            if let boolValue = value as? Bool {
                return boolValue == false
            }
            if let numberValue = value as? NSNumber {
                return numberValue.boolValue == false
            }
            if let stringValue = value as? String {
                return stringValue == "0" || stringValue.caseInsensitiveCompare("false") == .orderedSame
            }
            return false
        }

        if containsFalse {
            status = "Simple password sequences are disallowed."
            checkstatus = "Green"
        } else {
            status = "Password policy still permits simple sequences (allowSimple not false)."
            checkstatus = "Red"
        }
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
