// 
//  [Array+Foundation].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

public extension Array where Element == UInt8 {
  func toBase64(options: Data.Base64EncodingOptions = []) -> String {
    Data(self).base64EncodedString(options: options)
  }

  init(base64: String, options: Data.Base64DecodingOptions = .ignoreUnknownCharacters) {
    self.init()

    guard let decodedData = Data(base64Encoded: base64, options: options) else {
      return
    }

    append(contentsOf: decodedData.byteArray)
  }
}
