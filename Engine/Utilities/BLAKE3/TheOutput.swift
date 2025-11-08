//import SIMDEndianBytes

struct TheOutput {
    private let inputChainingValue: KeyWords
    private let block: BlockWords
    private let blockLength: Int
    private let counter: UInt64
    private let flags: Flags
    
    init(_ chunkState: ChunkState) {
        inputChainingValue = chunkState.chainingValue
        var paddedBlock = chunkState.block
        if paddedBlock.count < BLAKE3.blockByteCount {
            paddedBlock.append(contentsOf: repeatElement(0, count: BLAKE3.blockByteCount - paddedBlock.count))
        }
        block = BlockWords(littleEndianBytes: paddedBlock)
        blockLength = chunkState.block.count
        counter = chunkState.counter
        flags = chunkState.flags.union(chunkState.startFlag).union(.chunkEnd)
    }
    
    init(key: KeyWords, left leftChild: KeyWords, right rightChild: KeyWords, flags: Flags) {
        inputChainingValue = key
        block = BlockWords(lowHalf: leftChild, highHalf: rightChild)
        blockLength = BLAKE3.blockByteCount
        counter = 0
        self.flags = flags.union(.parent)
    }
    
    var chainingValue: KeyWords {
        block.compressed(
            with: inputChainingValue,
            blockLength: blockLength,
            counter: counter,
            flags: flags
        ).lowHalf
    }
    
    func writeRootBytes<Output>(to output: inout Output, outputByteCount: Int)
    where Output: RangeReplaceableCollection, Output.Element == UInt8 {
        var remaining = outputByteCount
        var outputBlockCounter: UInt64 = 0
        
        while remaining > 0 {
            let words = block.compressed(
                with: inputChainingValue,
                blockLength: blockLength,
                counter: outputBlockCounter,
                flags: flags.union(.root)
            )
            
            output.append(contentsOf: words
                                        .indices
                                        .lazy
                                        .map { words[$0].littleEndianBytes() }
                                        .joined())
            
            if output.count > outputByteCount {
                // Trim without requiring BidirectionalCollection
                let desiredCount = outputByteCount
                let prefixSlice = output.prefix(desiredCount)
                output.removeAll(keepingCapacity: true)
                output.append(contentsOf: prefixSlice)
                break
            }
            
            remaining -= BLAKE3.blockByteCount
            outputBlockCounter += 1
        }
    }
}
