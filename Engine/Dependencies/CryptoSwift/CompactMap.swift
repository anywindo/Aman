// 
//  [CompactMap].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

#if swift(>=4.1)
#else
  extension Sequence {
    @inlinable
    public func compactMap<ElementOfResult>(_ transform: (Element) throws -> ElementOfResult?) rethrows -> [ElementOfResult] {
      try flatMap(transform)
    }
  }
#endif
