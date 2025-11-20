// 
//  [PKCS1v15].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

struct EMSAPKCS1v15Padding: PaddingProtocol {

  init() {
  }

  @inlinable
  func add(to bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
    var r = blockSize - ((bytes.count + 3) % blockSize)
    if r <= 0 { r = blockSize - 3 }

    return [0x00, 0x01] + Array<UInt8>(repeating: 0xFF, count: r) + [0x00] + bytes
  }

  @inlinable
  func remove(from bytes: Array<UInt8>, blockSize _: Int?) -> Array<UInt8> {
    assert(!bytes.isEmpty, "Need bytes to remove padding")

    assert(bytes.prefix(2) == [0x00, 0x01], "Invalid padding prefix")

    guard let paddingLength = bytes.dropFirst(2).firstIndex(of: 0x00) else { return bytes }

    guard (paddingLength + 1) <= bytes.count else { return bytes }

    return Array(bytes[(paddingLength + 1)...])
  }
}

struct EMEPKCS1v15Padding: PaddingProtocol {

  init() {
  }

  @inlinable
  func add(to bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
    var r = blockSize - ((bytes.count + 3) % blockSize)
    if r <= 0 { r = blockSize - 3 }

    return [0x00, 0x02] + (0..<r).map { _ in UInt8.random(in: 1...UInt8.max) } + [0x00] + bytes
  }

  @inlinable
  func remove(from bytes: Array<UInt8>, blockSize _: Int?) -> Array<UInt8> {
    assert(!bytes.isEmpty, "Need bytes to remove padding")

    assert(bytes.prefix(2) == [0x00, 0x02], "Invalid padding prefix")

    guard let paddingLength = bytes.dropFirst(2).firstIndex(of: 0x00) else { return bytes }

    guard (paddingLength + 1) <= bytes.count else { return bytes }

    return Array(bytes[(paddingLength + 1)...])
  }
}
