//  ContinuityFeaturesCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class ContinuityFeaturesCheck: SystemCheck {
    init() {
        super.init(
            name: "Check Continuity and iPhone Mirroring Settings",
            description: "Verifies that Handoff advertising/receiving and iPhone Mirroring to this Mac are disabled when required by CIS.",
            category: "CIS Benchmark",
            remediation: "Disable Handoff and iPhone Mirroring in System Settings ▸ General ▸ AirDrop & Handoff.",
            severity: "Medium",
            documentation: "https://support.apple.com/HT204681",
            mitigation: "Disabling Continuity features reduces the attack surface for cross-device lateral movement and shoulder surfing risks.",
            docID: 105
        )
    }

    override func check() {
        let handoffAdvertise = readHostPreference(domain: "com.apple.coreservices.useractivityd", key: "ActivityAdvertisingAllowed")
        let handoffReceive = readHostPreference(domain: "com.apple.coreservices.useractivityd", key: "ActivityReceivingAllowed")
        let iphoneMirroring = readHostPreference(domain: "com.apple.airplay", key: "AllowPairedDeviceToMirrorThisMac")

        if handoffAdvertise == nil || handoffReceive == nil || iphoneMirroring == nil {
            status = "Unable to determine one or more Continuity settings."
            checkstatus = "Yellow"
            return
        }

        let handoffEnabled = (handoffAdvertise == true) || (handoffReceive == true)
        let mirroringEnabled = iphoneMirroring == true

        if !handoffEnabled && !mirroringEnabled {
            status = "Handoff advertising/receiving and iPhone Mirroring are disabled."
            checkstatus = "Green"
        } else {
            var issues: [String] = []
            if handoffEnabled {
                issues.append("Handoff")
            }
            if mirroringEnabled {
                issues.append("iPhone Mirroring")
            }
            status = "Continuity features enabled: \(issues.joined(separator: ", "))."
            checkstatus = "Red"
        }
    }

    private func readHostPreference(domain: String, key: String) -> Bool? {
        guard let value = CFPreferencesCopyValue(key as CFString, domain as CFString, kCFPreferencesCurrentUser, kCFPreferencesCurrentHost) else {
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
