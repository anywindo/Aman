//
//  PasswordPolicyInspector.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

enum PasswordPolicyInspector {
    static func loadPolicyXML() -> String? {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/pwpolicy")
        task.arguments = ["-getaccountpolicies"]

        let outputPipe = Pipe()
        let errorPipe = Pipe()
        task.standardOutput = outputPipe
        task.standardError = errorPipe

        do {
            try task.run()
            task.waitUntilExit()
        } catch {
            return nil
        }

        guard task.terminationStatus == 0 else {
            return nil
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard var text = String(data: data, encoding: .utf8), !text.isEmpty else {
            return nil
        }

        if let firstTagRange = text.range(of: "<") {
            text = String(text[firstTagRange.lowerBound...])
        }

        return text
    }

    static func loadPolicyPlist() -> Any? {
        guard let xml = loadPolicyXML(),
              let data = xml.data(using: .utf8) else {
            return nil
        }

        return try? PropertyListSerialization.propertyList(from: data, options: [], format: nil)
    }
}
