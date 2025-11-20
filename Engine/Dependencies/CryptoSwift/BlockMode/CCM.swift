// 
//  [CCM].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(WASILibc)
import WASILibc
#endif

public struct CCM: StreamMode {
  public enum Error: Swift.Error {
    case invalidInitializationVector
    case invalidParameter
    case fail
  }

  public let options: BlockModeOption = [.initializationVectorRequired, .useEncryptToDecrypt]
  private let nonce: Array<UInt8>
  private let additionalAuthenticatedData: Array<UInt8>?
  private let tagLength: Int
  private let messageLength: Int 
  public let customBlockSize: Int? = nil


  public var authenticationTag: Array<UInt8>?


  public init(iv: Array<UInt8>, tagLength: Int, messageLength: Int, additionalAuthenticatedData: Array<UInt8>? = nil) {
    self.nonce = iv
    self.tagLength = tagLength
    self.additionalAuthenticatedData = additionalAuthenticatedData
    self.messageLength = messageLength 
  }


  public init(iv: Array<UInt8>, tagLength: Int, messageLength: Int, authenticationTag: Array<UInt8>, additionalAuthenticatedData: Array<UInt8>? = nil) {
    self.init(iv: iv, tagLength: tagLength, messageLength: messageLength, additionalAuthenticatedData: additionalAuthenticatedData)
    self.authenticationTag = authenticationTag
  }

  public func worker(blockSize: Int, cipherOperation: @escaping CipherOperationOnBlock, encryptionOperation: @escaping CipherOperationOnBlock) throws -> CipherModeWorker {
    if self.nonce.isEmpty {
      throw Error.invalidInitializationVector
    }

    return CCMModeWorker(blockSize: blockSize, nonce: self.nonce.slice, messageLength: self.messageLength, additionalAuthenticatedData: self.additionalAuthenticatedData, tagLength: self.tagLength, cipherOperation: cipherOperation)
  }
}

class CCMModeWorker: StreamModeWorker, SeekableModeWorker, CounterModeWorker, FinalizingEncryptModeWorker, FinalizingDecryptModeWorker {
  typealias Counter = Int
  var counter = 0

  let cipherOperation: CipherOperationOnBlock
  let blockSize: Int
  private let tagLength: Int
  private let messageLength: Int 
  private let q: UInt8

  let additionalBufferSize: Int
  private var keystreamPosIdx = 0
  private let nonce: Array<UInt8>
  private var last_y: ArraySlice<UInt8> = []
  private var keystream: Array<UInt8> = []
  private var expectedTag: Array<UInt8>?

  public enum Error: Swift.Error {
    case invalidParameter
  }

  init(blockSize: Int, nonce: ArraySlice<UInt8>, messageLength: Int, additionalAuthenticatedData: [UInt8]?, expectedTag: Array<UInt8>? = nil, tagLength: Int, cipherOperation: @escaping CipherOperationOnBlock) {
    self.blockSize = 16 
    self.tagLength = tagLength
    self.additionalBufferSize = tagLength
    self.messageLength = messageLength
    self.expectedTag = expectedTag
    self.cipherOperation = cipherOperation
    self.nonce = Array(nonce)
    self.q = UInt8(15 - nonce.count) 

    let hasAssociatedData = additionalAuthenticatedData != nil && !additionalAuthenticatedData!.isEmpty
    self.processControlInformation(nonce: self.nonce, tagLength: tagLength, hasAssociatedData: hasAssociatedData)

    if let aad = additionalAuthenticatedData, hasAssociatedData {
      self.process(aad: aad)
    }
  }

  private func processControlInformation(nonce: [UInt8], tagLength: Int, hasAssociatedData: Bool) {
    let block0 = try! format(nonce: nonce, Q: UInt32(self.messageLength), q: self.q, t: UInt8(tagLength), hasAssociatedData: hasAssociatedData).slice
    let y0 = self.cipherOperation(block0)!.slice
    self.last_y = y0
  }

  private func process(aad: [UInt8]) {
    let encodedAAD = format(aad: aad)

    for block_i in encodedAAD.batched(by: 16) {
      let y_i = self.cipherOperation(xor(block_i, self.last_y))!.slice
      self.last_y = y_i
    }
  }

  private func S(i: Int) throws -> [UInt8] {
    let ctr = try format(counter: i, nonce: nonce, q: q)
    return self.cipherOperation(ctr.slice)!
  }

  @inlinable
  func seek(to position: Int) throws {
    self.counter = position
    self.keystream = try self.S(i: position)
    let offset = position % self.blockSize
    self.keystreamPosIdx = offset
  }

  func encrypt(block plaintext: ArraySlice<UInt8>) -> Array<UInt8> {
    var result = Array<UInt8>(reserveCapacity: plaintext.count)

    var processed = 0
    while processed < plaintext.count {
      if self.keystream.isEmpty || self.keystreamPosIdx == self.blockSize {
        self.counter += 1
        guard let S = try? S(i: counter) else { return Array(plaintext) }
        let plaintextP = addPadding(Array(plaintext), blockSize: blockSize)
        guard let y = cipherOperation(xor(last_y, plaintextP)) else { return Array(plaintext) }
        self.last_y = y.slice

        self.keystream = S
        self.keystreamPosIdx = 0
      }

      let xored: Array<UInt8> = xor(plaintext[plaintext.startIndex.advanced(by: processed)...], keystream[keystreamPosIdx...])
      keystreamPosIdx += xored.count
      processed += xored.count
      result += xored
    }
    return result
  }

