//
//  IntranetSecurityScanner.swift
//  Aman
//
//  Rewritten CVE scanner built directly on top of nmap output.
//

import Foundation

// MARK: - Data Models

struct IntranetScanReport {
    struct Host: Identifiable, Hashable {
        struct Service: Identifiable, Hashable {
            var id: String { "\(port)/\(transport)" }

            let port: Int
            let transport: String
            let state: String
            let name: String
            let product: String?
            let version: String?
            let extraInfo: String?
            let vulnerabilities: [Host.Vulnerability]
        }

        struct Vulnerability: Identifiable, Hashable {
            let identifier: String
            let summary: String
            let score: Double?
            let referenceURL: URL?

            var id: String { identifier }
        }

        let address: String
        let hostnames: [String]
        let operatingSystem: String?
        let services: [Service]
        let vulnerabilities: [Vulnerability]
        let timedOut: Bool

        var id: String { address }
    }

    let startedAt: Date
    let finishedAt: Date
    let target: String
    let hosts: [Host]
    let rawOutput: String
    let logFileURL: URL
    let cveEnriched: Bool
}

// MARK: - Errors

enum IntranetScanError: LocalizedError {
    case consentRequired
    case invalidTarget(String)
    case nmapMissing([URL])
    case commandFailed(code: Int32, stderr: String)
    case parseFailure

    var errorDescription: String? {
        switch self {
        case .consentRequired:
            return "User consent is required before scanning a network target."
        case .invalidTarget(let input):
            return "Target \"\(input)\" is not a valid IPv4 address or hostname."
        case .nmapMissing(let locations):
            let rendered = locations.map(\.path).joined(separator: ", ")
            return "Unable to find the nmap executable. Checked: \(rendered)"
        case .commandFailed(let code, let stderr):
            return "nmap exited with code \(code): \(stderr.isEmpty ? "no additional information" : stderr)"
        case .parseFailure:
            return "The nmap output could not be parsed."
        }
    }
}

// MARK: - Scanner

final class IntranetSecurityScanner {
    private let searchPaths: [URL] = [
        URL(fileURLWithPath: "/opt/homebrew/bin/nmap"),
        URL(fileURLWithPath: "/usr/local/bin/nmap"),
        URL(fileURLWithPath: "/opt/local/bin/nmap"),
        URL(fileURLWithPath: "/usr/bin/nmap")
    ]

    func runQuickScan(target: String, consentGiven: Bool) throws -> IntranetScanReport {
        let trimmedTarget = try validatedTarget(target, consentGiven: consentGiven)
        let args = [
            "-sV",
            "-Pn",
            "--top-ports", "200",
            "--host-timeout", "45s",
            "--max-retries", "1",
            "-oX",
            "-",
            trimmedTarget
        ]
        return try executeScan(
            target: trimmedTarget,
            arguments: args,
            modeDescription: "Quick service scan (no CVE enrichment)",
            cveEnriched: false
        )
    }

    func enrichWithCVEs(report: IntranetScanReport, consentGiven: Bool) throws -> IntranetScanReport {
        _ = try validatedTarget(report.target, consentGiven: consentGiven)

        let uniquePorts = Array(Set(report.hosts.flatMap { $0.services.map { $0.port } })).sorted()
        guard !uniquePorts.isEmpty else {
            let logWriter = try ScanLogWriter.make()
            logWriter.log("CVE enrichment skipped: no services discovered during quick scan.")
            let finished = Date()
            logWriter.log("Finished at \(Self.timestampFormatter.string(from: finished)) without enrichment.")
            logWriter.close()
            return IntranetScanReport(
                startedAt: report.startedAt,
                finishedAt: finished,
                target: report.target,
                hosts: report.hosts,
                rawOutput: report.rawOutput,
                logFileURL: logWriter.fileURL,
                cveEnriched: true
            )
        }

        let portArgument = uniquePorts.map(String.init).joined(separator: ",")
        let args = [
            "-sV",
            "--script",
            "vulners",
            "-Pn",
            "-p", portArgument,
            "--host-timeout", "90s",
            "--max-retries", "2",
            "--script-timeout", "45s",
            "-oX",
            "-",
            report.target
        ]

        let enriched = try executeScan(
            target: report.target,
            arguments: args,
            modeDescription: "Deep CVE enrichment (vulners)",
            cveEnriched: true
        )

        return merge(baseReport: report, enrichedReport: enriched)
    }

