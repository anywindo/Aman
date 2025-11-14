//
//  Cipher.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

public enum CipherError: Error {
  case encrypt
  case decrypt
}

public protocol Cipher: AnyObject {
  var keySize: Int { get }

  func encrypt(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8>
  func encrypt(_ bytes: Array<UInt8>) throws -> Array<UInt8>

  func decrypt(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8>
  func decrypt(_ bytes: Array<UInt8>) throws -> Array<UInt8>
}

extension Cipher {
  public func encrypt(_ bytes: Array<UInt8>) throws -> Array<UInt8> {
    try self.encrypt(bytes.slice)
  }

  public func decrypt(_ bytes: Array<UInt8>) throws -> Array<UInt8> {
    try self.decrypt(bytes.slice)
  }
}