  @inlinable
  func finalize(encrypt ciphertext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {
    guard let S0 = try? S(i: 0) else { return ciphertext }

    let computedTag = xor(last_y.prefix(self.tagLength), S0) as ArraySlice<UInt8>
    return ciphertext + computedTag
  }


  private var accumulatedPlaintext: [UInt8] = []

  func decrypt(block ciphertext: ArraySlice<UInt8>) -> Array<UInt8> {
    var output = Array<UInt8>(reserveCapacity: ciphertext.count)

    do {
      var currentCounter = self.counter
      var processed = 0
      while processed < ciphertext.count {

        if self.keystream.isEmpty || self.keystreamPosIdx == self.blockSize {
          currentCounter += 1
          guard let S = try? S(i: currentCounter) else { return Array(ciphertext) }
          self.keystream = S
          self.keystreamPosIdx = 0
        }

        let xored: Array<UInt8> = xor(ciphertext[ciphertext.startIndex.advanced(by: processed)...], keystream[keystreamPosIdx...]) // plaintext
        keystreamPosIdx += xored.count
        processed += xored.count
        output += xored
        self.counter = currentCounter
      }
    }


    self.accumulatedPlaintext += output

    return output
  }

  @inlinable
  func finalize(decrypt plaintext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {
    let computedTag = Array(last_y.prefix(self.tagLength))
    guard let expectedTag = self.expectedTag, expectedTag == computedTag else {
      throw CCM.Error.fail
    }

    return plaintext
  }

  @discardableResult
  func willDecryptLast(bytes ciphertext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {

    guard let S0 = try? S(i: 0) else { return ciphertext }
    self.expectedTag = xor(ciphertext.suffix(self.tagLength), S0) as [UInt8]
    return ciphertext[ciphertext.startIndex..<ciphertext.endIndex.advanced(by: -Swift.min(tagLength, ciphertext.count))]
  }

  @inlinable
  func didDecryptLast(bytes plaintext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {

    var processed = 0
    for block in self.accumulatedPlaintext.batched(by: self.blockSize) {
      let blockP = addPadding(Array(block), blockSize: blockSize)
      guard let y = cipherOperation(xor(last_y, blockP)) else { return plaintext }
      self.last_y = y.slice
      processed += block.count
    }
    self.accumulatedPlaintext.removeFirst(processed)
    return plaintext
  }
}


private func format(nonce N: [UInt8], Q: UInt32, q: UInt8, t: UInt8, hasAssociatedData: Bool) throws -> [UInt8] {
  var flags0: UInt8 = 0

  if hasAssociatedData {
    flags0 |= (1 << 6)
  }

  flags0 |= (((t - 2) / 2) & 0x07) << 3

  flags0 |= ((q - 1) & 0x07) << 0

  var block0: [UInt8] = Array<UInt8>(repeating: 0, count: 16)
  block0[0] = flags0


  let n = 15 - Int(q)
  guard (n + Int(q)) == 15 else {
    throw CCMModeWorker.Error.invalidParameter
  }
  block0[1...n] = N[0...(n - 1)]

  block0[(16 - Int(q))...15] = Q.bytes(totalBytes: Int(q)).slice

  return block0
}

private func format(counter i: Int, nonce N: [UInt8], q: UInt8) throws -> [UInt8] {
  var flags0: UInt8 = 0

  flags0 |= ((q - 1) & 0x07) << 0

  var block = Array<UInt8>(repeating: 0, count: 16) // block[0]
  block[0] = flags0


  let n = 15 - Int(q)
  guard (n + Int(q)) == 15 else {
    throw CCMModeWorker.Error.invalidParameter
  }
  block[1...n] = N[0...(n - 1)]

  block[(16 - Int(q))...15] = i.bytes(totalBytes: Int(q)).slice

  return block
}

private func format(aad: [UInt8]) -> [UInt8] {
  let a = aad.count

  switch Double(a) {
    case 0..<65280:
      return addPadding(a.bytes(totalBytes: 2) + aad, blockSize: 16)
    case 65280..<4_294_967_296:
      return addPadding([0xFF, 0xFE] + a.bytes(totalBytes: 4) + aad, blockSize: 16)
    case 4_294_967_296..<pow(2, 64):
      return addPadding([0xFF, 0xFF] + a.bytes(totalBytes: 8) + aad, blockSize: 16)
    default:
      return addPadding(aad, blockSize: 16)
  }
}


private func addPadding(_ bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
  if bytes.isEmpty {
    return Array<UInt8>(repeating: 0, count: blockSize)
  }

  let remainder = bytes.count % blockSize
  if remainder == 0 {
    return bytes
  }

  let paddingCount = blockSize - remainder
  if paddingCount > 0 {
    return bytes + Array<UInt8>(repeating: 0, count: paddingCount)
  }
  return bytes
}
