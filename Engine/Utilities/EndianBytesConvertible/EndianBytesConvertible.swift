// 
//  [EndianBytesConvertible].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public protocol EndianBytesConvertible {
    associatedtype BigEndianBytesSequence: Sequence<UInt8>
    
    associatedtype LittleEndianBytesSequence: Sequence<UInt8>
    
   init(bigEndianBytes: some Sequence<UInt8>)
    
    init(littleEndianBytes: some Sequence<UInt8>)
    
     func bigEndianBytes() -> BigEndianBytesSequence
    
    func littleEndianBytes() -> LittleEndianBytesSequence
}
