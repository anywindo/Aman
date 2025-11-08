// 
//  [Common].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension FixedWidthInteger {
    static var isExactlyByteRepresentable: Bool {
        0 <= bitWidth && bitWidth.isMultiple(of: 8)
    }
}
