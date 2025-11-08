// 
//  [Division].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

//MARK: Full-width multiplication and division

extension FixedWidthInteger {
    private var halfShift: Self {
        return Self(Self.bitWidth / 2)

    }
    private var high: Self {
        return self &>> halfShift
    }

    private var low: Self {
        let mask: Self = 1 &<< halfShift - 1
        return self & mask
    }

    private var upshifted: Self {
        return self &<< halfShift
    }

    private var split: (high: Self, low: Self) {
        return (self.high, self.low)
    }

    private init(_ value: (high: Self, low: Self)) {
        self = value.high.upshifted + value.low
    }

    internal func fastDividingFullWidth(_ dividend: (high: Self, low: Self.Magnitude)) -> (quotient: Self, remainder: Self) {
         precondition(dividend.high < self)

        func quotient(dividing u: (high: Self, low: Self), by vn: Self) -> Self {
            let (vn1, vn0) = vn.split
            let (q, r) = u.high.quotientAndRemainder(dividingBy: vn1)
            let p = q * vn0
           if q.high == 0 && p <= r.upshifted + u.low { return q }
            let r2 = r + vn1
            if r2.high != 0 { return q - 1 }
            if (q - 1).high == 0 && p - vn0 <= r2.upshifted + u.low { return q - 1 }
            return q - 2
        }
        func quotientAndRemainder(dividing u: (high: Self, low: Self), by v: Self) -> (quotient: Self, remainder: Self) {
            let q = quotient(dividing: u, by: v)
           let r = Self(u) &- q &* v
            assert(r < v)
            return (q, r)
        }

        let z = Self(self.leadingZeroBitCount)
        let w = Self(Self.bitWidth) - z
        let vn = self << z

        let un32 = (z == 0 ? dividend.high : (dividend.high &<< z) | ((dividend.low as! Self) &>> w)) // No bits are lost
        let un10 = dividend.low &<< z
        let (un1, un0) = un10.split

        let (q1, un21) = quotientAndRemainder(dividing: (un32, (un1 as! Self)), by: vn)
        let (q0, rn) = quotientAndRemainder(dividing: (un21, (un0 as! Self)), by: vn)

        let mod = rn >> z
        let div = Self((q1, q0))
        return (div, mod)
    }

    static func approximateQuotient(dividing x: (Self, Self, Self), by y: (Self, Self)) -> Self {
        var q: Self
        var r: Self
        if x.0 == y.0 {
            q = Self.max
            let (s, o) = x.0.addingReportingOverflow(x.1)
            if o { return q }
            r = s
        }
        else {
            (q, r) = y.0.fastDividingFullWidth((x.0, (x.1 as! Magnitude)))
        }
        let (ph, pl) = q.multipliedFullWidth(by: y.1)
        if ph < r || (ph == r && pl <= x.2) { return q }

        let (r1, ro) = r.addingReportingOverflow(y.0)
        if ro { return q - 1 }

        let (pl1, so) = pl.subtractingReportingOverflow((y.1 as! Magnitude))
        let ph1 = (so ? ph - 1 : ph)

        if ph1 < r1 || (ph1 == r1 && pl1 <= x.2) { return q - 1 }
        return q - 2
    }
}

extension CS.BigUInt {
    //MARK: Division

    internal mutating func divide(byWord y: Word) -> Word {
        precondition(y > 0)
        if y == 1 { return 0 }
        
        var remainder: Word = 0
        for i in (0 ..< count).reversed() {
            let u = self[i]
            (self[i], remainder) = y.fastDividingFullWidth((remainder, u))
        }
        return remainder
    }

    internal func quotientAndRemainder(dividingByWord y: Word) -> (quotient:  CS.BigUInt, remainder: Word) {
        var div = self
        let mod = div.divide(byWord: y)
        return (div, mod)
    }

