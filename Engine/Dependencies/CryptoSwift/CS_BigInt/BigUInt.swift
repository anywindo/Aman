// 
//  [BigUInt].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

extension CS {

  public struct BigUInt: UnsignedInteger {
      public typealias Word = UInt

      enum Kind {
          case inline(Word, Word)
          case slice(from: Int, to: Int)
          case array
      }

      internal fileprivate(set) var kind: Kind 
      internal fileprivate(set) var storage: [Word] 

      public init() {
          self.kind = .inline(0, 0)
          self.storage = []
      }

      internal init(word: Word) {
          self.kind = .inline(word, 0)
          self.storage = []
      }

      internal init(low: Word, high: Word) {
          self.kind = .inline(low, high)
          self.storage = []
      }

      public init(words: [Word]) {
          self.kind = .array
          self.storage = words
          normalize()
      }

      internal init(words: [Word], from startIndex: Int, to endIndex: Int) {
          self.kind = .slice(from: startIndex, to: endIndex)
          self.storage = words
          normalize()
      }
  }

}

extension CS.BigUInt {
    public static var isSigned: Bool {
        return false
    }

    var isZero: Bool {
        switch kind {
        case .inline(0, 0): return true
        case .array: return storage.isEmpty
        default:
            return false
        }
    }

    public func signum() -> CS.BigUInt {
        return isZero ? 0 : 1
    }
}

extension CS.BigUInt {
    mutating func ensureArray() {
        switch kind {
        case let .inline(w0, w1):
            kind = .array
            storage = w1 != 0 ? [w0, w1]
                : w0 != 0 ? [w0]
                : []
        case let .slice(from: start, to: end):
            kind = .array
            storage = Array(storage[start ..< end])
        case .array:
            break
        }
    }

    var capacity: Int {
        guard case .array = kind else { return 0 }
        return storage.capacity
    }

    mutating func reserveCapacity(_ minimumCapacity: Int) {
        switch kind {
        case let .inline(w0, w1):
            kind = .array
            storage.reserveCapacity(minimumCapacity)
            if w1 != 0 {
                storage.append(w0)
                storage.append(w1)
            }
            else if w0 != 0 {
                storage.append(w0)
            }
        case let .slice(from: start, to: end):
            kind = .array
            var words: [Word] = []
            words.reserveCapacity(Swift.max(end - start, minimumCapacity))
            words.append(contentsOf: storage[start ..< end])
            storage = words
        case .array:
            storage.reserveCapacity(minimumCapacity)
        }
    }

    internal mutating func normalize() {
        switch kind {
        case .slice(from: let start, to: var end):
            assert(start >= 0 && end <= storage.count && start <= end)
            while start < end, storage[end - 1] == 0 {
                end -= 1
            }
            switch end - start {
            case 0:
                kind = .inline(0, 0)
                storage = []
            case 1:
                kind = .inline(storage[start], 0)
                storage = []
            case 2:
                kind = .inline(storage[start], storage[start + 1])
                storage = []
            case storage.count:
                assert(start == 0)
                kind = .array
            default:
                kind = .slice(from: start, to: end)
            }
        case .array where storage.last == 0:
            while storage.last == 0 {
                storage.removeLast()
            }
        default:
            break
        }
    }

    mutating func clear() {
        self.load(0)
    }

    mutating func load(_ value: CS.BigUInt) {
        switch kind {
        case .inline, .slice:
            self = value
        case .array:
            self.storage.removeAll(keepingCapacity: true)
            self.storage.append(contentsOf: value.words)
        }
    }
}

extension CS.BigUInt {
    //MARK: Collection-like members

    var count: Int {
        switch kind {
        case let .inline(w0, w1):
            return w1 != 0 ? 2
                : w0 != 0 ? 1
                : 0
        case let .slice(from: start, to: end):
            return end - start
        case .array:
            return storage.count
        }
    }

    
    subscript(_ index: Int) -> Word {
        get {
            precondition(index >= 0)
            switch (kind, index) {
            case (.inline(let w0, _), 0): return w0
            case (.inline(_, let w1), 1): return w1
            case (.slice(from: let start, to: let end), _) where index < end - start:
                return storage[start + index]
            case (.array, _) where index < storage.count:
                return storage[index]
            default:
                return 0
            }
        }
        set(word) {
            precondition(index >= 0)
            switch (kind, index) {
            case let (.inline(_, w1), 0):
                kind = .inline(word, w1)
            case let (.inline(w0, _), 1):
                kind = .inline(w0, word)
            case let (.slice(from: start, to: end), _) where index < end - start:
                replace(at: index, with: word)
            case (.array, _) where index < storage.count:
                replace(at: index, with: word)
            default:
                extend(at: index, with: word)
            }
        }
    }

