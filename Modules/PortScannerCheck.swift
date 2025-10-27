//
//  PortScannerCheck.swift
//  Aman
//
//  Created by Arwindo Pratama
//

import Foundation
import Darwin
import System

final class PortScannerCheck: SystemCheck {

    // MARK: - Configuration
    struct Config {
        let host: String
        let ports: [Int]
        let connectTimeoutSeconds: TimeInterval
        let readTimeoutSeconds: TimeInterval
        let maxConcurrent: Int
        let bannerMaxBytes: Int
        let enableBannerGrab: Bool

        static func `default`() -> Config {
            // Curated common ports + a few extras
            let common: [Int] = [
                20,21,22,23,25,53,67,68,69,80,110,111,123,135,137,138,139,
                143,161,389,443,445,465,500,514,515,587,631,993,995,
                1025,1080,1433,1521,1723,2049,2181,2375,2376,2483,2484,
                3000,3306,3389,3690,4369,5000,5432,5672,5900,5984,6379,
                6667,7001,7002,8000,8008,8080,8081,8443,8888,9000,9042,
                9200,9418,11211,27017
            ]
            return Config(
                host: "127.0.0.1",
                ports: common,
                // Tighter defaults to reduce long-tail and perceived hang
                connectTimeoutSeconds: 1.0,
                readTimeoutSeconds: 0.25,
                // Less aggressive concurrency to avoid a scheduling spike
                maxConcurrent: 48,
                bannerMaxBytes: 160,
                enableBannerGrab: true
            )
        }
    }

    // MARK: - Result
    struct PortResult {
        let port: Int
        let service: String
        let open: Bool
        let latencyMs: Int?
        let banner: String?
        let error: String?
    }

    private enum PortScanError: Error, CustomStringConvertible {
        case socketFailed
        case connectError(Int32)
        case connectFailed(Int32)
        case timeout
        case dnsResolutionFailed

        var description: String {
            switch self {
            case .socketFailed: return "socket() failed"
            case .connectError(let code): return "connect error \(code)"
            case .connectFailed(let code): return "connect failed \(code)"
            case .timeout: return "timeout"
            case .dnsResolutionFailed: return "DNS resolution failed"
            }
        }
    }

    private let config: Config

    init(config: Config = .default()) {
        self.config = config
        super.init(
            name: "Local TCP Ports Scan",
            description: "Scans a set of common TCP ports on the local host and reports open services with latency and optional banners.",
            category: "Security",
            remediation: "Close or restrict access to unnecessary services. Disable unneeded daemons and ensure only required ports are accessible. Use a firewall to limit exposure.",
            severity: "Medium",
            documentation: "https://developer.apple.com/documentation/network",
            mitigation: "Reducing exposed ports minimizes attack surface. Limit services to localhost when possible, require authentication, and keep software updated.",
            docID: 1001
        )
    }

    override func check() {
        let started = Date()
        let results = scanHost(host: config.host, ports: config.ports)
        let open = results.filter { $0.open }

        // Determine status color
        let highRiskPorts: Set<Int> = [21,22,23,25,110,139,445,3306,3389,5432,5900,6379,9200,11211,27017]
        let hasHighRisk = open.contains { highRiskPorts.contains($0.port) }

        if open.isEmpty {
            checkstatus = "Green"
        } else if hasHighRisk {
            checkstatus = "Red"
        } else {
            checkstatus = "Yellow"
        }

        let elapsedMs = Int((Date().timeIntervalSince(started) * 1000).rounded())
        if open.isEmpty {
            status = "No open TCP ports detected on \(config.host). Scanned \(config.ports.count) ports in \(elapsedMs) ms."
            return
        }

        // Build detailed multi-line summary
        let header = "Found \(open.count) open TCP port(s) on \(config.host). Scanned \(config.ports.count) ports in \(elapsedMs) ms."
        let lines = open
            .sorted { $0.port < $1.port }
            .map { r -> String in
                let latency = r.latencyMs.map { "\($0) ms" } ?? "n/a"
                let svc = r.service.isEmpty ? "-" : r.service
                var line = "\(r.port)/tcp (\(svc)) open • \(latency)"
                if let banner = r.banner, !banner.isEmpty {
                    let trimmed = banner.replacingOccurrences(of: "\r", with: " ").replacingOccurrences(of: "\n", with: " ").trimmingCharacters(in: .whitespacesAndNewlines)
                    if !trimmed.isEmpty {
                        line += " • banner: \(trimmed.prefix(160))"
                    }
                }
                return line
            }
            .joined(separator: "\n")

        status = "\(header)\n\(lines)"
    }

