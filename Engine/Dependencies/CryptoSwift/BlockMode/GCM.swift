// 
//  [GCM].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public final class GCM: BlockMode {
  public enum Mode {
    case combined
    case detached
  }

  public let options: BlockModeOption = [.initializationVectorRequired, .useEncryptToDecrypt]

  public enum Error: Swift.Error {
    case invalidInitializationVector
    case fail
  }

  private let iv: Array<UInt8>
  private let additionalAuthenticatedData: Array<UInt8>?
  private let mode: Mode
  public let customBlockSize: Int? = nil

  private let tagLength: Int


  public var authenticationTag: Array<UInt8>?


  public init(iv: Array<UInt8>, additionalAuthenticatedData: Array<UInt8>? = nil, tagLength: Int = 16, mode: Mode = .detached) {
    self.iv = iv
    self.additionalAuthenticatedData = additionalAuthenticatedData
    self.mode = mode
    self.tagLength = tagLength
  }


  public convenience init(iv: Array<UInt8>, authenticationTag: Array<UInt8>, additionalAuthenticatedData: Array<UInt8>? = nil, mode: Mode = .detached) {
    self.init(iv: iv, additionalAuthenticatedData: additionalAuthenticatedData, tagLength: authenticationTag.count, mode: mode)
    self.authenticationTag = authenticationTag
  }

  public func worker(blockSize: Int, cipherOperation: @escaping CipherOperationOnBlock, encryptionOperation: @escaping CipherOperationOnBlock) throws -> CipherModeWorker {
    if self.iv.isEmpty {
      throw Error.invalidInitializationVector
    }

    let worker = GCMModeWorker(iv: iv.slice, aad: self.additionalAuthenticatedData?.slice, expectedTag: self.authenticationTag, tagLength: self.tagLength, mode: self.mode, cipherOperation: cipherOperation)
    worker.didCalculateTag = { [weak self] tag in
      self?.authenticationTag = tag
    }
    return worker
  }
}

// MARK: - Worker

final class GCMModeWorker: BlockModeWorker, FinalizingEncryptModeWorker, FinalizingDecryptModeWorker {
  let cipherOperation: CipherOperationOnBlock

  var didCalculateTag: ((Array<UInt8>) -> Void)?

  private let tagLength: Int
  private static let nonceSize = 12

  let blockSize = 16
  let additionalBufferSize: Int
  private let iv: ArraySlice<UInt8>
  private let mode: GCM.Mode
  private var counter: UInt128
  private let eky0: UInt128 
  private let h: UInt128

  private let aad: ArraySlice<UInt8>?
  private var expectedTag: Array<UInt8>?

 
  private lazy var gf: GF = {
    if let aad = aad {
      return GF(aad: Array(aad), h: h, blockSize: blockSize)
    }
    return GF(aad: [UInt8](), h: h, blockSize: blockSize)
  }()

  init(iv: ArraySlice<UInt8>, aad: ArraySlice<UInt8>? = nil, expectedTag: Array<UInt8>? = nil, tagLength: Int, mode: GCM.Mode, cipherOperation: @escaping CipherOperationOnBlock) {
    self.cipherOperation = cipherOperation
    self.iv = iv
    self.mode = mode
    self.aad = aad
    self.expectedTag = expectedTag
    self.tagLength = tagLength
    self.h = UInt128(cipherOperation(Array<UInt8>(repeating: 0, count: self.blockSize).slice)!) // empty block

    if mode == .combined {
      self.additionalBufferSize = tagLength
    } else {
      self.additionalBufferSize = 0
    }


    if iv.count == GCMModeWorker.nonceSize {
      self.counter = makeCounter(nonce: Array(self.iv))
    } else {
      self.counter = GF.ghash(h: self.h, aad: [UInt8](), ciphertext: Array(iv), blockSize: self.blockSize)
    }

    self.eky0 = UInt128(cipherOperation(self.counter.bytes.slice)!)
  }

  func encrypt(block plaintext: ArraySlice<UInt8>) -> Array<UInt8> {
    self.counter = incrementCounter(self.counter)

    guard let ekyN = cipherOperation(counter.bytes.slice) else {
      return Array(plaintext)
    }

    let ciphertext = xor(plaintext, ekyN) as Array<UInt8>

    gf.ghashUpdate(block: ciphertext)

    return Array(ciphertext)
  }

