//
//  NetworkingCheckTests.swift
//  Aman - Tests
//
//  Created by Aman Team on 08/11/25
//

import XCTest
import Foundation
@testable import Aman

final class PortListeningInventoryCheckTests: XCTestCase {
    func testParseListeningSocketsFiltersListenLines() {
        let check = PortListeningInventoryCheck()
        let sampleOutput = """
        Active Internet connections (including servers)
        Proto Local Address          Foreign Address        (state)
        tcp4  127.0.0.1.62078        *.*                    LISTEN
        tcp4  127.0.0.1.5000         *.*                    LISTEN
        tcp4  127.0.0.1.49152        127.0.0.1.62078        ESTABLISHED
        """
        let sockets = check.parseListeningSockets(from: sampleOutput)
        XCTAssertEqual(sockets.count, 2)
        XCTAssertTrue(sockets.allSatisfy { $0.localizedCaseInsensitiveContains("listen") })
    }

    func testCheckMarksGreenWhenNoListeningSockets() {
        let result = ShellCommandResult(stdout: "no listeners here", stderr: "", terminationStatus: 0)
        let check = PortListeningInventoryCheck(executor: StubShellRunner(result: .success(result)))
        check.check()
        XCTAssertEqual(check.checkstatus, "Green")
        XCTAssertEqual(check.status, "No listening TCP ports detected.")
    }

    func testCheckMarksYellowWhenSocketsFound() {
        let result = ShellCommandResult(
            stdout: "tcp4  127.0.0.1.62078        *.*                    LISTEN\n",
            stderr: "",
            terminationStatus: 0
        )
        let check = PortListeningInventoryCheck(executor: StubShellRunner(result: .success(result)))
        check.check()
        XCTAssertEqual(check.checkstatus, "Yellow")
        XCTAssertTrue(check.status?.contains("Listening sockets detected") ?? false)
    }

    func testCheckHandlesExecutorFailure() {
        let check = PortListeningInventoryCheck(executor: StubShellRunner(result: .failure(MockError.executionFailed)))
        check.check()
        XCTAssertEqual(check.checkstatus, "Yellow")
        XCTAssertTrue(check.status?.contains("Unable to run netstat") ?? false)
    }
}

private struct StubShellRunner: ShellCommandRunning {
    let result: Result<ShellCommandResult, Error>

    func run(executableURL: URL, arguments: [String]) throws -> ShellCommandResult {
        switch result {
        case .success(let output):
            return output
        case .failure(let error):
            throw error
        }
    }
}

private enum MockError: Error {
    case executionFailed
}
