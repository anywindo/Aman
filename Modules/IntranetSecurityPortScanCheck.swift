//
//  IntranetSecurityCVECheck.swift
//  Aman - Modules
//
//  Created by Aman Team on 08/11/25
//

import Foundation

final class IntranetSecurityCVECheck: SystemCheck {
    private let consentStore: IntranetConsentStore
    private let scanner: IntranetSecurityScanner

    init(
        consentStore: IntranetConsentStore = .shared,
        scanner: IntranetSecurityScanner = IntranetSecurityScanner()
    ) {
        self.consentStore = consentStore
        self.scanner = scanner
        super.init(
            name: "Intranet Security & CVE Mapping",
            description: """
            Performs authorized intranet discovery, fingerprints exposed services, and maps detected products to known CVEs to surface exploitable risks on the local network.
            """,
            category: "Network",
            categories: ["Security"],
            benchmarks: [],
            remediation: """
            Restrict or segment discovered services, apply vendor patches for flagged CVEs, and ensure only authorized hosts expose the identified ports. Review the generated log file for full findings and verify remediation steps are permitted for the scanned environment.
            """,
            severity: "High",
            documentation: "https://nmap.org/book/man-legal-issues.html",
            mitigation: """
            Confine scanning to networks where explicit authorization exists, sustain user consent, and remediate services with high-risk or exploitable CVEs. Maintain rate limits and test mode safeguards before expanding to live traffic.
            """,
            checkstatus: "Info",
            docID: 1301
        )
    }

    override func check() {
        let state = consentStore.currentState()
        guard state.consented else {
            checkstatus = "Info"
            status = """
            User consent is required before running intranet scans. Launch the Network Security window or enable consent via:
              defaults write -app Aman com.arwindo.aman.intranet.consent -bool true
            """
            return
        }

        let target = (state.targets.first ?? state.targets.last ?? "127.0.0.1").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else {
            checkstatus = "Info"
            status = "No valid target has been configured for the intranet CVE scan."
            return
        }

        do {
            let report = try scanner.runFullScan(target: target, consentGiven: true)
            checkstatus = verdict(for: report)
            status = renderStatus(for: report)
        } catch let error as IntranetScanError {
            checkstatus = "Yellow"
            status = error.localizedDescription
        } catch {
            checkstatus = "Yellow"
            status = "Intranet scan failed: \(error.localizedDescription)"
            self.error = error
        }
    }

    private func verdict(for report: IntranetScanReport) -> String {
        let maxScore = report.hosts
            .flatMap(\.vulnerabilities)
            .compactMap(\.score)
            .max() ?? 0

        switch maxScore {
        case 9...:
            return "Red"
        case 7..<9:
            return "Orange"
        case 4..<7:
            return "Yellow"
        default:
            return "Green"
        }
    }

    private func renderStatus(for report: IntranetScanReport) -> String {
        var lines: [String] = [
            "Target: \(report.target)",
            "Hosts discovered: \(report.hosts.count)",
            report.cveEnriched ? "CVE enrichment: complete" : "CVE enrichment: skipped"
        ]

        if !report.cveEnriched {
            lines.append("Run deep CVE enrichment from the Network Security dashboard to map vulnerabilities onto discovered services.")
        }

        if let firstHost = report.hosts.first {
            lines.append("")
            lines.append("Example host: \(firstHost.address)")
            if let os = firstHost.operatingSystem {
                lines.append("  OS guess: \(os)")
            }
            lines.append("  Services: \(firstHost.services.count)")
            lines.append("  CVEs mapped: \(firstHost.vulnerabilities.count)")
            if let top = firstHost.vulnerabilities.first {
                let scoreText = top.score.map { String(format: "%.1f", $0) } ?? "n/a"
                lines.append("  Top finding: \(top.identifier) (CVSS \(scoreText))")
            }
        }

        lines.append("")
        lines.append("Log file: \(report.logFileURL.path)")
        return lines.joined(separator: "\n")
    }
}
