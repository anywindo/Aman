//
//  DER.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation


internal protocol DERCodable: DERDecodable, DEREncodable { }


internal protocol DERDecodable {
  
  init(publicDER: Array<UInt8>) throws

  
  init(privateDER: Array<UInt8>) throws

  
  init(rawRepresentation: Data) throws
}


internal protocol DEREncodable {
  
  func publicKeyDER() throws -> Array<UInt8>

  
  func privateKeyDER() throws -> Array<UInt8>

  func externalRepresentation() throws -> Data

  func publicKeyExternalRepresentation() throws -> Data
}

struct DER {
  internal enum Error: Swift.Error {
    
    case invalidDERFormat
  }

  
  internal static func i2osp(x: [UInt8], size: Int) -> [UInt8] {
    var modulus = x
    while modulus.count < size {
      modulus.insert(0x00, at: 0)
    }
    if modulus[0] >= 0x80 {
      modulus.insert(0x00, at: 0)
    }
    return modulus
  }

  internal static func i2ospData(x: [UInt8], size: Int) -> Data {
    return Data(DER.i2osp(x: x, size: size))
  }
}
