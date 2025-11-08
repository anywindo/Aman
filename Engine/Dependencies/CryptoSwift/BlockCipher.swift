// 
//  [BlockCipher].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

protocol BlockCipher: Cipher {
  static var blockSize: Int { get }
}
