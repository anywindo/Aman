// 
//  [Exponentiation].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS.BigUInt {
    //MARK: Exponentiation

    public func power(_ exponent: Int) -> CS.BigUInt {
        if exponent == 0 { return 1 }
        if exponent == 1 { return self }
        if exponent < 0 {
            precondition(!self.isZero)
            return self == 1 ? 1 : 0
        }
        if self <= 1 { return self }
        var result = CS.BigUInt(1)
        var b = self
        var e = exponent
        while e > 0 {
            if e & 1 == 1 {
                result *= b
            }
            e >>= 1
            b *= b
        }
        return result
    }

    public func power(_ exponent: CS.BigUInt, modulus: CS.BigUInt) -> CS.BigUInt {
        precondition(!modulus.isZero)
        if modulus == (1 as CS.BigUInt) { return 0 }
        let shift = modulus.leadingZeroBitCount
        let normalizedModulus = modulus << shift
        var result = CS.BigUInt(1)
        var b = self
        b.formRemainder(dividingBy: normalizedModulus, normalizedBy: shift)
        for var e in exponent.words {
            for _ in 0 ..< Word.bitWidth {
                if e & 1 == 1 {
                    result *= b
                    result.formRemainder(dividingBy: normalizedModulus, normalizedBy: shift)
                }
                e >>= 1
                b *= b
                b.formRemainder(dividingBy: normalizedModulus, normalizedBy: shift)
            }
        }
        return result
    }
}

extension CS.BigInt {
    public func power(_ exponent: Int) -> CS.BigInt {
        return CS.BigInt(sign: self.sign == .minus && exponent & 1 != 0 ? .minus : .plus,
                      magnitude: self.magnitude.power(exponent))
    }
public func power(_ exponent: CS.BigInt, modulus: CS.BigInt) -> CS.BigInt {
        precondition(!modulus.isZero)
        if modulus.magnitude == 1 { return 0 }
        if exponent.isZero { return 1 }
        if exponent == 1 { return self.modulus(modulus) }
        if exponent < 0 {
            precondition(!self.isZero)
            guard magnitude == 1 else { return 0 }
            guard sign == .minus else { return 1 }
            guard exponent.magnitude[0] & 1 != 0 else { return 1 }
            return CS.BigInt(modulus.magnitude - 1)
        }
        let power = self.magnitude.power(exponent.magnitude,
                                         modulus: modulus.magnitude)
        if self.sign == .plus || exponent.magnitude[0] & 1 == 0 || power.isZero {
            return CS.BigInt(power)
        }
        return CS.BigInt(modulus.magnitude - power)
    }
}
