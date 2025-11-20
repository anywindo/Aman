//
//  PasswordAlphanumericRequirementCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

final class PasswordAlphanumericRequirementCheck: SystemCheck {
    init() {
        super.init(
            name: "Require Alphanumeric Passwords",
            description: "Ensures account policies require at least one numeric character in user passwords.",
            category: "Compliance",
            categories: ["Accounts", "Security"],
            remediation: "Deploy a password policy profile (com.apple.mobiledevice.passwordpolicy) setting requireAlphanumeric = true.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Enforcing alphanumeric passwords raises the bar against credential guessing and satisfies CMMC Level 2 requirements.",
            docID: 223
        )
    }

    override func check() {
        guard
            let plist = PasswordPolicyInspector.loadPolicyPlist() as? [String: Any],
            let content = plist["policyCategoryPasswordContent"] as? [[String: Any]]
        else {
            status = "Unable to load password policy content."
            checkstatus = "Yellow"
            return
        }

        let identifiers = content.compactMap { $0["policyIdentifier"] as? String }
        let hasRequirement = identifiers.contains { $0.caseInsensitiveCompare("requireAlphanumeric") == .orderedSame }

        if hasRequirement {
            status = "Password policy requires alphanumeric characters."
            checkstatus = "Green"
        } else {
            status = "Password policy does not enforce alphanumeric characters."
            checkstatus = "Red"
        }
    }
}
