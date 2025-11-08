//
//  EfiCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation


class EFIVersionCheck: SystemCheck {
    
    init() {
        super.init(
            name: "Check EFI Version is Valid and Regularly Checked",
            description: "Check if the EFI version is valid and being regularly checked on the system",
            category: "CIS Benchmark",
            remediation: "Upgrade to the latest EFI version and enable automatic checks",
            severity: "Medium",
            documentation: "This code checks the current EFI version of the system and the date of the last EFI firmware update check. If the EFI version is outdated or the last update check is too long ago, it means that the system is at risk of EFI firmware attacks.",
            mitigation: "Upgrade to the latest EFI version and enable automatic checks to ensure that the system is protected from EFI firmware attacks.",
            docID: 26
        )
    }

    override func check() {
        let task = Process()
        task.launchPath = "/usr/sbin/system_profiler"
        task.arguments = ["SPHardwareDataType", "-xml"]

        let pipe = Pipe()
        task.standardOutput = pipe

        do {
            try task.run()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let xmlOutput = String(data: data, encoding: .utf8)

            if let efiVersion = xmlOutput?.components(separatedBy: "<key>boot_rom_version</key><string>").last?.components(separatedBy: "</string>").first {
                
                let currentDate = Date()
                
                let defaults = UserDefaults.standard
                
                if let lastCheckDate = defaults.object(forKey: "LastEFICheckDate") as? Date {
                    let calendar = Calendar.current
                    let components = calendar.dateComponents([.day], from: lastCheckDate, to: currentDate)
                    let daysSinceLastCheck = components.day ?? 0
                    
                    if daysSinceLastCheck <= 30 {
                        status = "EFI version is valid and being regularly checked"
                        checkstatus = "Green"
                    } else {
                        status = "EFI version is valid but last firmware update check was more than 30 days ago"
                        checkstatus = "Yellow"
                    }
                    
                } else {
                    status = "EFI version is valid but firmware update check has never been performed"
                    checkstatus = "Red"
                }
                
                defaults.set(currentDate, forKey: "LastEFICheckDate")
                
                if efiVersion.hasPrefix("MM") {
                    status = "EFI version is outdated and at risk of firmware attacks"
                    checkstatus = "Red"
                }
                
            } else {
                status = "Error checking EFI version"
                checkstatus = "Yellow"
            }
            
        } catch let e {
            print("Error checking \(name): \(e)")
            checkstatus = "Yellow"
            status = "Error checking EFI version"
            self.error = e
        }
    }
    
}
