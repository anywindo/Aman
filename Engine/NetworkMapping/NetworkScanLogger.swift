// 
//  [NetworkScanLogger].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
//

import Foundation
import OSLog

final class NetworkScanLogger {
    enum Event {
        case portResult(ip: String, port: UInt16, state: PortScanState, latency: TimeInterval)
        case probeError(ip: String, port: UInt16, description: String)
        case synModeUnavailable(ip: String)
        case scanStarted(ip: String, mode: PortScanMode, totalPorts: Int)
        case scanCompleted(ip: String, duration: TimeInterval, openPorts: Int)
        case scanCancelled(ip: String)
        case scanFailed(ip: String, message: String)
    }

    static let shared = NetworkScanLogger()

    private let logger = Logger(subsystem: "com.aman.network", category: "NetworkMapping")

    private init() {}

    func log(event: Event) {
        switch event {
        case let .portResult(ip, port, state, latency):
            logger.log("Port scan \(ip, privacy: .public):\(port) state=\(state.rawValue, privacy: .public) latency=\(latency, format: .fixed(precision: 4))s")
        case let .probeError(ip, port, description):
            logger.error("Probe error \(ip, privacy: .public):\(port) reason=\(description, privacy: .public)")
        case let .synModeUnavailable(ip):
            logger.warning("SYN mode requested without privileges for host \(ip, privacy: .public)")
        case let .scanStarted(ip, mode, total):
            logger.log("Port scan started host=\(ip, privacy: .public) mode=\(mode.rawValue, privacy: .public) total_ports=\(total)")
        case let .scanCompleted(ip, duration, openPorts):
            logger.log("Port scan completed host=\(ip, privacy: .public) duration=\(duration, format: .fixed(precision: 3))s open_ports=\(openPorts)")
        case let .scanCancelled(ip):
            logger.log("Port scan cancelled host=\(ip, privacy: .public)")
        case let .scanFailed(ip, message):
            logger.error("Port scan failed host=\(ip, privacy: .public) reason=\(message, privacy: .public)")
        }
    }
}
