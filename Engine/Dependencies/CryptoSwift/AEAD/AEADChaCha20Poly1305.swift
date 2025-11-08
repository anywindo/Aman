//
//  AEADChaCha20Poly1305.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//


public final class AEADChaCha20Poly1305: AEAD {
  public static let kLen = 32 
  public static var ivRange = Range<Int>(12...12)

  
  public static func encrypt(_ plainText: Array<UInt8>, key: Array<UInt8>, iv: Array<UInt8>, authenticationHeader: Array<UInt8>) throws -> (cipherText: Array<UInt8>, authenticationTag: Array<UInt8>) {
    let cipher = try ChaCha20(key: key, iv: iv)
    return try self.encrypt(cipher: cipher, plainText, key: key, iv: iv, authenticationHeader: authenticationHeader)
  }

  public static func encrypt(cipher: Cipher, _ plainText: Array<UInt8>, key: Array<UInt8>, iv: Array<UInt8>, authenticationHeader: Array<UInt8>) throws -> (cipherText: Array<UInt8>, authenticationTag: Array<UInt8>) {
    var polykey = Array<UInt8>(repeating: 0, count: kLen)
    var toEncrypt = polykey
    polykey = try cipher.encrypt(polykey)
    toEncrypt += polykey
    toEncrypt += plainText

    let fullCipherText = try cipher.encrypt(toEncrypt)
    let cipherText = Array(fullCipherText.dropFirst(64))

    let tag = try calculateAuthenticationTag(authenticator: Poly1305(key: polykey), cipherText: cipherText, authenticationHeader: authenticationHeader)
    return (cipherText, tag)
  }

  
  public static func decrypt(_ cipherText: Array<UInt8>, key: Array<UInt8>, iv: Array<UInt8>, authenticationHeader: Array<UInt8>, authenticationTag: Array<UInt8>) throws -> (plainText: Array<UInt8>, success: Bool) {
    let cipher = try ChaCha20(key: key, iv: iv)
    return try self.decrypt(cipher: cipher, cipherText: cipherText, key: key, iv: iv, authenticationHeader: authenticationHeader, authenticationTag: authenticationTag)
  }

  static func decrypt(cipher: Cipher, cipherText: Array<UInt8>, key: Array<UInt8>, iv: Array<UInt8>, authenticationHeader: Array<UInt8>, authenticationTag: Array<UInt8>) throws -> (plainText: Array<UInt8>, success: Bool) {

    let polykey = try cipher.encrypt(Array<UInt8>(repeating: 0, count: self.kLen))
    let mac = try calculateAuthenticationTag(authenticator: Poly1305(key: polykey), cipherText: cipherText, authenticationHeader: authenticationHeader)
    guard mac == authenticationTag else {
      return (cipherText, false)
    }

    var toDecrypt = Array<UInt8>(reserveCapacity: cipherText.count + 64)
    toDecrypt += polykey
    toDecrypt += polykey
    toDecrypt += cipherText
    let fullPlainText = try cipher.decrypt(toDecrypt)
    let plainText = Array(fullPlainText.dropFirst(64))
    return (plainText, true)
  }
}
