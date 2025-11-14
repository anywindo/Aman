//
//  ASN1Decoder.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

extension ASN1 {
  
  enum Decoder {

    enum DecodingError: Error {
      case noType
      case invalidType(value: UInt8)
    }

   
    static func decode(data: Data) throws -> Node {
      let scanner = ASN1.Scanner(data: data)
      let node = try decodeNode(scanner: scanner)
      return node
    }

    
    private static func decodeNode(scanner: ASN1.Scanner) throws -> Node {

      let firstByte = try scanner.consume(length: 1).firstByte

      switch firstByte {
        case IDENTIFIERS.SEQUENCE.rawValue:
          let length = try scanner.consumeLength()
          let data = try scanner.consume(length: length)
          let nodes = try decodeSequence(data: data)
          return .sequence(nodes: nodes)

        case IDENTIFIERS.INTERGER.rawValue:
          let length = try scanner.consumeLength()
          let data = try scanner.consume(length: length)
          return .integer(data: data)

        case IDENTIFIERS.OBJECTID.rawValue:
          let length = try scanner.consumeLength()
          let data = try scanner.consume(length: length)
          return .objectIdentifier(data: data)

        case IDENTIFIERS.NULL.rawValue:
          _ = try scanner.consume(length: 1)
          return .null

        case IDENTIFIERS.BITSTRING.rawValue:
          let length = try scanner.consumeLength()

          
          _ = try scanner.consume(length: 1)

          let data = try scanner.consume(length: length - 1)
          return .bitString(data: data)

        case IDENTIFIERS.OCTETSTRING.rawValue:
          let length = try scanner.consumeLength()
          let data = try scanner.consume(length: length)
          return .octetString(data: data)

        default:
          throw DecodingError.invalidType(value: firstByte)
      }
    }

    
    private static func decodeSequence(data: Data) throws -> [Node] {
      let scanner = ASN1.Scanner(data: data)
      var nodes: [Node] = []
      while !scanner.isComplete {
        let node = try decodeNode(scanner: scanner)
        nodes.append(node)
      }
      return nodes
    }
  }
}
