//  PortListeningInventoryCheck.swift
//  Aman - Modules
//
//   Created by Aman Team on 08/11/25
//

import Foundation

class PortListeningInventoryCheck: SystemCheck {
    private let executor: ShellCommandRunning

    init(executor: ShellCommandRunning = ProcessShellRunner()) {
        self.executor = executor
        super.init(
            name: "Inventory Listening TCP Ports",
            description: "Reports TCP services listening on local interfaces so administrators can review unexpected exposure.",
            category: "Security",
            remediation: "Disable unnecessary services or restrict them via firewall, launchctl overrides, or configuration changes.",
            severity: "Medium",
            documentation: "https://support.apple.com/guide/mac-help/block-connections-to-your-mac-mh34042/mac",
            mitigation: "Monitoring listening ports helps detect rogue or legacy services that increase attack surface.",
            docID: 201
        )
    }

    override func check() {
        let executable = URL(fileURLWithPath: "/usr/sbin/netstat")
        do {
            let result = try executor.run(executableURL: executable, arguments: ["-an", "-p", "tcp"])
            guard result.terminationStatus == 0 else {
                status = "netstat exited with status \(result.terminationStatus)."
                checkstatus = "Yellow"
                return
            }

            let listeningSockets = parseListeningSockets(from: result.stdout)

            if listeningSockets.isEmpty {
                status = "No listening TCP ports detected."
                checkstatus = "Green"
            } else {
                status = "Listening sockets detected:\n" + listeningSockets.joined(separator: "\n")
                checkstatus = "Yellow"
            }
        } catch {
            status = "Unable to run netstat: \(error.localizedDescription)"
            checkstatus = "Yellow"
            self.error = error
            return
        }
    }

    func parseListeningSockets(from output: String) -> [String] {
        output
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { $0.localizedCaseInsensitiveContains("listen") && !$0.isEmpty }
    }
}
