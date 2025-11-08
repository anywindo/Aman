
// 
//  [HMAC+Foundation].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 
import Foundation

extension HMAC {
  public convenience init(key: String, variant: HMAC.Variant = .md5) throws {
    self.init(key: key.bytes, variant: variant)
  }
}
