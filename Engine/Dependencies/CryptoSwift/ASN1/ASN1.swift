//
//  ASN1.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation


enum ASN1 {
  internal enum IDENTIFIERS: UInt8, Equatable {
    case SEQUENCE = 0x30
    case INTERGER = 0x02
    case OBJECTID = 0x06
    case NULL = 0x05
    case BITSTRING = 0x03
    case OCTETSTRING = 0x04

    static func == (lhs: UInt8, rhs: IDENTIFIERS) -> Bool {
      lhs == rhs.rawValue
    }

    var bytes: [UInt8] {
      switch self {
        case .NULL:
          return [self.rawValue, 0x00]
        default:
          return [self.rawValue]
      }
    }
  }

 
  internal enum Node: CustomStringConvertible {
   
    case sequence(nodes: [Node])
    
    case integer(data: Data)
    
    case objectIdentifier(data: Data)
    
    case null
    
    case bitString(data: Data)
    
    case octetString(data: Data)

    var description: String {
      ASN1.printNode(self, level: 0)
    }
  }

  internal static func printNode(_ node: ASN1.Node, level: Int) -> String {
    var str: [String] = []
    let prefix = String(repeating: "\t", count: level)
    switch node {
      case .integer(let int):
        str.append("\(prefix)Integer: \(int.toHexString())")
      case .bitString(let bs):
        str.append("\(prefix)BitString: \(bs.toHexString())")
      case .null:
        str.append("\(prefix)NULL")
      case .objectIdentifier(let oid):
        str.append("\(prefix)ObjectID: \(oid.toHexString())")
      case .octetString(let os):
        str.append("\(prefix)OctetString: \(os.toHexString())")
      case .sequence(let nodes):
        str.append("\(prefix)Sequence:")
        nodes.forEach { str.append(printNode($0, level: level + 1)) }
    }
    return str.joined(separator: "\n")
  }
}
