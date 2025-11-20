// 
//  [Addition].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS.BigUInt {
    //MARK: Addition
    
   
    internal mutating func addWord(_ word: Word, shiftedBy shift: Int = 0) {
        precondition(shift >= 0)
        var carry = word
        var i = shift
        while carry > 0 {
            let (d, c) = self[i].addingReportingOverflow(carry)
            self[i] = d
            carry = (c ? 1 : 0)
            i += 1
        }
    }

  
    internal func addingWord(_ word: Word, shiftedBy shift: Int = 0) -> CS.BigUInt {
        var r = self
        r.addWord(word, shiftedBy: shift)
        return r
    }

    
    internal mutating func add(_ b: CS.BigUInt, shiftedBy shift: Int = 0) {
        precondition(shift >= 0)
        var carry = false
        var bi = 0
        let bc = b.count
        while bi < bc || carry {
            let ai = shift + bi
            let (d, c) = self[ai].addingReportingOverflow(b[bi])
            if carry {
                let (d2, c2) = d.addingReportingOverflow(1)
                self[ai] = d2
                carry = c || c2
            }
            else {
                self[ai] = d
                carry = c
            }
            bi += 1
        }
    }

   
    internal func adding(_ b: CS.BigUInt, shiftedBy shift: Int = 0) -> CS.BigUInt {
        var r = self
        r.add(b, shiftedBy: shift)
        return r
    }

    
    internal mutating func increment(shiftedBy shift: Int = 0) {
        self.addWord(1, shiftedBy: shift)
    }

    public static func +(a: CS.BigUInt, b: CS.BigUInt) -> CS.BigUInt {
        return a.adding(b)
    }

    public static func +=(a: inout CS.BigUInt, b: CS.BigUInt) {
        a.add(b, shiftedBy: 0)
    }
}

extension CS.BigInt {
    public static func +(a: CS.BigInt, b: CS.BigInt) -> CS.BigInt {
        switch (a.sign, b.sign) {
        case (.plus, .plus):
            return CS.BigInt(sign: .plus, magnitude: a.magnitude + b.magnitude)
        case (.minus, .minus):
            return CS.BigInt(sign: .minus, magnitude: a.magnitude + b.magnitude)
        case (.plus, .minus):
            if a.magnitude >= b.magnitude {
                return CS.BigInt(sign: .plus, magnitude: a.magnitude - b.magnitude)
            }
            else {
                return CS.BigInt(sign: .minus, magnitude: b.magnitude - a.magnitude)
            }
        case (.minus, .plus):
            if b.magnitude >= a.magnitude {
                return CS.BigInt(sign: .plus, magnitude: b.magnitude - a.magnitude)
            }
            else {
                return CS.BigInt(sign: .minus, magnitude: a.magnitude - b.magnitude)
            }
        }
    }

    public static func +=(a: inout CS.BigInt, b: CS.BigInt) {
        a = a + b
    }
}

