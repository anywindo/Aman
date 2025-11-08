///
//  NoPadding.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

struct NoPadding: PaddingProtocol {
  init() {
  }

  func add(to data: Array<UInt8>, blockSize _: Int) -> Array<UInt8> {
    data
  }

  func remove(from data: Array<UInt8>, blockSize _: Int?) -> Array<UInt8> {
    data
  }
}