    private mutating func replace(at index: Int, with word: Word) {
        ensureArray()
        precondition(index < storage.count)
        storage[index] = word
        if word == 0, index == storage.count - 1 {
            normalize()
        }
    }

    private mutating func extend(at index: Int, with word: Word) {
        guard word != 0 else { return }
        reserveCapacity(index + 1)
        precondition(index >= storage.count)
        storage.append(contentsOf: repeatElement(0, count: index - storage.count))
        storage.append(word)
    }

    internal func extract(_ bounds: Range<Int>) -> CS.BigUInt {
        switch kind {
        case let .inline(w0, w1):
            let bounds = bounds.clamped(to: 0 ..< 2)
            if bounds == 0 ..< 2 {
                return CS.BigUInt(low: w0, high: w1)
            }
            else if bounds == 0 ..< 1 {
                return CS.BigUInt(word: w0)
            }
            else if bounds == 1 ..< 2 {
                return CS.BigUInt(word: w1)
            }
            else {
                return CS.BigUInt()
            }
        case let .slice(from: start, to: end):
            let s = Swift.min(end, start + Swift.max(bounds.lowerBound, 0))
            let e = Swift.max(s, (bounds.upperBound > end - start ? end : start + bounds.upperBound))
            return CS.BigUInt(words: storage, from: s, to: e)
        case .array:
            let b = bounds.clamped(to: storage.startIndex ..< storage.endIndex)
            return CS.BigUInt(words: storage, from: b.lowerBound, to: b.upperBound)
        }
    }

    internal func extract<Bounds: RangeExpression>(_ bounds: Bounds) -> CS.BigUInt where Bounds.Bound == Int {
        return self.extract(bounds.relative(to: 0 ..< Int.max))
    }
}

extension CS.BigUInt {
    internal mutating func shiftRight(byWords amount: Int) {
        assert(amount >= 0)
        guard amount > 0 else { return }
        switch kind {
        case let .inline(_, w1) where amount == 1:
            kind = .inline(w1, 0)
        case .inline(_, _):
            kind = .inline(0, 0)
        case let .slice(from: start, to: end):
            let s = start + amount
            if s >= end {
                kind = .inline(0, 0)
            }
            else {
                kind = .slice(from: s, to: end)
                normalize()
            }
        case .array:
            if amount >= storage.count {
                storage.removeAll(keepingCapacity: true)
            }
            else {
                storage.removeFirst(amount)
            }
        }
    }

    internal mutating func shiftLeft(byWords amount: Int) {
        assert(amount >= 0)
        guard amount > 0 else { return }
        guard !isZero else { return }
        switch kind {
        case let .inline(w0, 0) where amount == 1:
            kind = .inline(0, w0)
        case let .inline(w0, w1):
            let c = (w1 == 0 ? 1 : 2)
            storage.reserveCapacity(amount + c)
            storage.append(contentsOf: repeatElement(0, count: amount))
            storage.append(w0)
            if w1 != 0 {
                storage.append(w1)
            }
            kind = .array
        case let .slice(from: start, to: end):
            var words: [Word] = []
            words.reserveCapacity(amount + count)
            words.append(contentsOf: repeatElement(0, count: amount))
            words.append(contentsOf: storage[start ..< end])
            storage = words
            kind = .array
        case .array:
            storage.insert(contentsOf: repeatElement(0, count: amount), at: 0)
        }
    }
}

extension CS.BigUInt {
    //MARK: Low and High

    internal var split: (high: CS.BigUInt, low: CS.BigUInt) {
        precondition(count > 1)
        let mid = middleIndex
        return (self.extract(mid...), self.extract(..<mid))
    }

    internal var middleIndex: Int {
        return (count + 1) / 2
    }

     internal var low: CS.BigUInt {
        return self.extract(0 ..< middleIndex)
    }

    
    internal var high: CS.BigUInt {
        return self.extract(middleIndex ..< count)
    }
}
