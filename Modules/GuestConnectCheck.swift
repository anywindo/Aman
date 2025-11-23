//
//  GuestConnectCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class GuestConnectCheck: SystemCheck {
    init() {
        super.init(
            name: "Check 'Allow guests to connect to shared folders' Status",
            description: "This check ensures that the 'Allow guests to connect to shared folders' option is disabled on your system, which helps protect against unauthorized access to your computer.",
            category: "Security",
            remediation: "To disable guest access, open System Settings ▸ General ▸ Sharing ▸ File Sharing ▸ Options… and turn off ‘Allow guest users to connect to shared folders’.",
            severity: "Medium",
            documentation: "For more information on disabling 'Allow guests to connect to shared folders', visit: https://support.apple.com/guide/mac-help/share-mac-files-with-windows-users-mh14132/mac",
            mitigation: "By disabling 'Allow guests to connect to shared folders', you reduce the risk of unauthorized access to your computer's shared folders, enhancing its security.",
            docID: 31
        )
    }

    override func check() {
        let afpGuest = readOptionalBool(domain: "/Library/Preferences/com.apple.AppleFileServer", key: "guestAccess")
        let smbGuest = readOptionalBool(domain: "/Library/Preferences/SystemConfiguration/com.apple.smb.server", key: "AllowGuestAccess")

        if afpGuest == true || smbGuest == true {
            status = "Guest access to shared folders is enabled."
            checkstatus = "Red"
        } else {
            status = "Guest access to shared folders is disabled."
            checkstatus = "Green"
        }
    }

    private func readOptionalBool(domain: String, key: String) -> Bool? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["read", domain, key]

        let pipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = pipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        if task.terminationStatus != 0 {
            let errorOutput = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if errorOutput.contains("does not exist") || errorOutput.contains("The domain/default pair") {
                return nil
            }
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let trimmed = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
        if ["1", "true", "yes"].contains(trimmed) {
            return true
        }
        if ["0", "false", "no"].contains(trimmed) {
            return false
        }
        return nil
    }
}
