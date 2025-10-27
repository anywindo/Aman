//  AppTrackingTransparencyCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class AppTrackingTransparencyCheck: SystemCheck {
    init() {
        super.init(
            name: "Check App Tracking Transparency Setting",
            description: "Verifies that system-wide tracking is disabled unless explicitly required.",
            category: "Privacy",
            remediation: "Set System Settings ▸ Privacy & Security ▸ Tracking to disallow app requests.",
            severity: "Medium",
            documentation: "https://support.apple.com/HT212025",
            mitigation: "Disallowing tracking requests prevents apps from profiling users across apps and websites.",
            docID: 211
        )
    }

    override func check() {
        guard let value = CFPreferencesCopyValue("allowTracking" as CFString, "com.apple.AdLib" as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) else {
            status = "Unable to determine App Tracking Transparency preference."
            checkstatus = "Yellow"
            return
        }

        let allowed: Bool
        if let boolValue = value as? Bool {
            allowed = boolValue
        } else if let number = value as? NSNumber {
            allowed = number.boolValue
        } else {
            status = "Unexpected value type for App Tracking setting."
            checkstatus = "Yellow"
            return
        }

        if allowed {
            status = "Apps are allowed to request to track."
            checkstatus = "Red"
        } else {
            status = "Apps are blocked from requesting tracking."
            checkstatus = "Green"
        }
    }
}
