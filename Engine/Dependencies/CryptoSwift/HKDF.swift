//
//  HKDF.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
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


public struct HKDF {
  public enum Error: Swift.Error {
    case invalidInput
    case derivedKeyTooLong
  }

  private let numBlocks: Int // l
  private let dkLen: Int
  private let info: Array<UInt8>
  private let prk: Array<UInt8>
  private let variant: HMAC.Variant

  
  public init(password: Array<UInt8>, salt: Array<UInt8>? = nil, info: Array<UInt8>? = nil, keyLength: Int? = nil /* dkLen */, variant: HMAC.Variant = .sha2(.sha256)) throws {
    guard !password.isEmpty else {
      throw Error.invalidInput
    }

    let dkLen = keyLength ?? variant.digestLength
    let keyLengthFinal = Double(dkLen)
    let hLen = Double(variant.digestLength)
    let numBlocks = Int(ceil(keyLengthFinal / hLen)) 
    guard numBlocks <= 255 else {
      throw Error.derivedKeyTooLong
    }

   
    self.prk = try HMAC(key: salt ?? [], variant: variant).authenticate(password)
    self.info = info ?? []
    self.variant = variant
    self.dkLen = dkLen
    self.numBlocks = numBlocks
  }

  public func calculate() throws -> Array<UInt8> {
    let hmac = HMAC(key: prk, variant: variant)
    var ret = Array<UInt8>()
    ret.reserveCapacity(self.numBlocks * self.variant.digestLength)
    var value = Array<UInt8>()
    for i in 1...self.numBlocks {
      value.append(contentsOf: self.info)
      value.append(UInt8(i))

      let bytes = try hmac.authenticate(value)
      ret.append(contentsOf: bytes)

      
      value = bytes
    }
    return Array(ret.prefix(self.dkLen))
  }

  public func callAsFunction() throws -> Array<UInt8> {
    try calculate()
  }
}
