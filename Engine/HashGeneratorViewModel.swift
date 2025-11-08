//
//  HashGeneratorViewModel.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation
import CryptoKit

@MainActor
final class HashGeneratorViewModel: ObservableObject {
    enum InputMode: String, CaseIterable, Identifiable {
        case text
        case file

        var id: String { rawValue }

        var title: String {
            switch self {
            case .text: return "Text"
            case .file: return "File"
            }
        }
    }

    struct HashResult: Identifiable {
        let algorithm: HashAlgorithm
        let outcome: Outcome

        var id: HashAlgorithm { algorithm }

        enum Outcome {
            case digest(String)
            case failure(String)

            var displayString: String {
                switch self {
                case .digest(let value): return value
                case .failure(let message): return message
                }
            }

            var isFailure: Bool {
                if case .failure = self { return true }
                return false
            }
        }
    }

    @Published var inputMode: InputMode = .text
    @Published var textInput: String = ""
    @Published var fileURL: URL?
    enum Selection: Hashable {
        case single(HashAlgorithm)
        case all
    }

    @Published private(set) var results: [HashResult] = []
    @Published private(set) var isProcessing = false
    @Published var error: String?
    @Published var selection: Selection = .single(.sha256)

    private let hasher = HashingService()

    func setFileURL(_ url: URL?) {
        fileURL = url
    }

    func setSelection(_ newSelection: Selection) {
        selection = newSelection
    }

    func clear() {
        textInput = ""
        fileURL = nil
        results = []
        error = nil
        selection = .single(.sha256)
    }

    func generate() {
        error = nil

        guard let dataSource = prepareInput() else {
            results = []
            return
        }

        isProcessing = true
        let orderedAlgorithms: [HashAlgorithm]
        switch selection {
        case .all:
            orderedAlgorithms = HashAlgorithm.ordered
        case .single(let algorithm):
            orderedAlgorithms = [algorithm]
        }

        Task {
            do {
                let digests = try await hasher.computeDigests(for: orderedAlgorithms, input: dataSource)
                let mappedResults = orderedAlgorithms.map { algorithm -> HashResult in
                    switch digests[algorithm] {
                    case .success(let digest):
                        return HashResult(algorithm: algorithm, outcome: .digest(digest))
                    case .failure(let error):
                        return HashResult(
                            algorithm: algorithm,
                            outcome: .failure(error.localizedDescription)
                        )
                    case .none:
                        return HashResult(
                            algorithm: algorithm,
                            outcome: .failure("No output produced.")
                        )
                    }
                }
                await updateResults(mappedResults)
            } catch {
                await handleError(error)
            }
        }
    }

    private func prepareInput() -> HashingService.Input? {
        switch inputMode {
        case .text:
            let trimmed = textInput
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty,
                  let data = trimmed.data(using: .utf8) else {
                error = "Provide text to hash."
                return nil
            }
            return .data(data)
        case .file:
            guard let url = fileURL else {
                error = "Select a file to hash."
                return nil
            }
            return .file(url)
        }
    }

    @MainActor
    private func updateResults(_ ordered: [HashResult]) {
        self.results = ordered
        self.isProcessing = false
    }

    @MainActor
    private func handleError(_ error: Error) {
        self.error = error.localizedDescription
        self.results = []
        self.isProcessing = false
    }
}

enum HashAlgorithm: CaseIterable, Identifiable, Hashable {
    case sha3_512
    case sha512
    case blake3
    case blake2b
    case sha3_256
    case sha256
    case whirlpool
    case ripemd160
    case sha1
    case md5

    var id: String { displayName }

    var displayName: String {
        switch self {
        case .sha3_512: return "SHA3-512 (Keccak)"
        case .sha512: return "SHA-512"
        case .blake3: return "BLAKE3"
        case .blake2b: return "BLAKE2b"
        case .sha3_256: return "SHA3-256"
        case .sha256: return "SHA-256"
        case .whirlpool: return "Whirlpool"
        case .ripemd160: return "RIPEMD-160"
        case .sha1: return "SHA-1"
        case .md5: return "MD5"
        }
    }

