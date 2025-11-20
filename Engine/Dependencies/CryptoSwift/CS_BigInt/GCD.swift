// 
//  [GCD].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS.BigUInt {
    //MARK: Greatest Common Divisor
    

    public func greatestCommonDivisor(with b: CS.BigUInt) -> CS.BigUInt {
        if self.isZero { return b }
        if b.isZero { return self }

        let az = self.trailingZeroBitCount
        let bz = b.trailingZeroBitCount
        let twos = Swift.min(az, bz)

        var (x, y) = (self >> az, b >> bz)
        if x < y { swap(&x, &y) }

        while !x.isZero {
            x >>= x.trailingZeroBitCount
            if x < y { swap(&x, &y) }
            x -= y
        }
        return y << twos
    }
    

    public func inverse(_ modulus: CS.BigUInt) -> CS.BigUInt? {
        precondition(modulus > 1)
        var t1 = CS.BigInt(0)
        var t2 = CS.BigInt(1)
        var r1 = modulus
        var r2 = self
        while !r2.isZero {
            let quotient = r1 / r2
            (t1, t2) = (t2, t1 - CS.BigInt(quotient) * t2)
            (r1, r2) = (r2, r1 - quotient * r2)
        }
        if r1 > 1 { return nil }
        if t1.sign == .minus { return modulus - t1.magnitude }
        return t1.magnitude
    }
}

extension CS.BigInt {

    public func greatestCommonDivisor(with b: CS.BigInt) -> CS.BigInt {
        return CS.BigInt(self.magnitude.greatestCommonDivisor(with: b.magnitude))
    }


    public func inverse(_ modulus: CS.BigInt) -> CS.BigInt? {
        guard let inv = self.magnitude.inverse(modulus.magnitude) else { return nil }
        return CS.BigInt(self.sign == .plus || inv.isZero ? inv : modulus.magnitude - inv)
    }
}
