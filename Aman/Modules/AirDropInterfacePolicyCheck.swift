//  AirDropInterfacePolicyCheck.swift
//  Aman
//
//  Created by Arwindo Pratama.
//

import Foundation

class AirDropInterfacePolicyCheck: SystemCheck {
    init() {
        super.init(
            name: "Check AirDrop Interface Restrictions",
            description: "Reports AirDrop discoverability settings per interface (Contacts Only, Everyone, No One).",
            category: "Security",
            remediation: "Set AirDrop to 'Contacts Only' or 'No One' via Control Centre ▸ AirDrop options.",
            severity: "Medium",
            documentation: "https://support.apple.com/HT204144",
            mitigation: "Restricting AirDrop reduces unsolicited file transfers and lateral movement opportunities.",
            docID: 206
        )
    }

    override func check() {
        guard let value = CFPreferencesCopyValue("DiscoverableMode" as CFString, "com.apple.sharingd" as CFString, kCFPreferencesCurrentUser, kCFPreferencesAnyHost) as? String else {
            status = "Unable to determine AirDrop discoverability."
            checkstatus = "Yellow"
            return
        }

        switch value.lowercased() {
        case "contacts" :
            status = "AirDrop is limited to contacts."
            checkstatus = "Green"
        case "everyone" :
            status = "AirDrop is set to Everyone."
            checkstatus = "Red"
        default:
            status = "AirDrop discoverability: \(value)"
            checkstatus = value.lowercased() == "off" ? "Green" : "Yellow"
        }
    }
}
