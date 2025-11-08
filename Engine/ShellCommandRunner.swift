//
//  ShellCommandRunner.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

struct ShellCommandResult {
    let stdout: String
    let stderr: String
    let terminationStatus: Int32
}

protocol ShellCommandRunning {
    func run(executableURL: URL, arguments: [String]) throws -> ShellCommandResult
}

struct ProcessShellRunner: ShellCommandRunning {
    func run(executableURL: URL, arguments: [String]) throws -> ShellCommandResult {
        let task = Process()
        task.executableURL = executableURL
        task.arguments = arguments

        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        task.standardOutput = stdoutPipe
        task.standardError = stderrPipe

        try task.run()
        task.waitUntilExit()

        let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
        let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

        let stdout = String(data: stdoutData, encoding: .utf8) ?? ""
        let stderr = String(data: stderrData, encoding: .utf8) ?? ""

        return ShellCommandResult(stdout: stdout, stderr: stderr, terminationStatus: task.terminationStatus)
    }
}
