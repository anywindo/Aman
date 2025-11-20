// 
//  [StringConversion].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS.BigUInt {

    //MARK: String Conversion

        fileprivate static func charsPerWord(forRadix radix: Int) -> (chars: Int, power: Word) {
        var power: Word = 1
        var overflow = false
        var count = 0
        while !overflow {
            let (high,low) = power.multipliedFullWidth(by: Word(radix))
            if high > 0 {
              overflow = true
            }

            if !overflow || (high == 1 && low == 0) {
                count += 1
                power = low
            }
        }
        return (count, power)
    }

    public init?<S: StringProtocol>(_ text: S, radix: Int = 10) {
        precondition(radix > 1 && radix < 36)
        guard !text.isEmpty else { return nil }
        let (charsPerWord, power) = CS.BigUInt.charsPerWord(forRadix: radix)

        var words: [Word] = []
        var end = text.endIndex
        var start = end
        var count = 0
        while start != text.startIndex {
            start = text.index(before: start)
            count += 1
            if count == charsPerWord {
                guard let d = Word.init(text[start ..< end], radix: radix) else { return nil }
                words.append(d)
                end = start
                count = 0
            }
        }
        if start != end {
            guard let d = Word.init(text[start ..< end], radix: radix) else { return nil }
            words.append(d)
        }

        if power == 0 {
            self.init(words: words)
        }
        else {
            self.init()
            for d in words.reversed() {
                self.multiply(byWord: power)
                self.addWord(d)
            }
        }
    }
}

extension CS.BigInt {
     public init?<S: StringProtocol>(_ text: S, radix: Int = 10) {
        var magnitude: CS.BigUInt?
        var sign: Sign = .plus
        if text.first == "-" {
            sign = .minus
            let text = text.dropFirst()
            magnitude = CS.BigUInt(text, radix: radix)
        }
        else if text.first == "+" {
            let text = text.dropFirst()
            magnitude = CS.BigUInt(text, radix: radix)
        }
        else {
            magnitude = CS.BigUInt(text, radix: radix)
        }
        guard let m = magnitude else { return nil }
        self.magnitude = m
        self.sign = m.isZero ? .plus : sign
    }
}

extension String {
      public init(_ v: CS.BigUInt) { self.init(v, radix: 10, uppercase: false) }

       public init(_ v: CS.BigUInt, radix: Int, uppercase: Bool = false) {
        precondition(radix > 1)
        let (charsPerWord, power) = CS.BigUInt.charsPerWord(forRadix: radix)

        guard !v.isZero else { self = "0"; return }

        var parts: [String]
        if power == 0 {
            parts = v.words.map { String($0, radix: radix, uppercase: uppercase) }
        }
        else {
            parts = []
            var rest = v
            while !rest.isZero {
                let mod = rest.divide(byWord: power)
                parts.append(String(mod, radix: radix, uppercase: uppercase))
            }
        }
        assert(!parts.isEmpty)

        self = ""
        var first = true
        for part in parts.reversed() {
            let zeroes = charsPerWord - part.count
            assert(zeroes >= 0)
            if !first && zeroes > 0 {
                self += String(repeating: "0", count: zeroes)
            }
            first = false
            self += part
        }
    }

   public init(_ value: CS.BigInt, radix: Int = 10, uppercase: Bool = false) {
        self = String(value.magnitude, radix: radix, uppercase: uppercase)
        if value.sign == .minus {
            self = "-" + self
        }
    }
}

extension CS.BigUInt: ExpressibleByStringLiteral {
   public init(unicodeScalarLiteral value: UnicodeScalar) {
        self = CS.BigUInt(String(value), radix: 10)!
    }

    public init(extendedGraphemeClusterLiteral value: String) {
        self = CS.BigUInt(value, radix: 10)!
    }

    public init(stringLiteral value: StringLiteralType) {
        self = CS.BigUInt(value, radix: 10)!
    }
}

extension CS.BigInt: ExpressibleByStringLiteral {
    
    public init(unicodeScalarLiteral value: UnicodeScalar) {
        self = CS.BigInt(String(value), radix: 10)!
    }

  
    public init(extendedGraphemeClusterLiteral value: String) {
        self = CS.BigInt(value, radix: 10)!
    }


    public init(stringLiteral value: StringLiteralType) {
        self = CS.BigInt(value, radix: 10)!
    }
}

extension CS.BigUInt: CustomStringConvertible {
    public var description: String {
        return String(self, radix: 10)
    }
}

extension CS.BigInt: CustomStringConvertible {
    public var description: String {
        return String(self, radix: 10)
    }
}

extension CS.BigUInt: CustomPlaygroundDisplayConvertible {

    public var playgroundDescription: Any {
        let text = String(self)
        return text + " (\(self.bitWidth) bits)"
    }
}

extension CS.BigInt: CustomPlaygroundDisplayConvertible {

    public var playgroundDescription: Any {
        let text = String(self)
        return text + " (\(self.magnitude.bitWidth) bits)"
    }
}
