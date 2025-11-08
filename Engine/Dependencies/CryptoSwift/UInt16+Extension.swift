//
//  Ulnt16+Extension.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//


extension UInt16 {
  @_specialize(where T == ArraySlice<UInt8>)
  init<T: Collection>(bytes: T) where T.Element == UInt8, T.Index == Int {
    self = UInt16(bytes: bytes, fromIndex: bytes.startIndex)
  }

  @_specialize(where T == ArraySlice<UInt8>)
  init<T: Collection>(bytes: T, fromIndex index: T.Index) where T.Element == UInt8, T.Index == Int {
    if bytes.isEmpty {
      self = 0
      return
    }

    let count = bytes.count

    let val0 = count > 0 ? UInt16(bytes[index.advanced(by: 0)]) << 8 : 0
    let val1 = count > 1 ? UInt16(bytes[index.advanced(by: 1)]) : 0

    self = val0 | val1
  }
}
