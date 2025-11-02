import Foundation

enum PythonRunnerError: LocalizedError {
    case pythonNotFound
    case scriptNotFound(String)
    case executionFailed(String)
    case noOutput
    case encodingFailure

    var errorDescription: String? {
        switch self {
        case .pythonNotFound:
            return "Python 3 is not available on this system. Please install Python 3 or ensure /usr/bin/python3 exists."
        case .scriptNotFound(let name):
            return "Analyzer script not found in app resources: \(name)"
        case .executionFailed(let stderr):
            return stderr.isEmpty ? "Python script failed." : stderr
        case .noOutput:
            return "No output produced by Python script."
        case .encodingFailure:
            return "Failed to encode request JSON for Python."
        }
    }
}

final class PythonProcessRunner {
    static let shared = PythonProcessRunner()

    private static let pythonURL: URL? = {
        let preferred = URL(fileURLWithPath: "/usr/bin/python3")
        if FileManager.default.isExecutableFile(atPath: preferred.path) {
            return preferred
        }
        if let path = ProcessInfo.processInfo.environment["PATH"] {
            for component in path.split(separator: ":") {
                let candidate = URL(fileURLWithPath: String(component)).appendingPathComponent("python3")
                if FileManager.default.isExecutableFile(atPath: candidate.path) {
                    return candidate
                }
            }
        }
        return nil
    }()

    func runJSONScript<T: Decodable>(
        scriptURL: URL,
        requestJSON: Data,
        responseType: T.Type
    ) throws -> T {
        guard let python = Self.pythonURL else { throw PythonRunnerError.pythonNotFound }
        guard FileManager.default.fileExists(atPath: scriptURL.path) else {
            throw PythonRunnerError.scriptNotFound(scriptURL.lastPathComponent)
        }

        let process = Process()
        process.executableURL = python
        process.arguments = [scriptURL.path]
        let input = Pipe()
        let output = Pipe()
        let error = Pipe()
        process.standardInput = input
        process.standardOutput = output
        process.standardError = error

        try process.run()
        input.fileHandleForWriting.write(requestJSON)
        input.fileHandleForWriting.closeFile()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let stderr = String(data: error.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw PythonRunnerError.executionFailed(stderr.trimmingCharacters(in: .whitespacesAndNewlines))
        }

        let data = output.fileHandleForReading.readDataToEndOfFile()
        if data.isEmpty { throw PythonRunnerError.noOutput }

        let decoder = JSONDecoder.iso8601Fractional()
        return try decoder.decode(T.self, from: data)
    }
}
