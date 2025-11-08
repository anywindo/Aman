// 
//  [Random].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS.BigUInt {
 
    public static func randomInteger<RNG: RandomNumberGenerator>(withMaximumWidth width: Int, using generator: inout RNG) -> CS.BigUInt {
        var result = CS.BigUInt.zero
        var bitsLeft = width
        var i = 0
        let wordsNeeded = (width + Word.bitWidth - 1) / Word.bitWidth
        if wordsNeeded > 2 {
            result.reserveCapacity(wordsNeeded)
        }
        while bitsLeft >= Word.bitWidth {
            result[i] = generator.next()
            i += 1
            bitsLeft -= Word.bitWidth
        }
        if bitsLeft > 0 {
            let mask: Word = (1 << bitsLeft) - 1
            result[i] = (generator.next() as Word) & mask
        }
        return result
    }


    public static func randomInteger(withMaximumWidth width: Int) -> CS.BigUInt {
        var rng = SystemRandomNumberGenerator()
        return randomInteger(withMaximumWidth: width, using: &rng)
    }


    public static func randomInteger<RNG: RandomNumberGenerator>(withExactWidth width: Int, using generator: inout RNG) -> CS.BigUInt {

        guard width > 1 else { return CS.BigUInt(width) }
        var result = randomInteger(withMaximumWidth: width - 1, using: &generator)
        result[(width - 1) / Word.bitWidth] |= 1 << Word((width - 1) % Word.bitWidth)
        return result
    }


    public static func randomInteger(withExactWidth width: Int) -> CS.BigUInt {
        var rng = SystemRandomNumberGenerator()
        return randomInteger(withExactWidth: width, using: &rng)
    }


    public static func randomInteger<RNG: RandomNumberGenerator>(lessThan limit: CS.BigUInt, using generator: inout RNG) -> CS.BigUInt {
        precondition(limit > 0, "\(#function): 0 is not a valid limit")
        let width = limit.bitWidth
        var random = randomInteger(withMaximumWidth: width, using: &generator)
        while random >= limit {
            random = randomInteger(withMaximumWidth: width, using: &generator)
        }
        return random
    }


    public static func randomInteger(lessThan limit: CS.BigUInt) -> CS.BigUInt {
        var rng = SystemRandomNumberGenerator()
        return randomInteger(lessThan: limit, using: &rng)
    }
}