  @inlinable
  func finalize(encrypt ciphertext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {
    let ghash = self.gf.ghashFinish()
    let tag = Array((ghash ^ self.eky0).bytes.prefix(self.tagLength))

    self.didCalculateTag?(tag)

    switch self.mode {
      case .combined:
        return (ciphertext + tag).slice
      case .detached:
        return ciphertext
    }
  }

  @inlinable
  func decrypt(block ciphertext: ArraySlice<UInt8>) -> Array<UInt8> {
    self.counter = incrementCounter(self.counter)

    self.gf.ghashUpdate(block: Array(ciphertext))

    guard let ekN = cipherOperation(counter.bytes.slice) else {
      return Array(ciphertext)
    }

    let plaintext = xor(ciphertext, ekN) as Array<UInt8>
    return plaintext
  }


  @discardableResult
  func willDecryptLast(bytes ciphertext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {
    switch self.mode {
      case .combined:
        self.expectedTag = Array(ciphertext.suffix(self.tagLength))
        return ciphertext[ciphertext.startIndex..<ciphertext.endIndex.advanced(by: -Swift.min(tagLength, ciphertext.count))]
      case .detached:
        return ciphertext
    }
  }

  @inlinable
  func didDecryptLast(bytes plaintext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {
    let ghash = self.gf.ghashFinish()
    let computedTag = Array((ghash ^ self.eky0).bytes.prefix(self.tagLength))

    guard let expectedTag = self.expectedTag, computedTag == expectedTag else {
      throw GCM.Error.fail
    }

    return plaintext
  }

  func finalize(decrypt plaintext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {
    plaintext
  }
}

// MARK: - Local utils

private func makeCounter(nonce: Array<UInt8>) -> UInt128 {
  UInt128(nonce + [0, 0, 0, 1])
}

private func incrementCounter(_ counter: UInt128) -> UInt128 {
  let b = counter.i.b + 1
  let a = (b == 0 ? counter.i.a + 1 : counter.i.a)
  return UInt128((a, b))
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

// MARK: - GF

private final class GF {
  static let r = UInt128(a: 0xE100000000000000, b: 0)

  let blockSize: Int
  let h: UInt128

  let aadLength: Int

  var ciphertextLength: Int

]  var x: UInt128

  init(aad: [UInt8], h: UInt128, blockSize: Int) {
    self.blockSize = blockSize
    self.aadLength = aad.count
    self.ciphertextLength = 0
    self.h = h
    self.x = 0

    self.x = GF.calculateX(aad: aad, x: self.x, h: h, blockSize: blockSize)
  }

  @discardableResult
  func ghashUpdate(block ciphertextBlock: Array<UInt8>) -> UInt128 {
    self.ciphertextLength += ciphertextBlock.count
    self.x = GF.calculateX(block: addPadding(ciphertextBlock, blockSize: self.blockSize), x: self.x, h: self.h, blockSize: self.blockSize)
    return self.x
  }

  func ghashFinish() -> UInt128 {
    let len = UInt128(a: UInt64(aadLength * 8), b: UInt64(ciphertextLength * 8))
    x = GF.multiply(self.x ^ len, self.h)
    return self.x
  }

  static func ghash(x startx: UInt128 = 0, h: UInt128, aad: Array<UInt8>, ciphertext: Array<UInt8>, blockSize: Int) -> UInt128 {
    var x = self.calculateX(aad: aad, x: startx, h: h, blockSize: blockSize)
    x = self.calculateX(ciphertext: ciphertext, x: x, h: h, blockSize: blockSize)

    let len = UInt128(a: UInt64(aad.count * 8), b: UInt64(ciphertext.count * 8))
    x = self.multiply(x ^ len, h)

    return x
  }


  private static func calculateX(ciphertext: [UInt8], x startx: UInt128, h: UInt128, blockSize: Int) -> UInt128 {
    let pciphertext = addPadding(ciphertext, blockSize: blockSize)
    let blocksCount = pciphertext.count / blockSize

    var x = startx
    for i in 0..<blocksCount {
      let cpos = i * blockSize
      let block = pciphertext[pciphertext.startIndex.advanced(by: cpos)..<pciphertext.startIndex.advanced(by: cpos + blockSize)]
      x = self.calculateX(block: Array(block), x: x, h: h, blockSize: blockSize)
    }
    return x
  }

  private static func calculateX(block ciphertextBlock: Array<UInt8>, x: UInt128, h: UInt128, blockSize: Int) -> UInt128 {
    let k = x ^ UInt128(ciphertextBlock)
    return self.multiply(k, h)
  }

  private static func calculateX(aad: [UInt8], x startx: UInt128, h: UInt128, blockSize: Int) -> UInt128 {
    let paad = addPadding(aad, blockSize: blockSize)
    let blocksCount = paad.count / blockSize

    var x = startx
    for i in 0..<blocksCount {
      let apos = i * blockSize
      let k = x ^ UInt128(paad[paad.startIndex.advanced(by: apos)..<paad.startIndex.advanced(by: apos + blockSize)])
      x = self.multiply(k, h)
    }

    return x
  }

  private static func multiply(_ x: UInt128, _ y: UInt128) -> UInt128 {
    var z: UInt128 = 0
    var v = x
    var k = UInt128(a: 1 << 63, b: 0)

    for _ in 0..<128 {
      if y & k == k {
        z = z ^ v
      }

      if v & 1 != 1 {
        v = v >> 1
      } else {
        v = (v >> 1) ^ self.r
      }

      k = k >> 1
    }

    return z
  }
}
