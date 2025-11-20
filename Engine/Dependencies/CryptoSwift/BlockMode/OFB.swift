// 
//  [OFB].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public struct OFB: BlockMode {
  public enum Error: Swift.Error {
    case invalidInitializationVector
  }

  public let options: BlockModeOption = [.initializationVectorRequired, .useEncryptToDecrypt]
  private let iv: Array<UInt8>
  public let customBlockSize: Int? = nil

  public init(iv: Array<UInt8>) {
    self.iv = iv
  }

  public func worker(blockSize: Int, cipherOperation: @escaping CipherOperationOnBlock, encryptionOperation: @escaping CipherOperationOnBlock) throws -> CipherModeWorker {
    if self.iv.count != blockSize {
      throw Error.invalidInitializationVector
    }

    return OFBModeWorker(blockSize: blockSize, iv: self.iv.slice, cipherOperation: cipherOperation)
  }
}

struct OFBModeWorker: BlockModeWorker {
  let cipherOperation: CipherOperationOnBlock
  let blockSize: Int
  let additionalBufferSize: Int = 0
  private let iv: ArraySlice<UInt8>
  private var prev: ArraySlice<UInt8>?

  init(blockSize: Int, iv: ArraySlice<UInt8>, cipherOperation: @escaping CipherOperationOnBlock) {
    self.blockSize = blockSize
    self.iv = iv
    self.cipherOperation = cipherOperation
  }

  @inlinable
  mutating func encrypt(block plaintext: ArraySlice<UInt8>) -> Array<UInt8> {
    guard let ciphertext = cipherOperation(prev ?? iv) else {
      return Array(plaintext)
    }
    self.prev = ciphertext.slice
    return xor(plaintext, ciphertext)
  }

  @inlinable
  mutating func decrypt(block ciphertext: ArraySlice<UInt8>) -> Array<UInt8> {
    guard let decrypted = cipherOperation(prev ?? iv) else {
      return Array(ciphertext)
    }
    let plaintext: Array<UInt8> = xor(decrypted, ciphertext)
    prev = decrypted.slice
    return plaintext
  }
}
