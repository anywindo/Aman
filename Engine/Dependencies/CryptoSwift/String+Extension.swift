// 
//  [String+Extension].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

 extension String {

  @inlinable
  public var bytes: Array<UInt8> {
    data(using: String.Encoding.utf8, allowLossyConversion: true)?.byteArray ?? Array(utf8)
  }

  @inlinable
  public func md5() -> String {
    self.bytes.md5().toHexString()
  }

  @inlinable
  public func sha1() -> String {
    self.bytes.sha1().toHexString()
  }

  @inlinable
  public func sha224() -> String {
    self.bytes.sha224().toHexString()
  }

  @inlinable
  public func sha256() -> String {
    self.bytes.sha256().toHexString()
  }

  @inlinable
  public func sha384() -> String {
    self.bytes.sha384().toHexString()
  }

  @inlinable
  public func sha512() -> String {
    self.bytes.sha512().toHexString()
  }

  @inlinable
  public func sha3(_ variant: SHA3.Variant) -> String {
    self.bytes.sha3(variant).toHexString()
  }

  @inlinable
  public func crc32(seed: UInt32? = nil, reflect: Bool = true) -> String {
    self.bytes.crc32(seed: seed, reflect: reflect).bytes().toHexString()
  }

  @inlinable
  public func crc32c(seed: UInt32? = nil, reflect: Bool = true) -> String {
    self.bytes.crc32c(seed: seed, reflect: reflect).bytes().toHexString()
  }

  @inlinable
  public func crc16(seed: UInt16? = nil) -> String {
    self.bytes.crc16(seed: seed).bytes().toHexString()
  }

  @inlinable
  public func encrypt(cipher: Cipher) throws -> String {
    try self.bytes.encrypt(cipher: cipher).toHexString()
  }

  @inlinable
  public func encryptToBase64(cipher: Cipher) throws -> String {
    try self.bytes.encrypt(cipher: cipher).toBase64()
  }


  @inlinable
  public func authenticate<A: Authenticator>(with authenticator: A) throws -> String {
    try self.bytes.authenticate(with: authenticator).toHexString()
  }
}
