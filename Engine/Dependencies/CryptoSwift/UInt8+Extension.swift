// 
//  [UInt8+Extension].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
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

public protocol _UInt8Type {}
extension UInt8: _UInt8Type {}

extension UInt8 {
  static func with(value: UInt64) -> UInt8 {
    let tmp = value & 0xff
    return UInt8(tmp)
  }

  static func with(value: UInt32) -> UInt8 {
    let tmp = value & 0xff
    return UInt8(tmp)
  }

  static func with(value: UInt16) -> UInt8 {
    let tmp = value & 0xff
    return UInt8(tmp)
  }
}

extension UInt8 {
  public func bits() -> [Bit] {
    let totalBitsCount = MemoryLayout<UInt8>.size * 8

    var bitsArray = [Bit](repeating: Bit.zero, count: totalBitsCount)

    for j in 0..<totalBitsCount {
      let bitVal: UInt8 = 1 << UInt8(totalBitsCount - 1 - j)
      let check = self & bitVal

      if check != 0 {
        bitsArray[j] = Bit.one
      }
    }
    return bitsArray
  }

  public func bits() -> String {
    var s = String()
    let arr: [Bit] = self.bits()
    for idx in arr.indices {
      s += (arr[idx] == Bit.one ? "1" : "0")
      if idx.advanced(by: 1) % 8 == 0 { s += " " }
    }
    return s
  }
}
