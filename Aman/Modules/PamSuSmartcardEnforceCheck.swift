//
//  PamSuSmartcardEnforceCheck.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

final class PamSuSmartcardEnforceCheck: SystemCheck {
    init() {
        super.init(
            name: "Enforce Smartcard for su Command",
            description: "Verifies that the /etc/pam.d/su policy requires smartcard authentication before permitting su escalation.",
            category: "Compliance",
            categories: ["Accounts", "Security"],
            remediation: """
Replace /etc/pam.d/su with a PAM policy that includes:
auth        sufficient    pam_smartcard.so
auth        required      pam_rootok.so
""",
            severity: "High",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Requiring smartcards for su ties privileged escalation to multifactor authentication, reducing credential theft risk.",
            docID: 221
        )
    }

    override func check() {
        guard let contents = try? String(contentsOfFile: "/etc/pam.d/su", encoding: .utf8) else {
            status = "Unable to read /etc/pam.d/su."
            checkstatus = "Yellow"
            return
        }

        let normalized = contents
            .split(separator: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.hasPrefix("#") }

        let hasSmartcard = normalized.contains { $0.range(of: #"auth\s+sufficient\s+pam_smartcard\.so"#, options: [.regularExpression, .caseInsensitive]) != nil }
        let hasRootok = normalized.contains { $0.range(of: #"auth\s+required\s+pam_rootok\.so"#, options: [.regularExpression, .caseInsensitive]) != nil }

        if hasSmartcard && hasRootok {
            status = "PAM su policy requires smartcard authentication."
            checkstatus = "Green"
        } else if !hasSmartcard && !hasRootok {
            status = "PAM su policy lacks smartcard and rootok requirements."
            checkstatus = "Red"
        } else if !hasSmartcard {
            status = "PAM su policy missing pam_smartcard.so entry."
            checkstatus = "Red"
        } else {
            status = "PAM su policy missing pam_rootok.so entry."
            checkstatus = "Red"
        }
    }
}