    static func divide(_ x: inout  CS.BigUInt, by y: inout  CS.BigUInt) {
        
        precondition(!y.isZero)

        if x < y {
            (x, y) = (0, x)
            return
        }
        if y.count == 1 {
            y =  CS.BigUInt(x.divide(byWord: y[0]))
            return
        }

        let z = y.leadingZeroBitCount
        y <<= z
        x <<= z 
        var quotient =  CS.BigUInt()
        assert(y.leadingZeroBitCount == 0)

        let dc = y.count
        let d1 = y[dc - 1]
        let d0 = y[dc - 2]
        var product:  CS.BigUInt = 0
        for j in (dc ... x.count).reversed() {
            let r2 = x[j]
            let r1 = x[j - 1]
            let r0 = x[j - 2]
            let q = Word.approximateQuotient(dividing: (r2, r1, r0), by: (d1, d0))

            product.load(y)
            product.multiply(byWord: q)
            if product <= x.extract(j - dc ..< j + 1) {
                x.subtract(product, shiftedBy: j - dc)
                quotient[j - dc] = q
            }
            else {
                x.add(y, shiftedBy: j - dc)
                x.subtract(product, shiftedBy: j - dc)
                quotient[j - dc] = q - 1
            }
        }
        x >>= z
        y = x
        x = quotient
    }

    mutating func formRemainder(dividingBy y:  CS.BigUInt, normalizedBy shift: Int) {
        precondition(!y.isZero)
        assert(y.leadingZeroBitCount == 0)
        if y.count == 1 {
            let remainder = self.divide(byWord: y[0] >> shift)
            self.load(CS.BigUInt(remainder))
            return
        }
        self <<= shift
        if self >= y {
            let dc = y.count
            let d1 = y[dc - 1]
            let d0 = y[dc - 2]
            var product:  CS.BigUInt = 0
            for j in (dc ... self.count).reversed() {
                let r2 = self[j]
                let r1 = self[j - 1]
                let r0 = self[j - 2]
                let q = Word.approximateQuotient(dividing: (r2, r1, r0), by: (d1, d0))
                product.load(y)
                product.multiply(byWord: q)
                if product <= self.extract(j - dc ..< j + 1) {
                    self.subtract(product, shiftedBy: j - dc)
                }
                else {
                    self.add(y, shiftedBy: j - dc)
                    self.subtract(product, shiftedBy: j - dc)
                }
            }
        }
        self >>= shift
    }


    public func quotientAndRemainder(dividingBy y:  CS.BigUInt) -> (quotient:  CS.BigUInt, remainder:  CS.BigUInt) {
        var x = self
        var y = y
         CS.BigUInt.divide(&x, by: &y)
        return (x, y)
    }

    public static func /(x: CS.BigUInt, y: CS.BigUInt) -> CS.BigUInt {
        return x.quotientAndRemainder(dividingBy: y).quotient
    }

    public static func %(x: CS.BigUInt, y: CS.BigUInt) -> CS.BigUInt {
        var x = x
        let shift = y.leadingZeroBitCount
        x.formRemainder(dividingBy: y << shift, normalizedBy: shift)
        return x
    }

    public static func /=(x: inout  CS.BigUInt, y:  CS.BigUInt) {
        var y = y
         CS.BigUInt.divide(&x, by: &y)
    }

    public static func %=(x: inout CS.BigUInt, y: CS.BigUInt) {
        let shift = y.leadingZeroBitCount
        x.formRemainder(dividingBy: y << shift, normalizedBy: shift)
    }
}

extension CS.BigInt {
    public func quotientAndRemainder(dividingBy y: CS.BigInt) -> (quotient: CS.BigInt, remainder: CS.BigInt) {
        var a = self.magnitude
        var b = y.magnitude
         CS.BigUInt.divide(&a, by: &b)
        return ( CS.BigInt(sign: self.sign == y.sign ? .plus : .minus, magnitude: a),
                CS.BigInt(sign: self.sign, magnitude: b))
    }

    public static func /(a: CS.BigInt, b: CS.BigInt) -> CS.BigInt {
        return CS.BigInt(sign: a.sign == b.sign ? .plus : .minus, magnitude: a.magnitude / b.magnitude)
    }

    public static func %(a: CS.BigInt, b: CS.BigInt) -> CS.BigInt {
        return CS.BigInt(sign: a.sign, magnitude: a.magnitude % b.magnitude)
    }

    public func modulus(_ mod: CS.BigInt) -> CS.BigInt {
        let remainder = self.magnitude % mod.magnitude
        return CS.BigInt(
            self.sign == .minus && !remainder.isZero
                ? mod.magnitude - remainder
                : remainder)
    }
}

extension CS.BigInt {
    public static func /=(a: inout CS.BigInt, b: CS.BigInt) { a = a / b }
    public static func %=(a: inout CS.BigInt, b: CS.BigInt) { a = a % b }
}