    var explanation: String {
        switch self {
        case .sha3_512:
            return "Modern 512-bit member of the SHA-3 Keccak sponge family, resistant to length-extension attacks."
        case .sha512:
            return "Wide 512-bit digest from the SHA-2 family, still widely trusted for integrity checks."
        case .blake3:
            return "Fast parallel hash combining BLAKE2 and Merkle tree ideas, tuned for modern CPUs."
        case .blake2b:
            return "512-bit BLAKE2b is a speedy alternative to SHA-2 with built-in keyed hashing support (computed via Python's hashlib)."
        case .sha3_256:
            return "256-bit Keccak digest using sponge construction, offering SHA-3 security in a smaller output (requires Python 3)."
        case .sha256:
            return "The workhorse of SHA-2 with a 256-bit digest, used in TLS, software distribution, and blockchains."
        case .whirlpool:
            return "512-bit ISO/IEC standard hash built on an AES-like block cipher design by Barreto and Rijmen."
        case .ripemd160:
            return "160-bit legacy hash favored by early PGP tools and Bitcoin address generation (via Python's hashlib)."
        case .sha1:
            return "160-bit SHA-1, considered broken for collision resistance but still seen in older systems."
        case .md5:
            return "128-bit MD5, obsolete but useful for quick integrity checks on legacy data."
        }
    }

    var pythonIdentifier: String? {
        switch self {
        case .sha3_512: return "sha3_512"
        case .sha512: return "sha512"
        case .blake3: return nil
        case .blake2b: return "blake2b"
        case .sha3_256: return "sha3_256"
        case .sha256: return "sha256"
        case .whirlpool: return nil
        case .ripemd160: return "ripemd160"
        case .sha1: return "sha1"
        case .md5: return "md5"
        }
    }

    var digestBitLength: Int {
        switch self {
        case .sha3_512, .sha512, .whirlpool, .blake2b:
            return 512
        case .sha3_256, .sha256, .blake3:
            return 256
        case .ripemd160, .sha1:
            return 160
        case .md5:
            return 128
        }
    }

    var normalizedStrength: Double {
        Double(digestBitLength) / 512.0
    }

    static var ordered: [HashAlgorithm] {
        Self.allCases.sorted { $0.displayName < $1.displayName }
    }
}

final class HashingService {
    enum Input {
        case data(Data)
        case file(URL)
    }

