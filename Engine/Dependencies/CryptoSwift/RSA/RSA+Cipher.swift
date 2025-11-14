//
//  RSA+Cipher.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

// MARK: Cipher

extension RSA: Cipher {

  @inlinable
  public func encrypt(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8> {
    return try self.encrypt(Array<UInt8>(bytes), variant: .pksc1v15)
  }

  @inlinable
  public func encrypt(_ bytes: Array<UInt8>, variant: RSAEncryptionVariant) throws -> Array<UInt8> {
    let preparedData = try variant.prepare(bytes, blockSize: self.keySizeBytes)

    return try variant.formatEncryptedBytes(self.encryptPreparedBytes(preparedData), blockSize: self.keySizeBytes)
  }

  @inlinable
  internal func encryptPreparedBytes(_ bytes: Array<UInt8>) throws -> Array<UInt8> {
    return BigUInteger(Data(bytes)).power(self.e, modulus: self.n).serialize().byteArray
  }

  @inlinable
  public func decrypt(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8> {
    return try self.decrypt(Array<UInt8>(bytes), variant: .pksc1v15)
  }

  @inlinable
  public func decrypt(_ bytes: Array<UInt8>, variant: RSAEncryptionVariant) throws -> Array<UInt8> {
    let decrypted = try self.decryptPreparedBytes(bytes)

    return variant.removePadding(decrypted, blockSize: self.keySizeBytes)
  }

  @inlinable
  internal func decryptPreparedBytes(_ bytes: Array<UInt8>) throws -> Array<UInt8> {
    guard let d = d else { throw RSA.Error.noPrivateKey }

    return BigUInteger(Data(bytes)).power(d, modulus: self.n).serialize().byteArray
  }
}

extension RSA {
  
  @frozen
  public enum RSAEncryptionVariant {
    
    case unsafe
   
    case raw
   
    case pksc1v15

    @inlinable
    internal func prepare(_ bytes: Array<UInt8>, blockSize: Int) throws -> Array<UInt8> {
      switch self {
        case .unsafe:
          return bytes
        case .raw:
         
          guard blockSize >= bytes.count + 11 else { throw RSA.Error.invalidMessageLengthForEncryption }
          return Array(repeating: 0x00, count: blockSize - bytes.count) + bytes
        case .pksc1v15:
          guard !bytes.isEmpty else { throw RSA.Error.invalidMessageLengthForEncryption }
          guard blockSize >= bytes.count + 11 else { throw RSA.Error.invalidMessageLengthForEncryption }
          return Padding.eme_pkcs1v15.add(to: bytes, blockSize: blockSize)
      }
    }

    @inlinable
    internal func formatEncryptedBytes(_ bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
      switch self {
        case .unsafe:
          return bytes
        case .raw, .pksc1v15:
          return Array<UInt8>(repeating: 0x00, count: blockSize - bytes.count) + bytes
      }
    }

    @inlinable
    internal func removePadding(_ bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
      switch self {
        case .unsafe:
          return bytes
        case .raw:
          return bytes
        case .pksc1v15:
          
          return Padding.eme_pkcs1v15.remove(from: [0x00] + bytes, blockSize: blockSize)
      }
    }
  }
}
