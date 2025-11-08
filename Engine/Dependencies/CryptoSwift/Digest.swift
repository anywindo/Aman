//
//  Digest.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

@available(*, renamed: "Digest")
public typealias Hash = Digest


public struct Digest {
  
  public static func md5(_ bytes: Array<UInt8>) -> Array<UInt8> {
    MD5().calculate(for: bytes)
  }

  
  public static func sha1(_ bytes: Array<UInt8>) -> Array<UInt8> {
    SHA1().calculate(for: bytes)
  }

  
  public static func sha224(_ bytes: Array<UInt8>) -> Array<UInt8> {
    self.sha2(bytes, variant: .sha224)
  }

  
  public static func sha256(_ bytes: Array<UInt8>) -> Array<UInt8> {
    self.sha2(bytes, variant: .sha256)
  }

  
  public static func sha384(_ bytes: Array<UInt8>) -> Array<UInt8> {
    self.sha2(bytes, variant: .sha384)
  }

  
  public static func sha512(_ bytes: Array<UInt8>) -> Array<UInt8> {
    self.sha2(bytes, variant: .sha512)
  }

  
  public static func sha2(_ bytes: Array<UInt8>, variant: SHA2.Variant) -> Array<UInt8> {
    SHA2(variant: variant).calculate(for: bytes)
  }

  
  public static func sha3(_ bytes: Array<UInt8>, variant: SHA3.Variant) -> Array<UInt8> {
    SHA3(variant: variant).calculate(for: bytes)
  }
}
