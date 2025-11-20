// 
//  [DigestType].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

internal protocol DigestType {
  func calculate(for bytes: Array<UInt8>) -> Array<UInt8>
}
