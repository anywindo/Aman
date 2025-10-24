//  LocationServicesMenuIconCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class LocationServicesMenuIconCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Location Services Icon Visible",
            description: "Ensures the Location Services indicator is shown in the menu bar when active, per CIS guidance.",
            category: "CIS Benchmark",
            remediation: "Set System Settings ▸ Control Centre ▸ Location Services to show in Menu Bar when active.",
            severity: "Low",
            documentation: "https://support.apple.com/guide/mac-help/view-location-service-status-mchl7c2cda1a/mac",
            mitigation: "Displaying the Location Services indicator increases transparency whenever location data is accessed.",
            docID: 108
        )
    }

    override func check() {
        guard let visible = Self.readControlCenterBool(key: "NSStatusItem Visible Location") else {
            status = "Unable to determine Location Services icon visibility."
            checkstatus = "Yellow"
            return
        }

        if visible {
            status = "Location Services icon will appear in the menu bar when active."
            checkstatus = "Green"
        } else {
            status = "Location Services icon is hidden."
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
