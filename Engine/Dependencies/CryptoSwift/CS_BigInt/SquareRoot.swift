// 
//  [SquareRoot].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

//MARK: Square Root

extension CS.BigUInt {
   public func squareRoot() -> CS.BigUInt {
        guard !self.isZero else { return CS.BigUInt() }
        var x = CS.BigUInt(1) << ((self.bitWidth + 1) / 2)
        var y: CS.BigUInt = 0
        while true {
            y.load(self)
            y /= x
            y += x
            y >>= 1
            if x == y || x == y - 1 { break }
            x = y
        }
        return x
    }
}

extension CS.BigInt {
    public func squareRoot() -> CS.BigInt {
        precondition(self.sign == .plus)
        return CS.BigInt(sign: .plus, magnitude: self.magnitude.squareRoot())
    }
}
