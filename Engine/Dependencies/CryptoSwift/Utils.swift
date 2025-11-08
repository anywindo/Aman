// 
//  [Utils].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

@inlinable
func rotateLeft(_ value: UInt8, by: UInt8) -> UInt8 {
  ((value << by) & 0xff) | (value >> (8 - by))
}

@inlinable
func rotateLeft(_ value: UInt16, by: UInt16) -> UInt16 {
  ((value << by) & 0xffff) | (value >> (16 - by))
}

@inlinable
func rotateLeft(_ value: UInt32, by: UInt32) -> UInt32 {
  ((value << by) & 0xffffffff) | (value >> (32 - by))
}

@inlinable
func rotateLeft(_ value: UInt64, by: UInt64) -> UInt64 {
  (value << by) | (value >> (64 - by))
}

@inlinable
func rotateRight(_ value: UInt16, by: UInt16) -> UInt16 {
  (value >> by) | (value << (16 - by))
}

@inlinable
func rotateRight(_ value: UInt32, by: UInt32) -> UInt32 {
  (value >> by) | (value << (32 - by))
}

@inlinable
func rotateRight(_ value: UInt64, by: UInt64) -> UInt64 {
  ((value >> by) | (value << (64 - by)))
}

@inlinable
func reversed(_ uint8: UInt8) -> UInt8 {
  var v = uint8
  v = (v & 0xf0) >> 4 | (v & 0x0f) << 4
  v = (v & 0xcc) >> 2 | (v & 0x33) << 2
  v = (v & 0xaa) >> 1 | (v & 0x55) << 1
  return v
}

@inlinable
func reversed(_ uint32: UInt32) -> UInt32 {
  var v = uint32
  v = ((v >> 1) & 0x55555555) | ((v & 0x55555555) << 1)
  v = ((v >> 2) & 0x33333333) | ((v & 0x33333333) << 2)
  v = ((v >> 4) & 0x0f0f0f0f) | ((v & 0x0f0f0f0f) << 4)
  v = ((v >> 8) & 0x00ff00ff) | ((v & 0x00ff00ff) << 8)
  v = ((v >> 16) & 0xffff) | ((v & 0xffff) << 16)
  return v
}

@inlinable
func xor<T, V>(_ left: T, _ right: V) -> ArraySlice<UInt8> where T: RandomAccessCollection, V: RandomAccessCollection, T.Element == UInt8, T.Index == Int, V.Element == UInt8, V.Index == Int {
  return xor(left, right).slice
}

@inlinable
func xor<T, V>(_ left: T, _ right: V) -> Array<UInt8> where T: RandomAccessCollection, V: RandomAccessCollection, T.Element == UInt8, T.Index == Int, V.Element == UInt8, V.Index == Int {
  let length = Swift.min(left.count, right.count)

  let buf = UnsafeMutablePointer<UInt8>.allocate(capacity: length)
  buf.initialize(repeating: 0, count: length)
  defer {
    buf.deinitialize(count: length)
    buf.deallocate()
  }

  // xor
  for i in 0..<length {
    buf[i] = left[left.startIndex.advanced(by: i)] ^ right[right.startIndex.advanced(by: i)]
  }

  return Array(UnsafeBufferPointer(start: buf, count: length))
}


@inline(__always) @inlinable
func bitPadding(to data: inout Array<UInt8>, blockSize: Int, allowance: Int = 0) {
  let msgLength = data.count

  data.append(0x80)

  let max = blockSize - allowance
  if msgLength % blockSize < max {
    data += Array<UInt8>(repeating: 0, count: max - 1 - (msgLength % blockSize))
  } else {
    data += Array<UInt8>(repeating: 0, count: blockSize + max - 1 - (msgLength % blockSize))
  }
}
