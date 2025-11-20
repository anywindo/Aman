//
//  String+FoundationExtension.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

extension String {
  public func decryptBase64ToString(cipher: Cipher) throws -> String {
    guard let decodedData = Data(base64Encoded: self, options: []) else {
      throw CipherError.decrypt
    }

    let decrypted = try decodedData.decrypt(cipher: cipher)

    if let decryptedString = String(data: decrypted, encoding: String.Encoding.utf8) {
      return decryptedString
    }

    throw CipherError.decrypt
  }

  public func decryptBase64(cipher: Cipher) throws -> Array<UInt8> {
    guard let decodedData = Data(base64Encoded: self, options: []) else {
      throw CipherError.decrypt
    }

    return try decodedData.decrypt(cipher: cipher).byteArray
  }
}
