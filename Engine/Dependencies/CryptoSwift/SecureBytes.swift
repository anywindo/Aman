// 
//  [SecureBytes].swift 
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
#elseif canImport(WinSDK)
import WinSDK
#endif

typealias Key = SecureBytes

final class SecureBytes {
  private let bytes: Array<UInt8>
  let count: Int

  init(bytes: Array<UInt8>) {
    self.bytes = bytes
    self.count = bytes.count
    self.bytes.withUnsafeBufferPointer { (pointer) -> Void in
      #if os(Windows)
        VirtualLock(UnsafeMutableRawPointer(mutating: pointer.baseAddress), SIZE_T(pointer.count))
      #elseif os(WASI)
      #elseif os(Android)
        mlock(pointer.baseAddress!, pointer.count)
      #else
        mlock(pointer.baseAddress, pointer.count)
      #endif
    }
  }

  deinit {
    self.bytes.withUnsafeBufferPointer { (pointer) -> Void in
      #if os(Windows)
        VirtualUnlock(UnsafeMutableRawPointer(mutating: pointer.baseAddress), SIZE_T(pointer.count))
      #elseif os(WASI)
      #elseif os(Android)
        munlock(pointer.baseAddress!, pointer.count)
      #else
        munlock(pointer.baseAddress, pointer.count)
      #endif
    }
  }
}

extension SecureBytes: Collection {
  typealias Index = Int

  var endIndex: Int {
    self.bytes.endIndex
  }

  var startIndex: Int {
    self.bytes.startIndex
  }

  subscript(position: Index) -> UInt8 {
    self.bytes[position]
  }

  subscript(bounds: Range<Index>) -> ArraySlice<UInt8> {
    self.bytes[bounds]
  }

  func formIndex(after i: inout Int) {
    self.bytes.formIndex(after: &i)
  }

  func index(after i: Int) -> Int {
    self.bytes.index(after: i)
  }
}

extension SecureBytes: ExpressibleByArrayLiteral {
  public convenience init(arrayLiteral elements: UInt8...) {
    self.init(bytes: elements)
  }
}
