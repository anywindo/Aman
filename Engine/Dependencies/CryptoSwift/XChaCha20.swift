//
//  XChaCha20.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

public final class XChaCha20: BlockCipher, BlockMode {

  public enum Error: Swift.Error {
    case invalidKeyOrInitializationVector
    case notSupported
  }

  fileprivate var chacha20: ChaCha20

  // MARK: BlockCipher

  public static let blockSize = 64 

  // MARK: Cipher

  public let keySize: Int

  
  public init(key: Array<UInt8>, iv nonce: Array<UInt8>, blockCounter: UInt32 = 0) throws {
    guard key.count == 32 && nonce.count == 24 else {
      throw Error.invalidKeyOrInitializationVector
    }

    self.keySize = key.count

    
    self.chacha20 = try .init(
      key: XChaCha20.hChaCha20(key: key, nonce: Array(nonce[0..<16])),
      iv: [0, 0, 0, 0] + Array(nonce[16..<24]),
      blockCounter: blockCounter
    )
  }

  // MARK: BlockMode

 
  public let options: BlockModeOption = [.none]
  
  public let customBlockSize: Int? = nil

  public func worker(blockSize: Int, cipherOperation: @escaping CipherOperationOnBlock, encryptionOperation: @escaping CipherOperationOnBlock) throws -> CipherModeWorker {
    return XChaCha20Worker(
      blockSize: blockSize,
      cipherOperation: cipherOperation,
      xChaCha20: self
    )
  }

  
  static func hChaCha20(key: [UInt8], nonce: [UInt8]) -> [UInt8] {
    precondition(key.count == 32)
    precondition(nonce.count == 16)

   
    var state = Array<UInt32>(repeating: 0, count: 16)

    state[0] = 0x61707865
    state[1] = 0x3320646e
    state[2] = 0x79622d32
    state[3] = 0x6b206574
    for i in 0..<8 {
      state[4 + i] = UInt32(bytes: key[i * 4..<(i + 1) * 4]).bigEndian
    }
    for i in 0..<4 {
      state[12 + i] = UInt32(bytes: nonce[i * 4..<(i + 1) * 4]).bigEndian
    }

    

    for _ in 1...10 {
      self.innerBlock(&state)
    }

    

    var output = Array<UInt8>()
    for i in 0..<4 {
      output += state[i].bigEndian.bytes()
    }
    for i in 0..<4 {
      output += state[12 + i].bigEndian.bytes()
    }

    return output
  }

  
  static func qRound(_ state: inout [UInt32], _ a: Int, _ b: Int, _ c: Int, _ d: Int) {
    state[a] = state[a] &+ state[b]
    state[d] ^= state[a]
    state[d] = (state[d] << 16) | (state[d] >> 16)
    state[c] = state[c] &+ state[d]
    state[b] ^= state[c]
    state[b] = (state[b] << 12) | (state[b] >> 20)
    state[a] = state[a] &+ state[b]
    state[d] ^= state[a]
    state[d] = (state[d] << 8) | (state[d] >> 24)
    state[c] = state[c] &+ state[d]
    state[b] ^= state[c]
    state[b] = (state[b] << 7) | (state[b] >> 25)
  }

  
  static func innerBlock(_ state: inout [UInt32]) {
    self.qRound(&state, 0, 4, 8, 12)
    self.qRound(&state, 1, 5, 9, 13)
    self.qRound(&state, 2, 6, 10, 14)
    self.qRound(&state, 3, 7, 11, 15)
    self.qRound(&state, 0, 5, 10, 15)
    self.qRound(&state, 1, 6, 11, 12)
    self.qRound(&state, 2, 7, 8, 13)
    self.qRound(&state, 3, 4, 9, 14)
  }
}

// MARK: Cipher

extension XChaCha20: Cipher {
  public func encrypt(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8> {
    try self.chacha20.encrypt(bytes)
  }

  public func decrypt(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8> {
    try self.encrypt(bytes)
  }
}

// MARK: Cryptors

extension XChaCha20: Cryptors {

  public func makeEncryptor() throws -> Cryptor & Updatable {
    return try BlockEncryptor(
      blockSize: XChaCha20.blockSize,
      padding: .noPadding,
      self.worker(
        blockSize: XChaCha20.blockSize,
        cipherOperation: { _ in nil },
        encryptionOperation: { _ in nil }
      )
    )
  }

  public func makeDecryptor() throws -> Cryptor & Updatable {
    return try BlockDecryptor(
      blockSize: XChaCha20.blockSize,
      padding: .noPadding,
      self.worker(
        blockSize: XChaCha20.blockSize,
        cipherOperation: { _ in nil },
        encryptionOperation: { _ in nil }
      )
    )
  }
}

class XChaCha20Worker: CipherModeWorker {
  let blockSize: Int
  let cipherOperation: CipherOperationOnBlock
  let xChaCha20: XChaCha20

  init(blockSize: Int, cipherOperation: @escaping CipherOperationOnBlock, xChaCha20: XChaCha20) {
    self.blockSize = blockSize
    self.cipherOperation = cipherOperation
    self.xChaCha20 = xChaCha20
  }

  var additionalBufferSize: Int {
    return 0
  }

  func encrypt(block plaintext: ArraySlice<UInt8>) -> Array<UInt8> {
    return (try? self.xChaCha20.encrypt(plaintext)) ?? .init()
  }

  func decrypt(block ciphertext: ArraySlice<UInt8>) -> Array<UInt8> {
    return (try? self.xChaCha20.decrypt(ciphertext)) ?? .init()
  }
}
