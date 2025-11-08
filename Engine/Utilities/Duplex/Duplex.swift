public protocol DuplexProtocol {
    associatedtype Output: Sequence where Output.Element == UInt8
    
    static var defaultOutputByteCount: Int { get }
    
    mutating func absorb(_ byte: UInt8)
    
    mutating func absorb<Bytes>(contentsOf bytes: Bytes)
    where Bytes: Sequence, Bytes.Element == UInt8
    
    mutating func squeeze<Output>(
        to output: inout Output,
        outputByteCount: Int
    ) where Output: RangeReplaceableCollection, Output.Element == UInt8
    
    mutating func squeeze<Output>(to output: inout Output)
    where Output: RangeReplaceableCollection, Output.Element == UInt8
    
    mutating func squeeze(outputByteCount: Int) -> Output
    
    mutating func squeeze() -> Output
}

public extension DuplexProtocol {
    mutating func absorb(_ byte: UInt8) {
        self.absorb(contentsOf: CollectionOfOne(byte))
    }
    
    mutating func squeeze<Output>(to output: inout Output)
    where Output: RangeReplaceableCollection, Output.Element == UInt8 {
        self.squeeze(to: &output, outputByteCount: Self.defaultOutputByteCount)
    }
    
    mutating func squeeze() -> Output {
        self.squeeze(outputByteCount: Self.defaultOutputByteCount)
    }
}

public protocol Duplex: DuplexProtocol {
    init()
    
    static func hash<Bytes, Output>(
        contentsOf bytes: Bytes,
        to output: inout Output,
        outputByteCount: Int
    ) where
        Bytes: Sequence,
        Bytes.Element == UInt8,
        Output: RangeReplaceableCollection,
        Output.Element == UInt8
    
    static func hash<Bytes, Output>(
        contentsOf bytes: Bytes,
        to output: inout Output
    ) where
        Bytes: Sequence,
        Bytes.Element == UInt8,
        Output: RangeReplaceableCollection,
        Output.Element == UInt8
    
    static func hash<Bytes>(contentsOf bytes: Bytes, outputByteCount: Int) -> Output
    where Bytes: Sequence, Bytes.Element == UInt8
    
    static func hash<Bytes>(contentsOf bytes: Bytes) -> Output
    where Bytes: Sequence, Bytes.Element == UInt8
}

public extension Duplex {
    static func hash<Bytes, Output>(
        contentsOf bytes: Bytes,
        to output: inout Output,
        outputByteCount: Int
    ) where
        Bytes: Sequence,
        Bytes.Element == UInt8,
        Output: RangeReplaceableCollection,
        Output.Element == UInt8
    {
        var duplex: Self = .init()
        duplex.absorb(contentsOf: bytes)
        duplex.squeeze(to: &output, outputByteCount: outputByteCount)
    }
    
    static func hash<Bytes, Output>(contentsOf bytes: Bytes, to output: inout Output)
    where
        Bytes: Sequence,
        Bytes.Element == UInt8,
        Output: RangeReplaceableCollection,
        Output.Element == UInt8
    {
        var duplex: Self = .init()
        duplex.absorb(contentsOf: bytes)
        duplex.squeeze(to: &output, outputByteCount: Self.defaultOutputByteCount)
    }
    
    static func hash<Bytes>(contentsOf bytes: Bytes, outputByteCount: Int) -> Output
    where Bytes: Sequence, Bytes.Element == UInt8 {
        var duplex: Self = .init()
        duplex.absorb(contentsOf: bytes)
        return duplex.squeeze(outputByteCount: outputByteCount)
    }
    
    static func hash<Bytes>(contentsOf bytes: Bytes) -> Output
    where Bytes: Sequence, Bytes.Element == UInt8 {
        var duplex: Self = .init()
        duplex.absorb(contentsOf: bytes)
        return duplex.squeeze(outputByteCount: Self.defaultOutputByteCount)
    }
}
