// 
//  [ChaCha20+Foundation].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

extension ChaCha20 {
  public convenience init(key: String, iv: String) throws {
    try self.init(key: key.bytes, iv: iv.bytes)
  }
}
