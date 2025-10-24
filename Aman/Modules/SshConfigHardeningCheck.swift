//  SshConfigHardeningCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class SshConfigHardeningCheck: SystemCheck {
    init() {
        super.init(
            name: "Check SSH Configuration Hardening",
            description: "Inspects sshd_config for insecure overrides when Remote Login is disabled.",
            category: "Security",
            remediation: "Review /etc/ssh/sshd_config and remove overrides that weaken the default macOS sshd security.",
            severity: "Medium",
            documentation: "https://support.apple.com/HT209600",
            mitigation: "Ensuring SSH keeps default restrictions reduces the risk of unauthorized remote access.",
            docID: 203
        )
    }

    override func check() {
        let configPath = "/etc/ssh/sshd_config"
        guard let contents = try? String(contentsOfFile: configPath, encoding: .utf8) else {
            status = "Unable to read \(configPath)."
            checkstatus = "Yellow"
            return
        }

        let insecureDirectives = [
            "PermitRootLogin yes",
            "PermitEmptyPasswords yes",
            "PasswordAuthentication yes"
        ]

        let lower = contents.lowercased()
        let findings = insecureDirectives.filter { lower.contains($0.lowercased()) }

        if findings.isEmpty {
            status = "sshd_config does not contain insecure overrides."
            checkstatus = "Green"
        } else {
            status = "Insecure SSH directives detected: \(findings.joined(separator: ", "))."
            checkstatus = "Red"
        }
    }
}
