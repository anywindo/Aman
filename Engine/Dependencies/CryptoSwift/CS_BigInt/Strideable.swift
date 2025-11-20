// 
//  [Strideable].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS.BigUInt: Strideable {
    public typealias Stride = CS.BigInt

    public func advanced(by n: CS.BigInt) -> CS.BigUInt {
        return n.sign == .minus ? self - n.magnitude : self + n.magnitude
    }

    public func distance(to other: CS.BigUInt) -> CS.BigInt {
        return CS.BigInt(other) - CS.BigInt(self)
    }
}

extension CS.BigInt: Strideable {
    public typealias Stride = CS.BigInt

    public func advanced(by n: Stride) -> CS.BigInt {
        return self + n
    }

    public func distance(to other: CS.BigInt) -> Stride {
        return other - self
    }
}


