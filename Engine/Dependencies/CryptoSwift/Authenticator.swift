// 
//  [Authenticator].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public protocol Authenticator {
  func authenticate(_ bytes: Array<UInt8>) throws -> Array<UInt8>
}
