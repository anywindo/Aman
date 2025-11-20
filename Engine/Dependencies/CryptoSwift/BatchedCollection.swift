// 
//  [BatchedCollection].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

@usableFromInline
struct BatchedCollectionIndex<Base: Collection> {
  let range: Range<Base.Index>
}

extension BatchedCollectionIndex: Comparable {
  @usableFromInline
  static func == <BaseCollection>(lhs: BatchedCollectionIndex<BaseCollection>, rhs: BatchedCollectionIndex<BaseCollection>) -> Bool {
    lhs.range.lowerBound == rhs.range.lowerBound
  }

  @usableFromInline
  static func < <BaseCollection>(lhs: BatchedCollectionIndex<BaseCollection>, rhs: BatchedCollectionIndex<BaseCollection>) -> Bool {
    lhs.range.lowerBound < rhs.range.lowerBound
  }
}

protocol BatchedCollectionType: Collection {
  associatedtype Base: Collection
}

@usableFromInline
struct BatchedCollection<Base: Collection>: Collection {
  let base: Base
  let size: Int

  @usableFromInline
  init(base: Base, size: Int) {
    self.base = base
    self.size = size
  }

  @usableFromInline
  typealias Index = BatchedCollectionIndex<Base>

  private func nextBreak(after idx: Base.Index) -> Base.Index {
    self.base.index(idx, offsetBy: self.size, limitedBy: self.base.endIndex) ?? self.base.endIndex
  }

  @usableFromInline
  var startIndex: Index {
    Index(range: self.base.startIndex..<self.nextBreak(after: self.base.startIndex))
  }

  @usableFromInline
  var endIndex: Index {
    Index(range: self.base.endIndex..<self.base.endIndex)
  }

  @usableFromInline
  func index(after idx: Index) -> Index {
    Index(range: idx.range.upperBound..<self.nextBreak(after: idx.range.upperBound))
  }

  @usableFromInline
  subscript(idx: Index) -> Base.SubSequence {
    self.base[idx.range]
  }
}

extension Collection {
  @inlinable
  func batched(by size: Int) -> BatchedCollection<Self> {
    BatchedCollection(base: self, size: size)
  }
}
