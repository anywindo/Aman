// 
//  [OCB].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public final class OCB: BlockMode {

  public enum Mode {
    case combined
    case detached
  }

  public let options: BlockModeOption = [.initializationVectorRequired]

  public enum Error: Swift.Error {
    case invalidNonce
    case fail
  }

  private let N: Array<UInt8>
  private let additionalAuthenticatedData: Array<UInt8>?
  private let mode: Mode
  public let customBlockSize: Int? = nil

  private let tagLength: Int

  public var authenticationTag: Array<UInt8>?

  public init(nonce N: Array<UInt8>, additionalAuthenticatedData: Array<UInt8>? = nil, tagLength: Int = 16, mode: Mode = .detached) {
    self.N = N
    self.additionalAuthenticatedData = additionalAuthenticatedData
    self.mode = mode
    self.tagLength = tagLength
  }

  @inlinable
  public convenience init(nonce N: Array<UInt8>, authenticationTag: Array<UInt8>, additionalAuthenticatedData: Array<UInt8>? = nil, mode: Mode = .detached) {
    self.init(nonce: N, additionalAuthenticatedData: additionalAuthenticatedData, tagLength: authenticationTag.count, mode: mode)
    self.authenticationTag = authenticationTag
  }

  public func worker(blockSize: Int, cipherOperation: @escaping CipherOperationOnBlock, encryptionOperation: @escaping CipherOperationOnBlock) throws -> CipherModeWorker {
    if self.N.isEmpty || self.N.count > 15 {
      throw Error.invalidNonce
    }

    let worker = OCBModeWorker(N: N.slice, aad: self.additionalAuthenticatedData?.slice, expectedTag: self.authenticationTag, tagLength: self.tagLength, mode: self.mode, cipherOperation: cipherOperation, encryptionOperation: encryptionOperation)
    worker.didCalculateTag = { [weak self] tag in
      self?.authenticationTag = tag
    }
    return worker
  }
}

// MARK: - Worker

final class OCBModeWorker: BlockModeWorker, FinalizingEncryptModeWorker, FinalizingDecryptModeWorker {

  let cipherOperation: CipherOperationOnBlock
  var hashOperation: CipherOperationOnBlock!

  var didCalculateTag: ((Array<UInt8>) -> Void)?

  private let tagLength: Int

  let blockSize = 16
  var additionalBufferSize: Int
  private let mode: OCB.Mode

  private let aad: ArraySlice<UInt8>?
  private var expectedTag: Array<UInt8>?


  private var l = [Array<UInt8>]()
  private var lAsterisk: Array<UInt8>
  private var lDollar: Array<UInt8>


  private var mainBlockCount: UInt64
  private var offsetMain: Array<UInt8>
  private var checksum: Array<UInt8>

  init(N: ArraySlice<UInt8>, aad: ArraySlice<UInt8>? = nil, expectedTag: Array<UInt8>? = nil, tagLength: Int, mode: OCB.Mode, cipherOperation: @escaping CipherOperationOnBlock, encryptionOperation: @escaping CipherOperationOnBlock) {

    self.cipherOperation = cipherOperation
    self.hashOperation = encryptionOperation
    self.mode = mode
    self.aad = aad
    self.expectedTag = expectedTag
    self.tagLength = tagLength

    if mode == .combined {
      self.additionalBufferSize = tagLength
    } else {
      self.additionalBufferSize = 0
    }


    let zeros = Array<UInt8>(repeating: 0, count: self.blockSize)
    self.lAsterisk = self.hashOperation(zeros.slice)! 
    self.lDollar = double(self.lAsterisk) 
    self.l.append(double(self.lDollar)) 

   var nonce = Array<UInt8>(repeating: 0, count: blockSize)
    nonce[(nonce.count - N.count)...] = N
    nonce[0] = UInt8(tagLength) << 4
    nonce[blockSize - 1 - N.count] |= 1

    let bottom = nonce[15] & 0x3F

    nonce[15] &= 0xC0
    let Ktop = self.hashOperation(nonce.slice)!

    let Stretch = Ktop + xor(Ktop[0..<8], Ktop[1..<9])

    var offsetMAIN_0 = Array<UInt8>(repeating: 0, count: blockSize)
    let bits = bottom % 8
    let bytes = Int(bottom / 8)
    if bits == 0 {
      offsetMAIN_0[0..<blockSize] = Stretch[bytes..<(bytes + blockSize)]
    } else {
      for i in 0..<self.blockSize {
        let b1 = Stretch[bytes + i]
        let b2 = Stretch[bytes + i + 1]
        offsetMAIN_0[i] = ((b1 << bits) | (b2 >> (8 - bits)))
      }
    }

    self.mainBlockCount = 0
    self.offsetMain = Array<UInt8>(offsetMAIN_0.slice)
    self.checksum = Array<UInt8>(repeating: 0, count: self.blockSize) /// Checksum_0 = zeros(128)
  }

