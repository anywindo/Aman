// 
//  [Signature].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public enum SignatureError: Error {
  case sign
  case verify
}

public protocol Signature: AnyObject {
  var keySize: Int { get }


  func sign(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8>

  func sign(_ bytes: Array<UInt8>) throws -> Array<UInt8>

  func verify(signature: ArraySlice<UInt8>, for expectedData: ArraySlice<UInt8>) throws -> Bool
   
   func verify(signature: Array<UInt8>, for expectedData: Array<UInt8>) throws -> Bool
}

extension Signature {
  public func sign(_ bytes: Array<UInt8>) throws -> Array<UInt8> {
    try self.sign(bytes.slice)
  }

  public func verify(signature: Array<UInt8>, for expectedData: Array<UInt8>) throws -> Bool {
    try self.verify(signature: signature.slice, for: expectedData.slice)
  }
}
