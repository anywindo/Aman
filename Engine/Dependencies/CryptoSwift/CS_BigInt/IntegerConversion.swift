// 
//  [IntegerConversion].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS.BigUInt {
    public init?<T: BinaryInteger>(exactly source: T) {
        guard source >= (0 as T) else { return nil }
        if source.bitWidth <= 2 * Word.bitWidth {
            var it = source.words.makeIterator()
            self.init(low: it.next() ?? 0, high: it.next() ?? 0)
            precondition(it.next() == nil, "Length of BinaryInteger.words is greater than its bitWidth")
        }
        else {
            self.init(words: source.words)
        }
    }

    public init<T: BinaryInteger>(_ source: T) {
        precondition(source >= (0 as T), "BigUInt cannot represent negative values")
        self.init(exactly: source)!
    }

    public init<T: BinaryInteger>(truncatingIfNeeded source: T) {
        self.init(words: source.words)
    }

    public init<T: BinaryInteger>(clamping source: T) {
        if source <= (0 as T) {
            self.init()
        }
        else {
            self.init(words: source.words)
        }
    }
}

extension CS.BigInt {
    public init() {
        self.init(sign: .plus, magnitude: 0)
    }

    public init(_ integer: CS.BigUInt) {
        self.magnitude = integer
        self.sign = .plus
    }

    public init<T>(_ source: T) where T : BinaryInteger {
        if source >= (0 as T) {
            self.init(sign: .plus, magnitude: CS.BigUInt(source))
        }
        else {
            var words = Array(source.words)
            words.twosComplement()
            self.init(sign: .minus, magnitude: CS.BigUInt(words: words))
        }
    }

    public init?<T>(exactly source: T) where T : BinaryInteger {
        self.init(source)
    }

    public init<T>(clamping source: T) where T : BinaryInteger {
        self.init(source)
    }

    public init<T>(truncatingIfNeeded source: T) where T : BinaryInteger {
        self.init(source)
    }
}

extension CS.BigUInt: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: UInt64) {
        self.init(value)
    }
}

extension CS.BigInt: ExpressibleByIntegerLiteral {
    public init(integerLiteral value: Int64) {
        self.init(value)
    }
}