    // MARK: - Core scanning

    private func scanHost(host: String, ports: [Int]) -> [PortResult] {
        // Resolve address first
        guard let addr = resolveIPv4(host: host) ?? resolveIPv6(host: host) else {
            return ports.map { PortResult(port: $0, service: serviceName(for: $0), open: false, latencyMs: nil, banner: nil, error: PortScanError.dnsResolutionFailed.description) }
        }

        // Concurrency limiter
        let group = DispatchGroup()
        let semaphore = DispatchSemaphore(value: config.maxConcurrent)
        let resultLock = NSLock()
        var results: [PortResult] = []
        results.reserveCapacity(ports.count)

        // Submit in small batches to reduce initial scheduling spike
        let batchSize = 16
        let batches = stride(from: 0, to: ports.count, by: batchSize).map { start in
            Array(ports[start..<min(start + batchSize, ports.count)])
        }

        for (batchIndex, batch) in batches.enumerated() {
            for port in batch {
                semaphore.wait()
                group.enter()
                DispatchQueue.global(qos: .userInitiated).async {
                    let start = Date()
                    let outcome = self.tryConnect(address: addr, port: port, timeout: self.config.connectTimeoutSeconds)
                    let latency = Int((Date().timeIntervalSince(start) * 1000).rounded())

                    switch outcome {
                    case .success(let fd):
                        var banner: String? = nil
                        if self.config.enableBannerGrab {
                            banner = self.readBanner(fd: fd, timeout: self.config.readTimeoutSeconds, maxBytes: self.config.bannerMaxBytes)
                        }
                        close(fd)
                        let pr = PortResult(port: port, service: self.serviceName(for: port), open: true, latencyMs: latency, banner: banner, error: nil)
                        resultLock.lock(); results.append(pr); resultLock.unlock()
                    case .failure(let err):
                        let pr = PortResult(port: port, service: self.serviceName(for: port), open: false, latencyMs: latency, banner: nil, error: err.description)
                        resultLock.lock(); results.append(pr); resultLock.unlock()
                    }
                    semaphore.signal()
                    group.leave()
                }
            }

            // Tiny inter-batch pause to let the system breathe
            if batchIndex < batches.count - 1 {
                // 3 ms is enough to avoid a burst without slowing the scan noticeably
                let nanos: UInt64 = 3_000_000
                let deadline = DispatchTime.now() + .nanoseconds(Int(nanos))
                // Sleep the submitting thread (not the main thread)
                _ = DispatchSemaphore(value: 0).wait(timeout: deadline)
            }
        }

        group.wait()
        return results
    }

    private enum Address {
        case ipv4(sockaddr_in)
        case ipv6(sockaddr_in6)
    }

