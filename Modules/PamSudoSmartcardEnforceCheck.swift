//
//  PamSudoSmartcardEnforceCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

final class PamSudoSmartcardEnforceCheck: SystemCheck {
    init() {
        super.init(
            name: "Enforce Smartcard for sudo Command",
            description: "Checks /etc/pam.d/sudo to ensure smartcard factors are required before sudo elevation.",
            category: "Compliance",
            categories: ["Accounts", "Security"],
            remediation: """
Replace /etc/pam.d/sudo with a PAM policy that includes:
auth        sufficient    pam_smartcard.so
auth        required      pam_deny.so
""",
            severity: "High",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Requiring smartcards for sudo makes privilege escalation contingent on multifactor authentication.",
            docID: 222
        )
    }

    override func check() {
        guard let contents = try? String(contentsOfFile: "/etc/pam.d/sudo", encoding: .utf8) else {
            status = "Unable to read /etc/pam.d/sudo."
            checkstatus = "Yellow"
            return
        }

        let normalized = contents
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("#") }

        let hasSmartcard = normalized.contains { $0.range(of: #"auth\s+sufficient\s+pam_smartcard\.so"#, options: [.regularExpression, .caseInsensitive]) != nil }
        let hasDeny = normalized.contains { $0.range(of: #"auth\s+required\s+pam_deny\.so"#, options: [.regularExpression, .caseInsensitive]) != nil }

        if hasSmartcard && hasDeny {
            status = "PAM sudo policy requires smartcard authentication."
            checkstatus = "Green"
        } else if !hasSmartcard && !hasDeny {
            status = "PAM sudo policy lacks smartcard and deny safeguards."
            checkstatus = "Red"
        } else if !hasSmartcard {
            status = "PAM sudo policy missing pam_smartcard.so entry."
            checkstatus = "Red"
        } else {
            status = "PAM sudo policy missing pam_deny.so entry."
            checkstatus = "Red"
        }
    }
}
