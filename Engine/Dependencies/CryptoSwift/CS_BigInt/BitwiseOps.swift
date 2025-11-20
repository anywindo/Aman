// 
//  [BitwiseOps].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

//MARK: Bitwise Operations

extension CS.BigUInt {
    public static prefix func ~(a: CS.BigUInt) -> CS.BigUInt {
        return CS.BigUInt(words: a.words.map { ~$0 })
    }

    public static func |= (a: inout CS.BigUInt, b: CS.BigUInt) {
        a.reserveCapacity(b.count)
        for i in 0 ..< b.count {
            a[i] |= b[i]
        }
    }

    public static func &= (a: inout CS.BigUInt, b: CS.BigUInt) {
        for i in 0 ..< Swift.max(a.count, b.count) {
            a[i] &= b[i]
        }
    }

    public static func ^= (a: inout CS.BigUInt, b: CS.BigUInt) {
        a.reserveCapacity(b.count)
        for i in 0 ..< b.count {
            a[i] ^= b[i]
        }
    }
}

extension CS.BigInt {
    public static prefix func ~(x: CS.BigInt) -> CS.BigInt {
        switch x.sign {
        case .plus:
            return CS.BigInt(sign: .minus, magnitude: x.magnitude + 1)
        case .minus:
            return CS.BigInt(sign: .plus, magnitude: x.magnitude - 1)
        }
    }
    
    public static func &(lhs: inout CS.BigInt, rhs: CS.BigInt) -> CS.BigInt {
        let left = lhs.words
        let right = rhs.words
        let count = Swift.max(lhs.magnitude.count, rhs.magnitude.count)
        var words: [UInt] = []
        words.reserveCapacity(count)
        for i in 0 ..< count {
            words.append(left[i] & right[i])
        }
        if lhs.sign == .minus && rhs.sign == .minus {
            words.twosComplement()
            return CS.BigInt(sign: .minus, magnitude: CS.BigUInt(words: words))
        }
        return CS.BigInt(sign: .plus, magnitude: CS.BigUInt(words: words))
    }
    
    public static func |(lhs: inout CS.BigInt, rhs: CS.BigInt) -> CS.BigInt {
        let left = lhs.words
        let right = rhs.words
        let count = Swift.max(lhs.magnitude.count, rhs.magnitude.count)
        var words: [UInt] = []
        words.reserveCapacity(count)
        for i in 0 ..< count {
            words.append(left[i] | right[i])
        }
        if lhs.sign == .minus || rhs.sign == .minus {
            words.twosComplement()
            return CS.BigInt(sign: .minus, magnitude: CS.BigUInt(words: words))
        }
        return CS.BigInt(sign: .plus, magnitude: CS.BigUInt(words: words))
    }
    
    public static func ^(lhs: inout CS.BigInt, rhs: CS.BigInt) -> CS.BigInt {
        let left = lhs.words
        let right = rhs.words
        let count = Swift.max(lhs.magnitude.count, rhs.magnitude.count)
        var words: [UInt] = []
        words.reserveCapacity(count)
        for i in 0 ..< count {
            words.append(left[i] ^ right[i])
        }
        if (lhs.sign == .minus) != (rhs.sign == .minus) {
            words.twosComplement()
            return CS.BigInt(sign: .minus, magnitude: CS.BigUInt(words: words))
        }
        return CS.BigInt(sign: .plus, magnitude: CS.BigUInt(words: words))
    }
    
    public static func &=(lhs: inout CS.BigInt, rhs: CS.BigInt) {
        lhs = lhs & rhs
    }
    
    public static func |=(lhs: inout CS.BigInt, rhs: CS.BigInt) {
        lhs = lhs | rhs
    }
    
    public static func ^=(lhs: inout CS.BigInt, rhs: CS.BigInt) {
        lhs = lhs ^ rhs
    }
}
