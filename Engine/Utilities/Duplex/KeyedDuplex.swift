public protocol KeyedDuplexProtocol: DuplexProtocol {
    associatedtype EncryptionOutput: Sequence where EncryptionOutput.Element == UInt8
    
    associatedtype DecryptionOutput: Sequence where DecryptionOutput.Element == UInt8
    
    mutating func encrypt<Bytes, Output>(contentsOf bytes: Bytes, to output: inout Output)
    where
        Bytes: Sequence, Bytes.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    
    mutating func encrypt<Bytes>(contentsOf bytes: Bytes) -> Self.EncryptionOutput
    where Bytes: Sequence, Bytes.Element == UInt8
    
    mutating func decrypt<Bytes, Output>(contentsOf bytes: Bytes, to output: inout Output)
    where
        Bytes: Sequence, Bytes.Element == UInt8,
        Output: RangeReplaceableCollection, Output.Element == UInt8
    
    mutating func decrypt<Bytes>(contentsOf bytes: Bytes) -> Self.DecryptionOutput
    where Bytes: Sequence, Bytes.Element == UInt8
    
    mutating func ratchet()
}
