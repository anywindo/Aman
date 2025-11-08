//
//  IcloudEnabled.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class iCloudDriveCheck: SystemCheck {
    init() {
        super.init(
            name: "iCloud Drive Status Check",
            description: "Verify that iCloud Drive is enabled to provide backup and sync features for data protection and device recovery",
            category: "CIS Benchmark",
            remediation: "Enable iCloud Drive by going to System Preferences > Apple ID > iCloud and checking the box next to iCloud Drive",
            severity: "Medium",
            documentation: "https://support.apple.com/en-us/HT204025",
            mitigation: "Enabling iCloud Drive offers an additional layer of data protection and allows for seamless syncing and recovery of documents, desktop files, and app data across your devices.",
            checkstatus: "",
            docID: 3
        )
    }
    
    override func check() {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            task.arguments = ["defaults", "read", "com.apple.finder", "FXICloudDriveDesktop"]
            
            let outputPipe = Pipe()
            task.standardOutput = outputPipe
            
            do {
                try task.run()
                task.waitUntilExit()
                
                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                
                if output == "1" {
                    status = "iCloud Drive Document and Desktop sync is enabled."
                    checkstatus = "Green"
                } else {
                    status = "iCloud Drive Document and Desktop sync is disabled."
                    checkstatus = "Red"
                }
            } catch let e {
                print("Error checking \(name): \(e)")
                self.error = e
                checkstatus = "Yellow"
            }
        }
}
