// 
//  [ISO78164Padding].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 
import Foundation

struct ISO78164Padding: PaddingProtocol {
  init() {
  }

  @inlinable
  func add(to bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
    var padded = Array(bytes)
    padded.append(0x80)

    while (padded.count % blockSize) != 0 {
      padded.append(0x00)
    }
    return padded
  }

  @inlinable
  func remove(from bytes: Array<UInt8>, blockSize _: Int?) -> Array<UInt8> {
    if let idx = bytes.lastIndex(of: 0x80) {
      return Array(bytes[..<idx])
    } else {
      return bytes
    }
  }
}
