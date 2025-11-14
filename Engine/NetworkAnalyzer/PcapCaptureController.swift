//
//  PcapCaptureController.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//


import Foundation

enum PcapCaptureError: LocalizedError {
    case tcpdumpNotFound
    case startFailed(String)
    case alreadyRunning
    case notRunning
    case permissionDenied
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .tcpdumpNotFound:
            return "tcpdump was not found. Please install it (e.g., via Homebrew) or ensure /usr/sbin/tcpdump exists."
        case .startFailed(let msg):
            return "Failed to start capture: \(msg)"
        case .alreadyRunning:
            return "Capture is already running."
        case .notRunning:
            return "Capture is not running."
        case .permissionDenied:
            return "Permission denied. Capturing on this interface may require elevated privileges."
        case .unknown(let msg):
            return msg
        }
    }
}

final class PcapCaptureController {
    struct Config {
        enum Mode {
            case standard
            case privileged
        }

        let interface: String
        let bpfFilter: String
        let mode: Mode
        let capturePayload: Bool

        init(
            interface: String,
            bpfFilter: String,
            mode: Mode = .standard,
            capturePayload: Bool = false
        ) {
            self.interface = interface
            self.bpfFilter = bpfFilter
            self.mode = mode
            self.capturePayload = capturePayload
        }

       
        var tcpdumpArgs: [String] {
            var args = ["-i", interface, "-tt", "-n", "-q", "-l"]
            if capturePayload {
                args.append(contentsOf: ["-s", "0"])
            }
            if !bpfFilter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                args.append(contentsOf: bpfFilter.split(separator: " ").map(String.init))
            }
            return args
        }
    }

    private var process: Process?
    private var stdoutPipe: Pipe?
    private var stderrPipe: Pipe?
    private let queue = DispatchQueue(label: "com.aman.pcap.capture", qos: .utility)


    var onPacketLine: ((String) -> Void)?
    var onError: ((PcapCaptureError) -> Void)?

    func start(config: Config) throws {
        guard process == nil else { throw PcapCaptureError.alreadyRunning }

        let tcpdumpURL = locateTcpdump()
        guard let tcpdumpURL else { throw PcapCaptureError.tcpdumpNotFound }

        let proc = Process()
        proc.executableURL = tcpdumpURL
        proc.arguments = config.tcpdumpArgs
        proc.environment = ProcessInfo.processInfo.environment.merging(["LANG": "C", "LC_ALL": "C"]) { cur, _ in cur }

        let out = Pipe()
        let err = Pipe()
        proc.standardOutput = out
        proc.standardError = err

        stdoutPipe = out
        stderrPipe = err
        process = proc

      
        out.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty { return }
            if let text = String(data: data, encoding: .utf8) {
                self.dispatchLines(text)
            }
        }

       
        err.fileHandleForReading.readabilityHandler = { [weak self] handle in
            guard let self else { return }
            let data = handle.availableData
            if data.isEmpty { return }
            let text = String(data: data, encoding: .utf8) ?? ""
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }

            let lower = trimmed.lowercased()
            if lower.contains("permission denied") || lower.contains("you don't have permission") {
                self.onError?(.permissionDenied)
                return
            }

          
            let informationalPrefixes = [
                "tcpdump: verbose output suppressed",
                "listening on ",
                "reading from"
            ]
            if informationalPrefixes.contains(where: { lower.hasPrefix($0) }) {
                return
            }

            self.onError?(.startFailed(trimmed))
        }

        do {
            try proc.run()
        } catch {
            stop()
            throw PcapCaptureError.startFailed(error.localizedDescription)
        }
    }

    func stop() {
        stdoutPipe?.fileHandleForReading.readabilityHandler = nil
        stderrPipe?.fileHandleForReading.readabilityHandler = nil
        stdoutPipe = nil
        stderrPipe = nil

        if let proc = process {
            if proc.isRunning {
                proc.terminate()
                proc.waitUntilExit()
            }
        }
        process = nil
    }

    private func dispatchLines(_ chunk: String) {
       
        queue.async { [weak self] in
            for line in chunk.split(whereSeparator: \.isNewline).map(String.init) {
                self?.onPacketLine?(line)
            }
        }
    }

    private func locateTcpdump() -> URL? {
        let candidates = [
            "/usr/sbin/tcpdump",
            "/usr/bin/tcpdump",
            "/opt/homebrew/sbin/tcpdump",
            "/opt/homebrew/bin/tcpdump",
            "/usr/local/sbin/tcpdump",
            "/usr/local/bin/tcpdump"
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return URL(fileURLWithPath: path)
        }
        return nil
    }
}
