//
//  Bit.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

public enum Bit: Int {
  case zero
  case one
}

extension Bit {
  @inlinable
  func inverted() -> Bit {
    self == .zero ? .one : .zero
  }
}
