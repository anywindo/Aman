
//
//  ISO10126Padding.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation


struct ISO10126Padding: PaddingProtocol {
  init() {
  }

  @inlinable
  func add(to bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
    let padding = UInt8(blockSize - (bytes.count % blockSize))
    var withPadding = bytes
    if padding > 0 {
      withPadding += (0..<(padding - 1)).map { _ in UInt8.random(in: 0...255) } + [padding]
    }
    return withPadding
  }

  @inlinable
  func remove(from bytes: Array<UInt8>, blockSize: Int?) -> Array<UInt8> {
    guard !bytes.isEmpty, let lastByte = bytes.last else {
      return bytes
    }

    assert(!bytes.isEmpty, "Need bytes to remove padding")

    let padding = Int(lastByte) 
    let finalLength = bytes.count - padding

    if finalLength < 0 {
      return bytes
    }

    if padding >= 1 {
      return Array(bytes[0..<finalLength])
    }

    return bytes
  }
}
