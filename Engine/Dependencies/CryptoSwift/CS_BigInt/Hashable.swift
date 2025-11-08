// 
//  [Hashable].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS.BigUInt: Hashable {
    //MARK: Hashing


    public func hash(into hasher: inout Hasher) {
        for word in self.words {
            hasher.combine(word)
        }
    }
}

extension CS.BigInt: Hashable {
    public func hash(into hasher: inout Hasher) {
        hasher.combine(sign)
        hasher.combine(magnitude)
    }
}
