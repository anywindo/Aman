//
//  CMAC.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

public class CMAC: Authenticator {
  public enum Error: Swift.Error {
    case wrongKeyLength
  }

  internal let key: SecureBytes

  internal static let BlockSize: Int = 16
  internal static let Zero: Array<UInt8> = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
  private static let Rb: Array<UInt8> = [0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x87]

  public init(key: Array<UInt8>) throws {
    self.key = SecureBytes(bytes: key)
  }

  // MARK: Authenticator

  
  public func authenticate(_ bytes: Array<UInt8>) throws -> Array<UInt8> {
    let cipher = try AES(key: Array(key), blockMode: CBC(iv: CMAC.Zero), padding: .noPadding)
    return try self.authenticate(bytes, cipher: cipher)
  }

  
  public func authenticate(_ bytes: Array<UInt8>, cipher: Cipher) throws -> Array<UInt8> {
    let l = try cipher.encrypt(CMAC.Zero)
    var subKey1 = self.leftShiftOneBit(l)
    if (l[0] & 0x80) != 0 {
      subKey1 = xor(CMAC.Rb, subKey1)
    }
    var subKey2 = self.leftShiftOneBit(subKey1)
    if (subKey1[0] & 0x80) != 0 {
      subKey2 = xor(CMAC.Rb, subKey2)
    }

    let lastBlockComplete: Bool
    let blockCount = (bytes.count + CMAC.BlockSize - 1) / CMAC.BlockSize
    if blockCount == 0 {
      lastBlockComplete = false
    } else {
      lastBlockComplete = bytes.count % CMAC.BlockSize == 0
    }
    var paddedBytes = bytes
    if !lastBlockComplete {
      bitPadding(to: &paddedBytes, blockSize: CMAC.BlockSize)
    }

    var blocks = Array(paddedBytes.batched(by: CMAC.BlockSize))
    var lastBlock = blocks.popLast()!
    if lastBlockComplete {
      lastBlock = xor(lastBlock, subKey1)
    } else {
      lastBlock = xor(lastBlock, subKey2)
    }

    var x = Array<UInt8>(repeating: 0x00, count: CMAC.BlockSize)
    var y = Array<UInt8>(repeating: 0x00, count: CMAC.BlockSize)
    for block in blocks {
      y = xor(block, x)
      x = try cipher.encrypt(y)
    }
    
    y = self.process(lastBlock: lastBlock, with: x)
    return try cipher.encrypt(y)
  }

  func process(lastBlock: ArraySlice<UInt8>, with x: [UInt8]) -> [UInt8] {
    xor(lastBlock, x)
  }

  // MARK: Helper methods

  
  private func leftShiftOneBit(_ bytes: Array<UInt8>) -> Array<UInt8> {
    var shifted = Array<UInt8>(repeating: 0x00, count: bytes.count)
    let last = bytes.count - 1
    for index in 0..<last {
      shifted[index] = bytes[index] << 1
      if (bytes[index + 1] & 0x80) != 0 {
        shifted[index] += 0x01
      }
    }
    shifted[last] = bytes[last] << 1
    return shifted
  }
}