  func getLSub(_ n: Int) -> Array<UInt8> {
    while n >= self.l.count {
      self.l.append(double(self.l.last!))
    }
    return self.l[n]
  }

  func computeTag() -> Array<UInt8> {

    let sum = self.hashAAD()

    return xor(self.hashOperation(xor(xor(self.checksum, self.offsetMain).slice, self.lDollar))!, sum)
  }

  func hashAAD() -> Array<UInt8> {
    var sum = Array<UInt8>(repeating: 0, count: blockSize)

    guard let aad = self.aad else {
      return sum
    }

    var offset = Array<UInt8>(repeating: 0, count: blockSize)
    var blockCount: UInt64 = 1
    for aadBlock in aad.batched(by: self.blockSize) {

      if aadBlock.count == self.blockSize {

        offset = xor(offset, self.getLSub(ntz(blockCount)))

        sum = xor(sum, self.hashOperation(xor(aadBlock, offset))!)
      } else {
        if !aadBlock.isEmpty {

          offset = xor(offset, self.lAsterisk)

          let cipherInput: Array<UInt8> = xor(extend(aadBlock, size: blockSize), offset)

          sum = xor(sum, self.hashOperation(cipherInput.slice)!)
        }
      }
      blockCount += 1
    }

    return sum
  }

  func encrypt(block plaintext: ArraySlice<UInt8>) -> Array<UInt8> {

    if plaintext.count == self.blockSize {
      return self.processBlock(block: plaintext, forEncryption: true)
    } else {
      return self.processFinalBlock(block: plaintext, forEncryption: true)
    }
  }

  func finalize(encrypt ciphertext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {

    let tag = self.computeTag()

    self.didCalculateTag?(tag)

    switch self.mode {
      case .combined:
        return ciphertext + tag
      case .detached:
        return ciphertext
    }
  }

  func decrypt(block ciphertext: ArraySlice<UInt8>) -> Array<UInt8> {

    if ciphertext.count == self.blockSize {
      return self.processBlock(block: ciphertext, forEncryption: false)
    } else {
      return self.processFinalBlock(block: ciphertext, forEncryption: false)
    }
  }

  func finalize(decrypt plaintext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {
    plaintext
  }

  private func processBlock(block: ArraySlice<UInt8>, forEncryption: Bool) -> Array<UInt8> {

    self.mainBlockCount += 1

    self.offsetMain = xor(self.offsetMain, self.getLSub(ntz(self.mainBlockCount)))


    var mainBlock = Array<UInt8>(block)
    mainBlock = xor(mainBlock, offsetMain)
    mainBlock = self.cipherOperation(mainBlock.slice)!
    mainBlock = xor(mainBlock, self.offsetMain)

    if forEncryption {
      self.checksum = xor(self.checksum, block)
    } else {
      self.checksum = xor(self.checksum, mainBlock)
    }

    return mainBlock
  }

  private func processFinalBlock(block: ArraySlice<UInt8>, forEncryption: Bool) -> Array<UInt8> {

    let out: Array<UInt8>

    if block.isEmpty {

      out = []

    } else {

      self.offsetMain = xor(self.offsetMain, self.lAsterisk)

      let Pad = self.hashOperation(self.offsetMain.slice)!

      out = xor(block, Pad[0..<block.count])

      let plaintext = forEncryption ? block : out.slice
      self.checksum = xor(self.checksum, extend(plaintext, size: self.blockSize))
    }
    return out
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

  func didDecryptLast(bytes plaintext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8> {

    let computedTag = self.computeTag()

    guard let expectedTag = self.expectedTag, computedTag == expectedTag else {
      throw OCB.Error.fail
    }

    return plaintext
  }
}

// MARK: - Local utils

private func ntz(_ x: UInt64) -> Int {
  if x == 0 {
    return 64
  }

  var xv = x
  var n = 0
  while (xv & 1) == 0 {
    n += 1
    xv = xv >> 1
  }
  return n
}

private func double(_ block: Array<UInt8>) -> Array<UInt8> {
  var ( carry, result) = shiftLeft(block)


  result[15] ^= (0x87 >> ((1 - carry) << 3))

  return result
}

private func shiftLeft(_ block: Array<UInt8>) -> (UInt8, Array<UInt8>) {
  var output = Array<UInt8>(repeating: 0, count: block.count)

  var bit: UInt8 = 0

  for i in 0..<block.count {
    let b = block[block.count - 1 - i]
    output[block.count - 1 - i] = ((b << 1) | bit)
    bit = (b >> 7) & 1
  }
  return (bit, output)
}

private func extend(_ block: ArraySlice<UInt8>, size: Int) -> Array<UInt8> {
  var output = Array<UInt8>(repeating: 0, count: size)
  output[0..<block.count] = block
  output[block.count] |= 0x80
  return output
}
