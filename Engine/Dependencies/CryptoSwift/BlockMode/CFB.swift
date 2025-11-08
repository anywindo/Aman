// 
//  [CFB].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public struct CFB: BlockMode {
  public enum Error: Swift.Error {
    case invalidInitializationVector
  }
    
  public enum SegmentSize: Int {
    case cfb8 = 1 
    case cfb128 = 16 
  }

  public let options: BlockModeOption = [.initializationVectorRequired, .useEncryptToDecrypt]
  private let iv: Array<UInt8>
  private let segmentSize: SegmentSize
  public let customBlockSize: Int?

  public init(iv: Array<UInt8>, segmentSize: SegmentSize = .cfb128) {
    self.iv = iv
    self.segmentSize = segmentSize
    self.customBlockSize = segmentSize.rawValue
  }

  public func worker(blockSize: Int, cipherOperation: @escaping CipherOperationOnBlock, encryptionOperation: @escaping CipherOperationOnBlock) throws -> CipherModeWorker {
    if !(self.iv.count == blockSize || (segmentSize == .cfb8 && self.iv.count == AES.blockSize)) {
      throw Error.invalidInitializationVector
    }

    return CFBModeWorker(blockSize: blockSize, iv: self.iv.slice, segmentSize: segmentSize, cipherOperation: cipherOperation)
  }
}

struct CFBModeWorker: BlockModeWorker {
  let cipherOperation: CipherOperationOnBlock
  let blockSize: Int
  let additionalBufferSize: Int = 0
  private let iv: ArraySlice<UInt8>
  private let segmentSize: CFB.SegmentSize
  private var prev: ArraySlice<UInt8>?

  init(blockSize: Int, iv: ArraySlice<UInt8>, segmentSize: CFB.SegmentSize, cipherOperation: @escaping CipherOperationOnBlock) {
    self.blockSize = blockSize
    self.iv = iv
    self.segmentSize = segmentSize
    self.cipherOperation = cipherOperation
  }

  @inlinable
  mutating func encrypt(block plaintext: ArraySlice<UInt8>) -> Array<UInt8> {
    switch segmentSize {
    case .cfb128:
      guard let ciphertext = cipherOperation(prev ?? iv) else {
        return Array(plaintext)
      }
      self.prev = xor(plaintext, ciphertext.slice)
      return Array(self.prev ?? [])
    case .cfb8:
      guard let ciphertext = cipherOperation(prev ?? iv) else {
        return Array(plaintext)
      }
      let result = [Array(plaintext)[0] ^ Array(ciphertext)[0]]
      self.prev = Array((prev ?? iv).dropFirst()) + [result[0]]
      return result
    }
  }

  @inlinable
  mutating func decrypt(block ciphertext: ArraySlice<UInt8>) -> Array<UInt8> {
    switch segmentSize {
    case .cfb128:
      guard let plaintext = cipherOperation(prev ?? iv) else {
        return Array(ciphertext)
      }
      let result: Array<UInt8> = xor(plaintext, ciphertext)
      prev = ciphertext
      return result
    case .cfb8:
      guard let plaintext = cipherOperation(prev ?? iv) else {
        return Array(ciphertext)
      }
      self.prev = Array((prev ?? iv).dropFirst()) + [Array(ciphertext)[0]]
      return [Array(ciphertext)[0] ^ Array(plaintext)[0]]
    }
  }
}
