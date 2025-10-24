//
//  PasswordCustomRegexRequirementCheck.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

final class PasswordCustomRegexRequirementCheck: SystemCheck {
    init() {
        super.init(
            name: "Require Custom Password Regex",
            description: "Confirms the password policy enforces a custom regular expression (e.g., mixed case and numeric) per CMMC Level 2 guidance.",
            category: "Compliance",
            categories: ["Accounts", "Security"],
            remediation: "Deploy a password policy profile (com.apple.mobiledevice.passwordpolicy) defining customRegex/passwordContentRegex to match your organization’s requirements.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Custom regex enforcement provides fine-grained control over password composition to meet regulatory requirements.",
            docID: 224
        )
    }

    override func check() {
        guard let xml = PasswordPolicyInspector.loadPolicyXML() else {
            status = "Unable to read password policy XML."
            checkstatus = "Yellow"
            return
        }

        let matchesRegex = xml.contains("passwordContentRegex") || xml.contains("customRegex")
        let hasExamplePattern = xml.contains("(?=.*[A-Z])") && xml.contains("(?=.*[a-z])") && xml.contains("(?=.*[0-9])")

        if matchesRegex || hasExamplePattern {
            status = "Password policy includes a custom regex requirement."
            checkstatus = "Green"
        } else {
            status = "No custom regex enforcement detected in the password policy."
            checkstatus = "Red"
        }
    }
}
