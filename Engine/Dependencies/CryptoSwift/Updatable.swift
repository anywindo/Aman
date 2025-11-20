
// 
//  [Updatable].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public protocol Updatable {
 
  mutating func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool) throws -> Array<UInt8>

   mutating func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool, output: (_ bytes: Array<UInt8>) -> Void) throws
}

extension Updatable {
  @inlinable
  public mutating func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool = false, output: (_ bytes: Array<UInt8>) -> Void) throws {
    let processed = try update(withBytes: bytes, isLast: isLast)
    if !processed.isEmpty {
      output(processed)
    }
  }

  @inlinable
  public mutating func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool = false) throws -> Array<UInt8> {
    try self.update(withBytes: bytes, isLast: isLast)
  }

  @inlinable
  public mutating func update(withBytes bytes: Array<UInt8>, isLast: Bool = false) throws -> Array<UInt8> {
    try self.update(withBytes: bytes.slice, isLast: isLast)
  }

  @inlinable
  public mutating func update(withBytes bytes: Array<UInt8>, isLast: Bool = false, output: (_ bytes: Array<UInt8>) -> Void) throws {
    try self.update(withBytes: bytes.slice, isLast: isLast, output: output)
  }

   @inlinable
  public mutating func finish(withBytes bytes: ArraySlice<UInt8>) throws -> Array<UInt8> {
    try self.update(withBytes: bytes, isLast: true)
  }

  @inlinable
  public mutating func finish(withBytes bytes: Array<UInt8>) throws -> Array<UInt8> {
    try self.finish(withBytes: bytes.slice)
  }

  @inlinable
  public mutating func finish() throws -> Array<UInt8> {
    try self.update(withBytes: [], isLast: true)
  }


  @inlinable
  public mutating func finish(withBytes bytes: ArraySlice<UInt8>, output: (_ bytes: Array<UInt8>) -> Void) throws {
    let processed = try update(withBytes: bytes, isLast: true)
    if !processed.isEmpty {
      output(processed)
    }
  }

  @inlinable
  public mutating func finish(withBytes bytes: Array<UInt8>, output: (_ bytes: Array<UInt8>) -> Void) throws {
    try self.finish(withBytes: bytes.slice, output: output)
  }


  @inlinable
  public mutating func finish(output: (Array<UInt8>) -> Void) throws {
    try self.finish(withBytes: [], output: output)
  }
}
