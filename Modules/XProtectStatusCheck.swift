//  XProtectStatusCheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

class XProtectStatusCheck: SystemCheck {
    private let thresholdDays: Int = 30

    init() {
        super.init(
            name: "Check XProtect/MRT/XProtectRemediator Are Current",
            description: "Confirms Apple's built-in malware defenses have been updated within the last 30 days and the resources are present.",
            category: "CIS Benchmark",
            remediation: "Allow Apple security data files to install automatically and run Software Update to fetch the latest XProtect, MRT and XProtectRemediator packages.",
            severity: "High",
            documentation: "https://support.apple.com/HT201940",
            mitigation: "Keeping XProtect, MRT and XProtectRemediator current helps block known malware and applies critical threat intelligence promptly.",
            docID: 104
        )
    }

    override func check() {
        let targets: [(name: String, path: String)] = [
            ("XProtect", "/Library/Apple/System/Library/CoreServices/XProtect.bundle/Contents/Resources/XProtect.meta.plist"),
            ("Malware Removal Tool", "/Library/Apple/System/Library/CoreServices/MRT.app/Contents/Info.plist"),
            ("XProtect Remediator", "/Library/Apple/System/Library/CoreServices/XProtect.app/Contents/Resources/XProtectRemediator.bundle/Contents/Info.plist")
        ]

        var missing: [String] = []
        var outdated: [String] = []

        for target in targets {
            var isDirectory: ObjCBool = false
            guard FileManager.default.fileExists(atPath: target.path, isDirectory: &isDirectory) else {
                missing.append(target.name)
                continue
            }

            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: target.path)
                if let modified = attributes[.modificationDate] as? Date {
                    let age = Calendar.current.dateComponents([.day], from: modified, to: Date()).day ?? Int.max
                    if age > thresholdDays {
                        outdated.append("\(target.name) (\(age) days old)")
                    }
                } else {
                    outdated.append("\(target.name) (unknown age)")
                }
            } catch {
                print("Error reading attributes for \(target.path): \(error)")
                status = "Unable to verify XProtect resource timestamps."
                checkstatus = "Yellow"
                self.error = error
                return
            }
        }

        if !missing.isEmpty {
            status = "Missing protection components: \(missing.joined(separator: ", "))."
            checkstatus = "Red"
            return
        }

        if !outdated.isEmpty {
            status = "Protection components appear stale: \(outdated.joined(separator: ", "))."
            checkstatus = "Red"
            return
        }

        status = "XProtect, MRT and XProtectRemediator are present and updated within \(thresholdDays) days."
        checkstatus = "Green"
    }
}
