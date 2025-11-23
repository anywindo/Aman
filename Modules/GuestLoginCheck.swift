//
//  GuestLoginCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//


import Foundation

class GuestLoginCheck: SystemCheck {
    init() {
        super.init(
            name: "Guest Login Status Check",
            description: "Verify that guest login is disabled to protect your Mac from unauthorized access",
            category: "CIS Benchmark",
            remediation: "Disable guest login by opening System Settings ▸ Users & Groups ▸ Guest User and turning off ‘Allow guests to log in to this computer’.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/mac-help/set-up-other-users-on-your-mac-mtusr001/mac",
            mitigation: "Disabling guest login minimizes the risk of unauthorized access to your Mac by preventing users without a valid account from logging in.",
            checkstatus: "",
            docID: 2
        )
    }

    override func check() {
        if isGuestAccountDisabled() {
            status = "Guest login is disabled."
            checkstatus = "Green"
        } else {
            status = "Guest login is enabled."
            checkstatus = "Red"
        }
    }

    private func isGuestAccountDisabled() -> Bool {
        if let cliStatus = sysadminctlStatus() {
            return cliStatus
        }

        let plistPath = "/Library/Preferences/com.apple.loginwindow.plist"
        guard let data = FileManager.default.contents(atPath: plistPath) else {
            return true
        }

        do {
            if let plist = try PropertyListSerialization.propertyList(from: data, options: [], format: nil) as? [String: Any] {
                if let disabled = plist["DisableGuestAccount"] as? Bool {
                    return disabled
                }
                if let guestEnabled = plist["GuestEnabled"] as? Bool {
                    return guestEnabled == false
                }
            }
        } catch {
            print("Error reading guest configuration: \(error)")
        }
        return true
    }

    private func sysadminctlStatus() -> Bool? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/sysadminctl")
        task.arguments = ["-guestAccount", "status"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.lowercased() ?? ""
        if output.contains("disabled") {
            return true
        }
        if output.contains("enabled") {
            return false
        }
        return nil
    }
}
