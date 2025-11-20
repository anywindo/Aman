// 
//  [NetworkPortScanService].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Darwin
import Foundation
import OSLog

protocol NetworkPortScanService {
    func scan(
        host: DiscoveredHost,
        mode: PortScanMode,
        configuration: PortScannerConfiguration,
        progress: @Sendable @escaping (PortScanProgressUpdate) -> Void
    ) async throws -> [DiscoveredPort]

    func scan(
        ipAddress: String,
        mode: PortScanMode,
        configuration: PortScannerConfiguration,
        progress: @Sendable @escaping (PortScanProgressUpdate) -> Void
    ) async throws -> [DiscoveredPort]
}

final class DefaultNetworkPortScanService: NetworkPortScanService {
    private let scanner: PortScanner

    init(scanner: PortScanner = DefaultPortScanner()) {
        self.scanner = scanner
    }

    func scan(
        host: DiscoveredHost,
        mode: PortScanMode,
        configuration: PortScannerConfiguration,
        progress: @Sendable @escaping (PortScanProgressUpdate) -> Void
    ) async throws -> [DiscoveredPort] {
        try await scanner.scan(
            ipAddress: host.ipAddress,
            mode: mode,
            configuration: configuration,
            progress: progress
        )
    }

    func scan(
        ipAddress: String,
        mode: PortScanMode,
        configuration: PortScannerConfiguration,
        progress: @Sendable @escaping (PortScanProgressUpdate) -> Void
    ) async throws -> [DiscoveredPort] {
        try await scanner.scan(
            ipAddress: ipAddress,
            mode: mode,
            configuration: configuration,
            progress: progress
        )
    }
}

protocol PortScanner {
    func scan(
        ipAddress: String,
        mode: PortScanMode,
        configuration: PortScannerConfiguration,
        progress: @Sendable @escaping (PortScanProgressUpdate) -> Void
    ) async throws -> [DiscoveredPort]
}

final class DefaultPortScanner: PortScanner {
    private let logger = NetworkScanLogger.shared

    func scan(
        ipAddress: String,
        mode: PortScanMode,
        configuration: PortScannerConfiguration,
        progress: @Sendable @escaping (PortScanProgressUpdate) -> Void
    ) async throws -> [DiscoveredPort] {
        switch mode {
        case .connect:
            return try await connectScan(
                ipAddress: ipAddress,
                configuration: configuration,
                progress: progress
            )
        case .syn:
            logger.log(event: .synModeUnavailable(ip: ipAddress))
            throw PortScanError.modeRequiresPrivileges
        }
    }

    private func connectScan(
        ipAddress: String,
        configuration: PortScannerConfiguration,
        progress: @Sendable @escaping (PortScanProgressUpdate) -> Void
    ) async throws -> [DiscoveredPort] {
        let total = configuration.ports.count
        var completed = 0
        var discovered: [DiscoveredPort] = []

        for chunk in configuration.ports.chunked(into: configuration.maxConcurrency) {
            if Task.isCancelled { throw CancellationError() }

            try await withThrowingTaskGroup(of: DiscoveredPort?.self) { group in
                for port in chunk {
                    group.addTask {
                        if Task.isCancelled { return nil }
                        let start = Date()
                        let result = await PortProbe(ipAddress: ipAddress, port: port, timeout: configuration.timeout).run()
                        let latency = Date().timeIntervalSince(start)
                        return self.handleProbeResult(
                            result,
                            ipAddress: ipAddress,
                            port: port,
                            latency: latency
                        )
                    }
                }

                for try await port in group {
                    completed += 1
                    let update = PortScanProgressUpdate(
                        completed: completed,
                        total: total,
                        currentPort: port?.port,
                        mode: .connect,
                        timestamp: Date()
                    )
                    progress(update)

                    if let port {
                        discovered.append(port)
                    }
                }
            }
        }

        return discovered.sorted { lhs, rhs in
            lhs.port < rhs.port
        }
    }

