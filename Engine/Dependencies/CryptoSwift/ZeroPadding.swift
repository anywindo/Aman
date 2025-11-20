// 
//  [ZeroPadding].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

struct ZeroPadding: PaddingProtocol {
  init() {
  }

  @inlinable
  func add(to bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
    let paddingCount = blockSize - (bytes.count % blockSize)
    if paddingCount > 0 {
      return bytes + Array<UInt8>(repeating: 0, count: paddingCount)
    }
    return bytes
  }

  @inlinable
  func remove(from bytes: Array<UInt8>, blockSize _: Int?) -> Array<UInt8> {
    for (idx, value) in bytes.reversed().enumerated() {
      if value != 0 {
        return Array(bytes[0..<bytes.count - idx])
      }
    }
    return bytes
  }
}
