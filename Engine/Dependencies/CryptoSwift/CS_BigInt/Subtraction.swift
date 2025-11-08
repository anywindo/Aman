// 
//  [Subtraction].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS.BigUInt {
    //MARK: Subtraction

     internal mutating func subtractWordReportingOverflow(_ word: Word, shiftedBy shift: Int = 0) -> Bool {
        precondition(shift >= 0)
        var carry: Word = word
        var i = shift
        let count = self.count
        while carry > 0 && i < count {
            let (d, c) = self[i].subtractingReportingOverflow(carry)
            self[i] = d
            carry = (c ? 1 : 0)
            i += 1
        }
        return carry > 0
    }

    
    internal func subtractingWordReportingOverflow(_ word: Word, shiftedBy shift: Int = 0) -> (partialValue: CS.BigUInt, overflow: Bool) {
        var result = self
        let overflow = result.subtractWordReportingOverflow(word, shiftedBy: shift)
        return (result, overflow)
    }

    
    internal mutating func subtractWord(_ word: Word, shiftedBy shift: Int = 0) {
        let overflow = subtractWordReportingOverflow(word, shiftedBy: shift)
        precondition(!overflow)
    }

    
    internal func subtractingWord(_ word: Word, shiftedBy shift: Int = 0) -> CS.BigUInt {
        var result = self
        result.subtractWord(word, shiftedBy: shift)
        return result
    }

    
    public mutating func subtractReportingOverflow(_ b: CS.BigUInt, shiftedBy shift: Int = 0) -> Bool {
        precondition(shift >= 0)
        var carry = false
        var bi = 0
        let bc = b.count
        let count = self.count
        while bi < bc || (shift + bi < count && carry) {
            let ai = shift + bi
            let (d, c) = self[ai].subtractingReportingOverflow(b[bi])
            if carry {
                let (d2, c2) = d.subtractingReportingOverflow(1)
                self[ai] = d2
                carry = c || c2
            }
            else {
                self[ai] = d
                carry = c
            }
            bi += 1
        }
        return carry
    }

    public func subtractingReportingOverflow(_ other: CS.BigUInt, shiftedBy shift: Int) -> (partialValue: CS.BigUInt, overflow: Bool) {
        var result = self
        let overflow = result.subtractReportingOverflow(other, shiftedBy: shift)
        return (result, overflow)
    }
    public func subtractingReportingOverflow(_ other: CS.BigUInt) -> (partialValue: CS.BigUInt, overflow: Bool) {
        return self.subtractingReportingOverflow(other, shiftedBy: 0)
    }
    
     public mutating func subtract(_ other: CS.BigUInt, shiftedBy shift: Int = 0) {
        let overflow = subtractReportingOverflow(other, shiftedBy: shift)
        precondition(!overflow)
    }

    public func subtracting(_ other: CS.BigUInt, shiftedBy shift: Int = 0) -> CS.BigUInt {
        var result = self
        result.subtract(other, shiftedBy: shift)
        return result
    }

    public mutating func decrement(shiftedBy shift: Int = 0) {
        self.subtract(1, shiftedBy: shift)
    }

    public static func -(a: CS.BigUInt, b: CS.BigUInt) -> CS.BigUInt {
        return a.subtracting(b)
    }

    public static func -=(a: inout CS.BigUInt, b: CS.BigUInt) {
        a.subtract(b)
    }
}

extension CS.BigInt {
    public mutating func negate() {
        guard !magnitude.isZero else { return }
        self.sign = self.sign == .plus ? .minus : .plus
    }

    public static func -(a: CS.BigInt, b: CS.BigInt) -> CS.BigInt {
        return a + -b
    }

    public static func -=(a: inout CS.BigInt, b: CS.BigInt) { a = a - b }
}