    private func resolveIPv4(host: String) -> Address? {
        var hints = addrinfo(ai_flags: 0, ai_family: AF_INET, ai_socktype: SOCK_STREAM, ai_protocol: IPPROTO_TCP, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var res: UnsafeMutablePointer<addrinfo>?
        if getaddrinfo(host, nil, &hints, &res) != 0 { return nil }
        defer { if res != nil { freeaddrinfo(res) } }
        var p = res
        while p != nil {
            if let ai = p?.pointee, ai.ai_family == AF_INET, let sa = ai.ai_addr?.withMemoryRebound(to: sockaddr_in.self, capacity: 1, { $0.pointee }) {
                return .ipv4(sa)
            }
            p = p?.pointee.ai_next
        }
        return nil
    }

    private func resolveIPv6(host: String) -> Address? {
        var hints = addrinfo(ai_flags: 0, ai_family: AF_INET6, ai_socktype: SOCK_STREAM, ai_protocol: IPPROTO_TCP, ai_addrlen: 0, ai_canonname: nil, ai_addr: nil, ai_next: nil)
        var res: UnsafeMutablePointer<addrinfo>?
        if getaddrinfo(host, nil, &hints, &res) != 0 { return nil }
        defer { if res != nil { freeaddrinfo(res) } }
        var p = res
        while p != nil {
            if let ai = p?.pointee, ai.ai_family == AF_INET6, let sa = ai.ai_addr?.withMemoryRebound(to: sockaddr_in6.self, capacity: 1, { $0.pointee }) {
                return .ipv6(sa)
            }
            p = p?.pointee.ai_next
        }
        return nil
    }

    private func tryConnect(address: Address, port: Int, timeout: TimeInterval) -> Result<Int32, PortScanError> {
        switch address {
        case .ipv4(var sa):
            let fd = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP)
            if fd < 0 { return .failure(.socketFailed) }
            let flags = fcntl(fd, F_GETFL, 0)
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

            sa.sin_port = in_port_t(UInt16(port).bigEndian)
            var addr = sockaddr()
            var sin = sa
            memcpy(&addr, &sin, MemoryLayout<sockaddr_in>.size)
            let connectResult = withUnsafePointer(to: &addr) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in>.size))
                }
            }

            if connectResult == 0 {
                setBlocking(fd)
                return .success(fd)
            }

            if errno != EINPROGRESS {
                let code = errno
                close(fd)
                return .failure(.connectError(code))
            }

            // Wait for writability or timeout
            var wfds = fd_set()
            fdZero(&wfds)
            fdSet(fd, &wfds)
            var tv = makeTimeval(timeout)
            let sel = select(fd + 1, nil, &wfds, nil, &tv)
            if sel == 1 {
                var so_error: Int32 = 0
                var len = socklen_t(MemoryLayout<Int32>.size)
                if getsockopt(fd, SOL_SOCKET, SO_ERROR, &so_error, &len) == 0, so_error == 0 {
                    setBlocking(fd)
                    return .success(fd)
                } else {
                    let code = so_error != 0 ? so_error : errno
                    close(fd)
                    return .failure(.connectFailed(code))
                }
            } else {
                close(fd)
                return .failure(.timeout)
            }

        case .ipv6(var sa6):
            let fd = socket(AF_INET6, SOCK_STREAM, IPPROTO_TCP)
            if fd < 0 { return .failure(.socketFailed) }
            let flags = fcntl(fd, F_GETFL, 0)
            _ = fcntl(fd, F_SETFL, flags | O_NONBLOCK)

            sa6.sin6_port = in_port_t(UInt16(port).bigEndian)
            var addr6 = sockaddr()
            var sin6 = sa6
            memcpy(&addr6, &sin6, MemoryLayout<sockaddr_in6>.size)
            let connectResult = withUnsafePointer(to: &addr6) {
                $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                    connect(fd, $0, socklen_t(MemoryLayout<sockaddr_in6>.size))
                }
            }

            if connectResult == 0 {
                setBlocking(fd)
                return .success(fd)
            }

            if errno != EINPROGRESS {
                let code = errno
                close(fd)
                return .failure(.connectError(code))
            }

            var wfds = fd_set()
            fdZero(&wfds)
            fdSet(fd, &wfds)
            var tv = makeTimeval(timeout)
            let sel = select(fd + 1, nil, &wfds, nil, &tv)
            if sel == 1 {
                var so_error: Int32 = 0
                var len = socklen_t(MemoryLayout<Int32>.size)
                if getsockopt(fd, SOL_SOCKET, SO_ERROR, &so_error, &len) == 0, so_error == 0 {
                    setBlocking(fd)
                    return .success(fd)
                } else {
                    let code = so_error != 0 ? so_error : errno
                    close(fd)
                    return .failure(.connectFailed(code))
                }
            } else {
                close(fd)
                return .failure(.timeout)
            }
        }
    }

    private func setBlocking(_ fd: Int32) {
        let flags = fcntl(fd, F_GETFL, 0)
        _ = fcntl(fd, F_SETFL, flags & ~O_NONBLOCK)
    }

    private func readBanner(fd: Int32, timeout: TimeInterval, maxBytes: Int) -> String? {
        var rfds = fd_set()
        fdZero(&rfds)
        fdSet(fd, &rfds)
        var tv = makeTimeval(timeout)
        let sel = select(fd + 1, &rfds, nil, nil, &tv)
        if sel <= 0 { return nil }

        var buf = [UInt8](repeating: 0, count: maxBytes)
        let n = read(fd, &buf, maxBytes)
        if n > 0 {
            return String(bytes: buf.prefix(n), encoding: .utf8) ?? String(bytes: buf.prefix(n), encoding: .ascii)
        }
        return nil
    }

    // Basic service mapping for common ports
    private func serviceName(for port: Int) -> String {
        switch port {
        case 20,21: return "ftp"
        case 22: return "ssh"
        case 23: return "telnet"
        case 25: return "smtp"
        case 53: return "dns"
        case 67,68: return "dhcp"
        case 69: return "tftp"
        case 80: return "http"
        case 110: return "pop3"
        case 111: return "rpcbind"
        case 123: return "ntp"
        case 135: return "epmap"
        case 137,138,139: return "netbios"
        case 143: return "imap"
        case 161: return "snmp"
        case 389: return "ldap"
        case 443: return "https"
        case 445: return "smb"
        case 465: return "smtps"
        case 500: return "isakmp"
        case 514: return "syslog"
        case 515: return "printer"
        case 587: return "submission"
        case 631: return "ipp"
        case 993: return "imaps"
        case 995: return "pop3s"
        case 1080: return "socks"
        case 1433: return "mssql"
        case 1521: return "oracle"
        case 1723: return "pptp"
        case 2049: return "nfs"
        case 2181: return "zookeeper"
        case 2375,2376: return "docker"
        case 2483,2484: return "oracle"
        case 3000: return "http-alt"
        case 3306: return "mysql"
        case 3389: return "rdp"
        case 3690: return "svn"
        case 4369: return "epmd"
        case 5000: return "upnp/http"
        case 5432: return "postgres"
        case 5672: return "amqp"
        case 5900: return "vnc"
        case 5984: return "couchdb"
        case 6379: return "redis"
        case 6667: return "irc"
        case 7001,7002: return "http-alt"
        case 8000,8008: return "http-alt"
        case 8080,8081: return "http-proxy"
        case 8443: return "https-alt"
        case 8888: return "http-alt"
        case 9000: return "svc"
        case 9042: return "cassandra"
        case 9200: return "elasticsearch"
        case 9418: return "git"
        case 11211: return "memcached"
        case 27017: return "mongodb"
        default: return ""
        }
    }
}

