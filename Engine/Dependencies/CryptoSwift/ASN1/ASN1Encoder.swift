//
//  ASN1Encoder.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

extension ASN1 {
  enum Encoder {
   
    public static func encode(_ node: ASN1.Node) -> [UInt8] {
      switch node {
        case .integer(let integer):
          return IDENTIFIERS.INTERGER.bytes + self.asn1LengthPrefixed(integer.byteArray)
        case .bitString(let bits):
          return IDENTIFIERS.BITSTRING.bytes + self.asn1LengthPrefixed([0x00] + bits.byteArray)
        case .octetString(let octet):
          return IDENTIFIERS.OCTETSTRING.bytes + self.asn1LengthPrefixed(octet.byteArray)
        case .null:
          return IDENTIFIERS.NULL.bytes
        case .objectIdentifier(let oid):
          return IDENTIFIERS.OBJECTID.bytes + self.asn1LengthPrefixed(oid.byteArray)
        case .sequence(let nodes):
          return IDENTIFIERS.SEQUENCE.bytes + self.asn1LengthPrefixed( nodes.reduce(into: Array<UInt8>(), { partialResult, node in
            partialResult += encode(node)
          }))
      }
    }

   
    private static func asn1LengthPrefix(_ bytes: [UInt8]) -> [UInt8] {
      if bytes.count >= 0x80 {
        var lengthAsBytes = withUnsafeBytes(of: bytes.count.bigEndian, Array<UInt8>.init)
        while lengthAsBytes.first == 0 { lengthAsBytes.removeFirst() }
        return [0x80 + UInt8(lengthAsBytes.count)] + lengthAsBytes
      } else {
        return [UInt8(bytes.count)]
      }
    }

   
    private static func asn1LengthPrefixed(_ bytes: [UInt8]) -> [UInt8] {
      self.asn1LengthPrefix(bytes) + bytes
    }
  }
}