    func runFullScan(target: String, consentGiven: Bool) throws -> IntranetScanReport {
        let quick = try runQuickScan(target: target, consentGiven: consentGiven)
        guard quick.hosts.contains(where: { !$0.services.isEmpty }) else {
            return quick
        }
        return try enrichWithCVEs(report: quick, consentGiven: consentGiven)
    }

    private func validatedTarget(_ target: String, consentGiven: Bool) throws -> String {
        guard consentGiven else {
            throw IntranetScanError.consentRequired
        }
        let trimmed = target.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw IntranetScanError.invalidTarget(target)
        }
        return trimmed
    }

    private func executeScan(
        target: String,
        arguments: [String],
        modeDescription: String,
        cveEnriched: Bool
    ) throws -> IntranetScanReport {
        let nmapURL = try locateNmap()
        let startedAt = Date()

        let logWriter = try ScanLogWriter.make()
        logWriter.log("Scan started at \(Self.timestampFormatter.string(from: startedAt))")
        logWriter.log("Mode: \(modeDescription)")
        let renderedCommand = ([nmapURL.path] + arguments).joined(separator: " ")
        logWriter.log("Command: \(renderedCommand)")

        let (stdout, stderr, exitCode) = try runProcess(executable: nmapURL, arguments: arguments)

        if !stderr.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            logWriter.log("stderr:\n\(stderr)")
        }

        guard exitCode == 0 || exitCode == 1 else {
            logWriter.log("nmap terminated with code \(exitCode)")
            logWriter.close()
            throw IntranetScanError.commandFailed(code: exitCode, stderr: stderr)
        }

        logWriter.log("stdout:\n\(stdout)")

        let parser = NmapXMLParser()
        let hosts = parser.parse(stdout)
        if hosts.isEmpty {
            logWriter.log("No hosts were parsed from the output.")
        }

        let finishedAt = Date()
        logWriter.log("Scan finished at \(Self.timestampFormatter.string(from: finishedAt)) — parsed \(hosts.count) host(s).")
        logWriter.close()

        return IntranetScanReport(
            startedAt: startedAt,
            finishedAt: finishedAt,
            target: target,
            hosts: hosts,
            rawOutput: stdout,
            logFileURL: logWriter.fileURL,
            cveEnriched: cveEnriched
        )
    }

    private func merge(baseReport: IntranetScanReport, enrichedReport: IntranetScanReport) -> IntranetScanReport {
        var enrichedMap = Dictionary(uniqueKeysWithValues: enrichedReport.hosts.map { ($0.address, $0) })

        let mergedHosts = baseReport.hosts.map { baseHost -> IntranetScanReport.Host in
            if let enrichedHost = enrichedMap.removeValue(forKey: baseHost.address) {
                return IntranetScanReport.Host(
                    address: enrichedHost.address,
                    hostnames: enrichedHost.hostnames.isEmpty ? baseHost.hostnames : enrichedHost.hostnames,
                    operatingSystem: enrichedHost.operatingSystem ?? baseHost.operatingSystem,
                    services: enrichedHost.services.isEmpty ? baseHost.services : enrichedHost.services,
                    vulnerabilities: enrichedHost.vulnerabilities,
                    timedOut: baseHost.timedOut || enrichedHost.timedOut
                )
            }
            return IntranetScanReport.Host(
                address: baseHost.address,
                hostnames: baseHost.hostnames,
                operatingSystem: baseHost.operatingSystem,
                services: baseHost.services,
                vulnerabilities: baseHost.vulnerabilities,
                timedOut: baseHost.timedOut
            )
        }

        let remainingHosts = enrichedMap.values.map { host in
            IntranetScanReport.Host(
                address: host.address,
                hostnames: host.hostnames,
                operatingSystem: host.operatingSystem,
                services: host.services,
                vulnerabilities: host.vulnerabilities,
                timedOut: host.timedOut
            )
        }

        return IntranetScanReport(
            startedAt: baseReport.startedAt,
            finishedAt: enrichedReport.finishedAt,
            target: baseReport.target,
            hosts: mergedHosts + remainingHosts,
            rawOutput: enrichedReport.rawOutput,
            logFileURL: enrichedReport.logFileURL,
            cveEnriched: true
        )
    }

    private func locateNmap() throws -> URL {
        for path in searchPaths where FileManager.default.isExecutableFile(atPath: path.path) {
            return path
        }
        throw IntranetScanError.nmapMissing(searchPaths)
    }

    private func runProcess(executable: URL, arguments: [String]) throws -> (stdout: String, stderr: String, code: Int32) {
        let process = Process()
        process.executableURL = executable
        process.arguments = arguments
        process.environment = ProcessInfo.processInfo.environment.merging(["LANG": "C", "LC_ALL": "C"]) { current, _ in current }

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe

        try process.run()
        process.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return (stdout, stderr, process.terminationStatus)
    }

    private static let timestampFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

}

