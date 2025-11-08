//
//  AEADXChaCha20Poly1305.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//


import Foundation


public final class AEADXChaCha20Poly1305: AEAD {

  
  public static let kLen = 32 // key length

  
  public static var ivRange = Range<Int>(12...12)

  
  public static func encrypt(
    _ plainText: Array<UInt8>,
    key: Array<UInt8>,
    iv: Array<UInt8>,
    authenticationHeader: Array<UInt8>
  ) throws -> (cipherText: Array<UInt8>, authenticationTag: Array<UInt8>) {
    try AEADChaCha20Poly1305.encrypt(
      cipher: XChaCha20(key: key, iv: iv),
      plainText,
      key: key,
      iv: iv,
      authenticationHeader: authenticationHeader
    )
  }

  
  public static func decrypt(
    _ cipherText: Array<UInt8>,
    key: Array<UInt8>,
    iv: Array<UInt8>,
    authenticationHeader: Array<UInt8>,
    authenticationTag: Array<UInt8>
  ) throws -> (plainText: Array<UInt8>, success: Bool) {
    try AEADChaCha20Poly1305.decrypt(
      cipher: XChaCha20(key: key, iv: iv),
      cipherText: cipherText,
      key: key,
      iv: iv,
      authenticationHeader: authenticationHeader,
      authenticationTag: authenticationTag
    )
  }
}
