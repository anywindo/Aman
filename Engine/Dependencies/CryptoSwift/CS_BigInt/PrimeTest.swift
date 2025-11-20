// 
//  [PrimeTest].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

let primes: [CS.BigUInt.Word] = [2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41]

let pseudoPrimes: [CS.BigUInt] = [
    /*  2 */ 2_047,
    /*  3 */ 1_373_653,
    /*  5 */ 25_326_001,
    /*  7 */ 3_215_031_751,
    /* 11 */ 2_152_302_898_747,
    /* 13 */ 3_474_749_660_383,
    /* 17 */ 341_550_071_728_321,
    /* 19 */ 341_550_071_728_321,
    /* 23 */ 3_825_123_056_546_413_051,
    /* 29 */ 3_825_123_056_546_413_051,
    /* 31 */ 3_825_123_056_546_413_051,
    /* 37 */ "318665857834031151167461",
    /* 41 */ "3317044064679887385961981",
]

extension CS.BigUInt {
    //MARK: Primality Testing
public func isStrongProbablePrime(_ base: CS.BigUInt) -> Bool {
        precondition(base > (1 as CS.BigUInt))
        precondition(self > (0 as CS.BigUInt))
        let dec = self - 1

        let r = dec.trailingZeroBitCount
        let d = dec >> r

        var test = base.power(d, modulus: self)
        if test == 1 || test == dec { return true }

        if r > 0 {
            let shift = self.leadingZeroBitCount
            let normalized = self << shift
            for _ in 1 ..< r {
                test *= test
                test.formRemainder(dividingBy: normalized, normalizedBy: shift)
                if test == 1 {
                    return false
                }
                if test == dec { return true }
            }
        }
        return false
    }

     public func isPrime(rounds: Int = 10) -> Bool {
        if count <= 1 && self[0] < 2 { return false }
        if count == 1 && self[0] < 4 { return true }

        if self[0] & 1 == 0 { return false }

        for i in 1 ..< primes.count {
            let p = primes[i]
            if self.count == 1 && self[0] == p {
                return true
            }
            if self.quotientAndRemainder(dividingByWord: p).remainder == 0 {
                return false
            }
        }

        if self < pseudoPrimes.last! {
            for i in 0 ..< pseudoPrimes.count {
                guard isStrongProbablePrime(CS.BigUInt(primes[i])) else {
                    break
                }
                if self < pseudoPrimes[i] {
                    return true
                }
            }
            return false
        }

        for _ in 0 ..< rounds {
            let random = CS.BigUInt.randomInteger(lessThan: self - 2) + 2
            guard isStrongProbablePrime(random) else {
                return false
            }
        }

        return true
    }
}

extension CS.BigInt {
    //MARK: Primality Testing

   public func isStrongProbablePrime(_ base: CS.BigInt) -> Bool {
        precondition(base.sign == .plus)
        if self.sign == .minus { return false }
        return self.magnitude.isStrongProbablePrime(base.magnitude)
    }

    public func isPrime(rounds: Int = 10) -> Bool {
        if self.sign == .minus { return false }
        return self.magnitude.isPrime(rounds: rounds)
    }
}