// MARK: - Parser

private final class NmapXMLParser {
    func parse(_ xml: String) -> [IntranetScanReport.Host] {
        guard let data = xml.data(using: .utf8) else { return [] }
        guard let document = try? XMLDocument(data: data) else { return [] }
        guard let hostNodes = try? document.nodes(forXPath: "/nmaprun/host") as? [XMLElement] else { return [] }
        return hostNodes.compactMap(parseHost)
    }

    private func parseHost(_ element: XMLElement) -> IntranetScanReport.Host? {
        if let statusElement = element.elements(forName: "status").first,
           let state = statusElement.attribute(forName: "state")?.stringValue,
           state.lowercased() != "up" {
            return nil
        }

        guard let addressElement = element.elements(forName: "address").first(where: { addrElement in
            guard let type = addrElement.attribute(forName: "addrtype")?.stringValue else { return true }
            return type == "ipv4" || type == "ipv6"
        }),
        let address = addressElement.attribute(forName: "addr")?.stringValue else { return nil }

        let hostnameNodes = (try? element.nodes(forXPath: "hostnames/hostname") as? [XMLElement]) ?? []
        let hostnames = hostnameNodes.compactMap { $0.attribute(forName: "name")?.stringValue }

        let timedOut = element.attribute(forName: "timedout")?.stringValue == "true"

        var osGuess: String?
        if let osMatch = (try? element.nodes(forXPath: "os/osmatch") as? [XMLElement])?.first,
           let name = osMatch.attribute(forName: "name")?.stringValue {
            osGuess = name
        }

        let portNodes = (try? element.nodes(forXPath: "ports/port") as? [XMLElement]) ?? []
        var services: [IntranetScanReport.Host.Service] = []
        var hostVulnerabilities: [IntranetScanReport.Host.Vulnerability] = []

        for portNode in portNodes {
            guard let parsed = parseService(portNode) else { continue }
            services.append(parsed.service)
            hostVulnerabilities.append(contentsOf: parsed.vulnerabilities)
        }

        if let hostScripts = try? element.nodes(forXPath: "hostscript/script[@id='vulners']") as? [XMLElement] {
            for script in hostScripts {
                hostVulnerabilities.append(contentsOf: extractVulnerabilities(from: script))
            }
        }

        let deduped = dedupeVulnerabilities(hostVulnerabilities)

        return IntranetScanReport.Host(
            address: address,
            hostnames: hostnames,
            operatingSystem: osGuess,
            services: services,
            vulnerabilities: deduped,
            timedOut: timedOut
        )
    }