    private func handleProbeResult(
        _ result: PortProbe.Result,
        ipAddress: String,
        port: UInt16,
        latency: TimeInterval
    ) -> DiscoveredPort? {
        switch result {
        case .open:
            logger.log(event: .portResult(ip: ipAddress, port: port, state: .open, latency: latency))
            return DiscoveredPort(
                port: port,
                transportProtocol: .tcp,
                state: .open,
                service: nil
            )
        case .closed:
            logger.log(event: .portResult(ip: ipAddress, port: port, state: .closed, latency: latency))
            return nil
        case .filtered:
            logger.log(event: .portResult(ip: ipAddress, port: port, state: .filtered, latency: latency))
            return nil
        case .error(let error):
            logger.log(event: .probeError(ip: ipAddress, port: port, description: error.localizedDescription))
            return nil
        case .cancelled:
            return nil
        }
    }
}

enum PortScanError: Error {
    case modeRequiresPrivileges
}

private struct PortProbe {
    enum Result {
        case open
        case closed
        case filtered
        case error(Error)
        case cancelled
    }

    let ipAddress: String
    let port: UInt16
    let timeout: TimeInterval

    func run() async -> Result {
        await withTaskCancellationHandler(operation: {
            await Task.detached(priority: .utility) { () -> Result in
                if Task.isCancelled { return .cancelled }
                return attemptConnection()
            }.value
        }, onCancel: {

        })
    }

    private func attemptConnection() -> Result {
        var hints = addrinfo(
            ai_flags: 0,
            ai_family: AF_UNSPEC,
            ai_socktype: SOCK_STREAM,
            ai_protocol: 0,
            ai_addrlen: 0,
            ai_canonname: nil,
            ai_addr: nil,
            ai_next: nil
        )

        var infoPointer: UnsafeMutablePointer<addrinfo>?
        let stringPort = String(port)
        let lookup = getaddrinfo(ipAddress, stringPort, &hints, &infoPointer)
        guard lookup == 0, let infoPointer else {
            return .error(PortProbeError.addressResolutionFailure(code: lookup))
        }

        defer {
            freeaddrinfo(infoPointer)
        }

        var pointer: UnsafeMutablePointer<addrinfo>? = infoPointer
        while let info = pointer?.pointee {
            let socketDescriptor = Darwin.socket(info.ai_family, info.ai_socktype, info.ai_protocol)
            if socketDescriptor < 0 {
                pointer = info.ai_next
                continue
            }

            defer {
                close(socketDescriptor)
            }

            if setNonBlocking(socketDescriptor) != 0 {
                pointer = info.ai_next
                continue
            }

            let connection = Darwin.connect(
                socketDescriptor,
                info.ai_addr,
                socklen_t(info.ai_addrlen)
            )

            if connection == 0 {
                return .open
            }

            if errno != EINPROGRESS {
                pointer = info.ai_next
                continue
            }

            var pollDescriptor = pollfd(fd: socketDescriptor, events: Int16(POLLOUT), revents: 0)
            let timeoutMilliseconds = Int32(max(timeout * 1000, 1))

            let pollResult = withUnsafeMutablePointer(to: &pollDescriptor) { pointer -> Int32 in
                poll(pointer, 1, timeoutMilliseconds)
            }

            if pollResult == 0 {
                return .filtered
            }

            if pollResult < 0 {
                return .error(PortProbeError.pollFailure(code: errno))
            }

            var error: Int32 = 0
            var errorLength = socklen_t(MemoryLayout<Int32>.size)
            if getsockopt(
                socketDescriptor,
                SOL_SOCKET,
                SO_ERROR,
                &error,
                &errorLength
            ) < 0 {
                return .error(PortProbeError.socketOptionFailure(code: errno))
            }

            if error == 0 {
                return .open
            }

            if error == ETIMEDOUT {
                return .filtered
            }

            return .closed
        }

        return .filtered
    }

    private func setNonBlocking(_ socketDescriptor: Int32) -> Int32 {
        let flags = fcntl(socketDescriptor, F_GETFL, 0)
        if flags == -1 {
            return -1
        }
        return fcntl(socketDescriptor, F_SETFL, flags | O_NONBLOCK)
    }
}

enum PortProbeError: Error {
    case addressResolutionFailure(code: Int32)
    case pollFailure(code: Int32)
    case socketOptionFailure(code: Int32)
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        var result: [[Element]] = []
        result.reserveCapacity((count / size) + 1)

        var index = startIndex
        while index < endIndex {
            let nextIndex = self.index(index, offsetBy: size, limitedBy: endIndex) ?? endIndex
            result.append(Array(self[index..<nextIndex]))
            index = nextIndex
        }
        return result
    }
}
