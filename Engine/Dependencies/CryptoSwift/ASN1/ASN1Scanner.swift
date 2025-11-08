//
//  ASN1Scanner.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

extension ASN1 {
  
  internal class Scanner {

    enum ScannerError: Error {
      case outOfBounds
    }

    let data: Data
    var index: Int = 0

    
    var isComplete: Bool {
      return self.index >= self.data.count
    }

  
    init(data: Data) {
      self.data = data
    }

   
    func consume(length: Int) throws -> Data {

      guard length > 0 else {
        return Data()
      }

      guard self.index + length <= self.data.count else {
        throw ScannerError.outOfBounds
      }

      let subdata = self.data.subdata(in: self.index..<self.index + length)
      self.index += length
      return subdata
    }

    func consumeLength() throws -> Int {

      let lengthByte = try consume(length: 1).firstByte

      guard lengthByte >= 0x80 else {
        return Int(lengthByte)
      }

      let nextByteCount = lengthByte - 0x80
      let length = try consume(length: Int(nextByteCount))

      return length.integer
    }
  }
}

internal extension Data {

 
  var firstByte: UInt8 {
    var byte: UInt8 = 0
    copyBytes(to: &byte, count: MemoryLayout<UInt8>.size)
    return byte
  }

 
  var integer: Int {

    guard count > 0 else {
      return 0
    }

    var int: UInt32 = 0
    var offset: Int32 = Int32(count - 1)
    forEach { byte in
      let byte32 = UInt32(byte)
      let shifted = byte32 << (UInt32(offset) * 8)
      int = int | shifted
      offset -= 1
    }

    return Int(int)
  }
}
