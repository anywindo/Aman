//
//  Int+Extension.swift
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
#endif

extension FixedWidthInteger {
  @inlinable
  func bytes(totalBytes: Int = MemoryLayout<Self>.size) -> Array<UInt8> {
    arrayOfBytes(value: self.littleEndian, length: totalBytes)
    
  }
}
