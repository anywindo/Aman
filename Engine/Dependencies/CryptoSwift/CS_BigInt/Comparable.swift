// 
//  [Comparable].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

extension CS.BigUInt: Comparable {
    //MARK: Comparison
    
    public static func compare(_ a: CS.BigUInt, _ b: CS.BigUInt) -> ComparisonResult {
        if a.count != b.count { return a.count > b.count ? .orderedDescending : .orderedAscending }
        for i in (0 ..< a.count).reversed() {
            let ad = a[i]
            let bd = b[i]
            if ad != bd { return ad > bd ? .orderedDescending : .orderedAscending }
        }
        return .orderedSame
    }

    public static func ==(a: CS.BigUInt, b: CS.BigUInt) -> Bool {
        return CS.BigUInt.compare(a, b) == .orderedSame
    }

    
    public static func <(a: CS.BigUInt, b: CS.BigUInt) -> Bool {
        return CS.BigUInt.compare(a, b) == .orderedAscending
    }
}

extension CS.BigInt {
    public static func ==(a: CS.BigInt, b: CS.BigInt) -> Bool {
        return a.sign == b.sign && a.magnitude == b.magnitude
    }

    public static func <(a: CS.BigInt, b: CS.BigInt) -> Bool {
        switch (a.sign, b.sign) {
        case (.plus, .plus):
            return a.magnitude < b.magnitude
        case (.plus, .minus):
            return false
        case (.minus, .plus):
            return true
        case (.minus, .minus):
            return a.magnitude > b.magnitude
        }
    }
}