    private func parseService(_ element: XMLElement) -> (service: IntranetScanReport.Host.Service, vulnerabilities: [IntranetScanReport.Host.Vulnerability])? {
        guard let portString = element.attribute(forName: "portid")?.stringValue,
              let port = Int(portString),
              let transport = element.attribute(forName: "protocol")?.stringValue else { return nil }

        guard let stateElement = element.elements(forName: "state").first,
              let state = stateElement.attribute(forName: "state")?.stringValue else { return nil }

        let serviceElement = element.elements(forName: "service").first
        let name = serviceElement?.attribute(forName: "name")?.stringValue ?? "unknown"
        let product = serviceElement?.attribute(forName: "product")?.stringValue
        let version = serviceElement?.attribute(forName: "version")?.stringValue
        let extra = serviceElement?.attribute(forName: "extrainfo")?.stringValue

        var vulnerabilities: [IntranetScanReport.Host.Vulnerability] = []
        if let scripts = try? element.nodes(forXPath: "script[@id='vulners']") as? [XMLElement] {
            for script in scripts {
                vulnerabilities.append(contentsOf: extractVulnerabilities(from: script))
            }
        }

        let service = IntranetScanReport.Host.Service(
            port: port,
            transport: transport,
            state: state,
            name: name,
            product: product,
            version: version,
            extraInfo: extra,
            vulnerabilities: vulnerabilities
        )

        return (service, vulnerabilities)
    }

    private func extractVulnerabilities(from script: XMLElement) -> [IntranetScanReport.Host.Vulnerability] {
        var results: [IntranetScanReport.Host.Vulnerability] = []

        if let output = script.attribute(forName: "output")?.stringValue {
            let lines = output.components(separatedBy: CharacterSet.newlines)
            for line in lines {
                if let vuln = parseVulnerability(from: line) {
                    results.append(vuln)
                }
            }
        }

        for table in script.elements(forName: "table") {
            results.append(contentsOf: extractVulnerabilities(fromTable: table))
        }

        return results
    }

    private func extractVulnerabilities(fromTable table: XMLElement) -> [IntranetScanReport.Host.Vulnerability] {
        var results: [IntranetScanReport.Host.Vulnerability] = []

        for nested in table.elements(forName: "table") {
            results.append(contentsOf: extractVulnerabilities(fromTable: nested))
        }

        let elements = table.elements(forName: "elem")
        var identifier = table.attribute(forName: "key")?.stringValue
        var scoreString: String?
        var referenceURL: URL?
        var summary: String?

        for elem in elements {
            let key = elem.attribute(forName: "key")?.stringValue?.lowercased()
            switch key {
            case "id":
                if identifier == nil { identifier = elem.stringValue }
            case "cvss", "cvss_score", "cvss3":
                scoreString = elem.stringValue
            case "source", "href", "url":
                if let raw = elem.stringValue, let url = URL(string: raw) {
                    referenceURL = url
                }
            case "title", "summary":
                summary = elem.stringValue
            default:
                break
            }
        }

        guard let rawIdentifier = identifier,
              let identifierMatch = matchFirst(in: rawIdentifier, pattern: #"CVE-\d{4}-\d{4,7}"#) else {
            return results
        }

        let score = parseScore(scoreString)
        let trimmedSummary = summary?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let resolvedSummary = trimmedSummary.isEmpty ? "No summary provided." : trimmedSummary

        results.append(
            IntranetScanReport.Host.Vulnerability(
                identifier: identifierMatch,
                summary: resolvedSummary,
                score: score,
                referenceURL: referenceURL
            )
        )

        return results
    }

