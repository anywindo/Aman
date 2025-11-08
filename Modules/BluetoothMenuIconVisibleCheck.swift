//
//  BluetoothMenuIconVisibleCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class BluetoothMenuIconVisibleCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Bluetooth Status Icon Visible",
            description: "Ensures the Bluetooth status icon is shown in the menu bar or Control Centre per CIS guidance.",
            category: "CIS Benchmark",
            remediation: "Set System Settings ▸ Control Centre ▸ Bluetooth to show in Menu Bar and Control Centre.",
            severity: "Low",
            documentation: "https://support.apple.com/guide/mac-help/use-bluetooth-devices-mchlpt1030/mac",
            mitigation: "Displaying Bluetooth status helps users monitor active connections and detect unexpected accessories.",
            docID: 107
        )
    }

    override func check() {
        guard let visible = Self.readControlCenterBool(key: "NSStatusItem Visible Bluetooth") else {
            status = "Unable to determine Bluetooth menu icon visibility."
            checkstatus = "Yellow"
            return
        }

        if visible {
            status = "Bluetooth status icon is displayed."
            checkstatus = "Green"
        } else {
            status = "Bluetooth status icon is hidden."
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