    func computeDigests(
        for algorithms: [HashAlgorithm],
        input: Input
    ) async throws -> [HashAlgorithm: Result<String, HashingError>] {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let data = try self.loadData(from: input)
                    var outputs: [HashAlgorithm: Result<String, HashingError>] = [:]
                    for algorithm in algorithms {
                        do {
                            let digest = try self.computeDigest(for: algorithm, data: data)
                            outputs[algorithm] = .success(digest)
                        } catch let error as HashingError {
                            outputs[algorithm] = .failure(error)
                        } catch {
                            outputs[algorithm] = .failure(.unknown)
                        }
                    }
                    continuation.resume(returning: outputs)
                } catch let error as HashingError {
                    let failures: [HashAlgorithm: Result<String, HashingError>] =
                        Dictionary(uniqueKeysWithValues: algorithms.map { ($0, Result<String, HashingError>.failure(error)) })
                    continuation.resume(returning: failures)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadData(from input: Input) throws -> Data {
        switch input {
        case .data(let data):
            return data
        case .file(let url):
            var needsStop = false
            if url.startAccessingSecurityScopedResource() {
                needsStop = true
            }
            defer {
                if needsStop {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            return try Data(contentsOf: url)
        }
    }

    private func computeDigest(for algorithm: HashAlgorithm, data: Data) throws -> String {
        if let ccDigest = commonCryptoDigest(for: algorithm, data: data) {
            return ccDigest
        }

        switch algorithm {
        case .blake3:
            return computeBLAKE3Digest(data: data)
        case .whirlpool:
            return computeWhirlpoolDigest(data: data)
        case .sha3_256:
            return try computeSHA3Digest(bits: 256, data: data)
        case .sha3_512:
            return try computeSHA3Digest(bits: 512, data: data)
        case .blake2b:
            return try computeBLAKE2bDigest(data: data)
        case .ripemd160:
            return try computeRIPEMD160Digest(data: data)
        default:
            throw HashingError.algorithmUnavailable("Algorithm not supported on this system.")
        }
    }

    private func commonCryptoDigest(for algorithm: HashAlgorithm, data: Data) -> String? {
        switch algorithm {
        case .md5:
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            data.withUnsafeBytes { CC_MD5($0.baseAddress, CC_LONG(data.count), &hash) }
            return hexString(from: hash)
        case .sha1:
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))
            data.withUnsafeBytes { CC_SHA1($0.baseAddress, CC_LONG(data.count), &hash) }
            return hexString(from: hash)
        case .sha256:
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
            data.withUnsafeBytes { CC_SHA256($0.baseAddress, CC_LONG(data.count), &hash) }
            return hexString(from: hash)
        case .sha512:
            var hash = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
            data.withUnsafeBytes { CC_SHA512($0.baseAddress, CC_LONG(data.count), &hash) }
            return hexString(from: hash)
        default:
            return nil
        }
    }

    private func computeBLAKE3Digest(data: Data) -> String {
        var hasher = BLAKE3()
        hasher.absorb(contentsOf: data)
        let digest = hasher.squeeze(outputByteCount: 32)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func computeWhirlpoolDigest(data: Data) -> String {
        var whirlpool = Whirlpool()
        whirlpool.update(data: data)
        let digest = whirlpool.finalize()
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func computeSHA3Digest(bits: Int, data: Data) throws -> String {
        let identifier = bits == 256 ? "sha3_256" : "sha3_512"
        return try pythonDigest(identifier: identifier, data: data)
    }

    private func computeBLAKE2bDigest(data: Data) throws -> String {
        return try pythonDigest(identifier: "blake2b", data: data)
    }

    private func computeRIPEMD160Digest(data: Data) throws -> String {
        return try pythonDigest(identifier: "ripemd160", data: data)
    }

    private func pythonDigest(identifier: String, data: Data) throws -> String {
        guard let pythonURL = Self.pythonURL else {
            throw HashingError.algorithmUnavailable("Python 3 with hashlib support is required for \(identifier.uppercased()).")
        }

        let script = """
import sys, hashlib, base64
algo = sys.argv[1]
payload = base64.b64decode(sys.stdin.buffer.read())
try:
    if hasattr(hashlib, algo):
        hasher = getattr(hashlib, algo)()
        hasher.update(payload)
    else:
        hasher = hashlib.new(algo, payload)
except Exception as exc:
    sys.stderr.write(str(exc))
    sys.exit(2)
sys.stdout.write(hasher.hexdigest())
"""

        let process = Process()
        process.executableURL = pythonURL
        process.arguments = ["-c", script, identifier]

        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        try process.run()

        let base64String = data.base64EncodedString()
        if let encoded = (base64String + "\n").data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(encoded)
        }
        inputPipe.fileHandleForWriting.closeFile()

        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            let errorMessage = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            throw HashingError.algorithmUnavailable(errorMessage.isEmpty ? "Python environment does not support \(identifier.uppercased())." : errorMessage)
        }

        let output = outputPipe.fileHandleForReading.readDataToEndOfFile()
        guard let digest = String(data: output, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines), !digest.isEmpty else {
            throw HashingError.algorithmUnavailable("No output produced for \(identifier.uppercased()).")
        }
        return digest
    }

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

    private func hexString(from bytes: [UInt8]) -> String {
        bytes.map { String(format: "%02x", $0) }.joined()
    }

    enum HashingError: LocalizedError {
        case algorithmUnavailable(String)
        case unknown

        var errorDescription: String? {
            switch self {
            case .algorithmUnavailable(let note):
                return note
            case .unknown:
                return "Unexpected error while computing the hash."
            }
        }
    }
}