    private func parseVulnerability(from line: String) -> IntranetScanReport.Host.Vulnerability? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let identifier = matchFirst(in: trimmed, pattern: #"CVE-\d{4}-\d{4,7}"#) else { return nil }

        let scoreString = matchFirst(in: trimmed, pattern: #"\b\d{1,2}\.\d{1,2}\b"#)
        let score = parseScore(scoreString)
        let urlString = matchFirst(in: trimmed, pattern: #"https?://\S+"#)
        let reference = urlString.flatMap(URL.init(string:))

        var summary = trimmed
        summary = summary.replacingOccurrences(of: identifier, with: "")
        if let scoreString {
            summary = summary.replacingOccurrences(of: scoreString, with: "")
        }
        if let urlString {
            summary = summary.replacingOccurrences(of: urlString, with: "")
        }
        summary = summary.trimmingCharacters(in: CharacterSet(charactersIn: "-: ")).trimmingCharacters(in: .whitespacesAndNewlines)
        if summary.isEmpty {
            summary = "No summary provided."
        }

        return IntranetScanReport.Host.Vulnerability(
            identifier: identifier,
            summary: summary,
            score: score,
            referenceURL: reference
        )
    }

    private func dedupeVulnerabilities(_ vulnerabilities: [IntranetScanReport.Host.Vulnerability]) -> [IntranetScanReport.Host.Vulnerability] {
        var map: [String: IntranetScanReport.Host.Vulnerability] = [:]
        for vulnerability in vulnerabilities {
            if let existing = map[vulnerability.identifier] {
                let bestScore = max(existing.score ?? 0, vulnerability.score ?? 0)
                let merged = IntranetScanReport.Host.Vulnerability(
                    identifier: vulnerability.identifier,
                    summary: existing.summary.isEmpty ? vulnerability.summary : existing.summary,
                    score: bestScore == 0 ? existing.score ?? vulnerability.score : bestScore,
                    referenceURL: existing.referenceURL ?? vulnerability.referenceURL
                )
                map[vulnerability.identifier] = merged
            } else {
                map[vulnerability.identifier] = vulnerability
            }
        }
        return map.values.sorted { ($0.score ?? 0) > ($1.score ?? 0) }
    }

    private func matchFirst(in text: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else { return nil }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, options: [], range: range),
              let resultRange = Range(match.range, in: text) else { return nil }
        return String(text[resultRange])
    }

    private func parseScore(_ raw: String?) -> Double? {
        guard let raw, !raw.isEmpty else { return nil }
        let cleaned = raw.split(separator: "/", maxSplits: 1).first.map(String.init) ?? raw
        return Double(cleaned.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}
// MARK: - Scan Log Writer

private final class ScanLogWriter {
    let fileURL: URL
    private let handle: FileHandle
    private let queue = DispatchQueue(label: "com.arwindo.aman.cve-scan-log", qos: .utility)

    private init(fileURL: URL, handle: FileHandle) {
        self.fileURL = fileURL
        self.handle = handle
    }

    static func make() throws -> ScanLogWriter {
        let directory = FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Logs/Aman", isDirectory: true) ?? URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("AmanLogs", isDirectory: true)

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let timestamp = Self.filenameFormatter.string(from: Date())
        let fileURL = directory.appendingPathComponent("cve-scan-\(timestamp).log")

        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        guard let handle = try? FileHandle(forWritingTo: fileURL) else {
            throw IntranetScanError.parseFailure
        }

        return ScanLogWriter(fileURL: fileURL, handle: handle)
    }

    func log(_ message: String) {
        queue.async { [handle] in
            guard let data = (message + "\n").data(using: .utf8) else { return }
            do {
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } catch {
                // Best-effort logging.
            }
        }
    }

    func close() {
        queue.sync {
            try? handle.close()
        }
    }

    private static let filenameFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd-HHmmss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    deinit {
        close()
    }
}
