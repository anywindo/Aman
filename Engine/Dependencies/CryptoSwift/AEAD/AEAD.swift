//
//  AEAD.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//


public protocol AEAD {
  static var kLen: Int { get } 
  static var ivRange: Range<Int> { get } 
}

extension AEAD {
  static func calculateAuthenticationTag(authenticator: Authenticator, cipherText: Array<UInt8>, authenticationHeader: Array<UInt8>) throws -> Array<UInt8> {
    let headerPadding = ((16 - (authenticationHeader.count & 0xf)) & 0xf)
    let cipherPadding = ((16 - (cipherText.count & 0xf)) & 0xf)

    var mac = authenticationHeader
    mac += Array<UInt8>(repeating: 0, count: headerPadding)
    mac += cipherText
    mac += Array<UInt8>(repeating: 0, count: cipherPadding)
    mac += UInt64(bigEndian: UInt64(authenticationHeader.count)).bytes()
    mac += UInt64(bigEndian: UInt64(cipherText.count)).bytes()

    return try authenticator.authenticate(mac)
  }
}
