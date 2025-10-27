//
//  HotCornersDisabledCheck.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

final class HotCornersDisabledCheck: SystemCheck {
    private let cornerKeys = [
        "wvous-bl-corner",
        "wvous-br-corner",
        "wvous-tl-corner",
        "wvous-tr-corner"
    ]

    init() {
        super.init(
            name: "Disable Hot Corners",
            description: "Confirms all Mission Control hot corners are set to “No Action” (value 0) as required by CMMC Level 2.",
            category: "Compliance",
            categories: ["Security"],
            remediation: "Deploy a configuration profile for com.apple.dock that sets each wvous-*-corner key to 0.",
            severity: "Low",
            documentation: "https://support.apple.com/guide/deployment/system-security-settings-depc60232ca0/web",
            mitigation: "Disabling hot corners prevents accidental or unauthorized invocation of screen exposures that could leak sensitive data.",
            docID: 227
        )
    }

    override func check() {
        var missing: [String] = []
        var violations: [String] = []

        for key in cornerKeys {
            guard let value = readDockCorner(key) else {
                missing.append(key)
                continue
            }

            if value != 0 {
                violations.append("\(key)=\(value)")
            }
        }

        if !missing.isEmpty {
            status = "Unable to determine hot corner values for: \(missing.joined(separator: ", "))."
            checkstatus = "Yellow"
            return
        }

        if violations.isEmpty {
            status = "All hot corners are disabled."
            checkstatus = "Green"
        } else {
            status = "Hot corners active: \(violations.joined(separator: ", "))."
            checkstatus = "Red"
        }
    }

    private func readDockCorner(_ key: String) -> Int? {
        if let number = CFPreferencesCopyValue(
            key as CFString,
            "com.apple.dock" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesCurrentHost
        ) as? NSNumber {
            return number.intValue
        }

        if let number = CFPreferencesCopyValue(
            key as CFString,
            "com.apple.dock" as CFString,
            kCFPreferencesCurrentUser,
            kCFPreferencesAnyHost
        ) as? NSNumber {
            return number.intValue
        }

        if let number = CFPreferencesCopyValue(
            key as CFString,
            "com.apple.dock" as CFString,
            kCFPreferencesAnyUser,
            kCFPreferencesCurrentHost
        ) as? NSNumber {
            return number.intValue
        }

        return nil
    }
}
