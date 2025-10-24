//
//  CheckTimeMachineEnabled.swift
//  Aman
//
//  Created by Samet Sazak
//

import Foundation

class TimeMachineEnabledCheck: SystemCheck {
    init() {
        super.init(
            name: "Check that Time Machine is Enabled",
            description: "Check if Time Machine is enabled and has completed a backup",
            category: "CIS Benchmark",
            remediation: "Enable Time Machine in System Settings ▸ General ▸ Time Machine, choose a backup disk, and complete an initial backup.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/mac-help/what-is-time-machine-mh15139/mac",
            mitigation: "Enabling Time Machine and running regular backups helps to ensure that your system is regularly backed up to prevent data loss.",
            docID: 46
        )
    }
    
    override func check() {
        guard isTimeMachineConfigured() else {
            status = "Time Machine is not configured."
            checkstatus = "Red"
            return
        }

        switch latestBackupDate() {
        case .success(let backupDate):
            let days = Calendar.current.dateComponents([.day], from: backupDate, to: Date()).day ?? Int.max
            if days <= 30 {
                status = "Time Machine is enabled and the last backup completed on \(formatted(date: backupDate))."
                checkstatus = "Green"
            } else {
                status = "Time Machine is enabled but the last backup is older than 30 days (\(days) days)."
                checkstatus = "Red"
            }
        case .noBackups:
            status = "Time Machine is enabled but no backups have completed yet."
            checkstatus = "Yellow"
        case .error(let error):
            print("Error checking \(name): \(error)")
            status = "Error checking Time Machine status"
            checkstatus = "Yellow"
        }
    }

    private func isTimeMachineConfigured() -> Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        task.arguments = ["destinationinfo"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
            return task.terminationStatus == 0
        } catch {
            return false
        }
    }

    private enum BackupState {
        case success(Date)
        case noBackups
        case error(Error)
    }

    private func latestBackupDate() -> BackupState {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/tmutil")
        task.arguments = ["latestbackup"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe
        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return .error(error)
        }

        if task.terminationStatus != 0 {
            let errorOutput = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            if errorOutput.contains("No backups found") {
                return .noBackups
            }
            return .error(NSError(domain: NSPOSIXErrorDomain, code: Int(task.terminationStatus), userInfo: [NSLocalizedDescriptionKey: errorOutput]))
        }

        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard let lastComponent = output.split(separator: "/").last else {
            return .noBackups
        }

        let name = lastComponent.replacingOccurrences(of: ".backup", with: "")
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd-HHmmss"
        if let date = formatter.date(from: String(name)) {
            return .success(date)
        }
        return .noBackups
    }

    private func formatted(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}
