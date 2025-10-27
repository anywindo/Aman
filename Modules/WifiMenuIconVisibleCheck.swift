//  WifiMenuIconVisibleCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class WifiMenuIconVisibleCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Wi-Fi Status Icon Visible",
            description: "Ensures the Wi-Fi status icon is shown in the menu bar or Control Centre per CIS guidance.",
            category: "CIS Benchmark",
            remediation: "Set System Settings ▸ Control Centre ▸ Wi-Fi to show in Menu Bar and Control Centre.",
            severity: "Low",
            documentation: "https://support.apple.com/guide/mac-help/use-the-wi-fi-status-menu-mchlp1540/mac",
            mitigation: "Displaying Wi-Fi status helps users quickly inspect their network connection and detect unexpected changes.",
            docID: 106
        )
    }

    override func check() {
        guard let visible = Self.readControlCenterBool(key: "NSStatusItem Visible WiFi") else {
            status = "Unable to determine Wi-Fi menu icon visibility."
            checkstatus = "Yellow"
            return
        }

        if visible {
            status = "Wi-Fi status icon is displayed."
            checkstatus = "Green"
        } else {
            status = "Wi-Fi status icon is hidden."
            checkstatus = "Red"
        }
    }

    private static func readControlCenterBool(key: String) -> Bool? {
        guard let value = CFPreferencesCopyValue(key as CFString, "com.apple.controlcenter" as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) else {
            return nil
        }
        if let boolValue = value as? Bool {
            return boolValue
        }
        if let number = value as? NSNumber {
            return number.boolValue
        }
        return nil
    }
}