// MARK: - fd_set helpers replacing FD_ZERO/FD_SET macros

private func fdZero(_ set: inout fd_set) {
    // fd_set is a struct with an array field fds_bits on Apple platforms.
    // Zero the whole struct memory.
    memset(&set, 0, MemoryLayout<fd_set>.size)
}

private func fdSet(_ fd: Int32, _ set: inout fd_set) {
    // Mirror of FD_SET macro: set the bit for fd.
    let intSize = MemoryLayout<Int>.size * 8
    let idx = Int(fd) / intSize
    let mask = 1 << (Int(fd) % intSize)
    withUnsafeMutablePointer(to: &set) { ptr in
        ptr.withMemoryRebound(to: Int.self, capacity: MemoryLayout<fd_set>.size / MemoryLayout<Int>.size) { ints in
            ints[idx] |= mask
        }
    }
}

// MARK: - Timeval helper

private func makeTimeval(_ timeout: TimeInterval) -> timeval {
    let secs = Int(timeout)
    let usecsDouble = (timeout - TimeInterval(secs)) * 1_000_000
    // Clamp to valid range [0, 999_999] and cast to platform C types
    let clampedUsecs = max(0, min(999_999, Int(usecsDouble.rounded())))
    return timeval(tv_sec: time_t(secs), tv_usec: suseconds_t(clampedUsecs))
}

