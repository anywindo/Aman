// 
//  [BlockDecryptor].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public class BlockDecryptor: Cryptor, Updatable {

  public enum Error: Swift.Error {
    case unsupported
  }

  @usableFromInline
  let blockSize: Int

  @usableFromInline
  let padding: Padding

  @usableFromInline
  var worker: CipherModeWorker

  @usableFromInline
  var accumulated = Array<UInt8>()

  @usableFromInline
  init(blockSize: Int, padding: Padding, _ worker: CipherModeWorker) throws {
    self.blockSize = blockSize
    self.padding = padding
    self.worker = worker
  }

  @inlinable
  public func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool = false) throws -> Array<UInt8> {
    self.accumulated += bytes

    if !isLast && self.accumulated.count < self.blockSize + self.worker.additionalBufferSize {
      return []
    }

    let accumulatedWithoutSuffix: Array<UInt8>
    if self.worker.additionalBufferSize > 0 {
      accumulatedWithoutSuffix = Array(self.accumulated.prefix(self.accumulated.count - self.worker.additionalBufferSize))
    } else {
      accumulatedWithoutSuffix = self.accumulated
    }

    var processedBytesCount = 0
    var plaintext = Array<UInt8>(reserveCapacity: accumulatedWithoutSuffix.count)
    for var chunk in accumulatedWithoutSuffix.batched(by: self.blockSize) {
      if isLast || (accumulatedWithoutSuffix.count - processedBytesCount) >= blockSize {
        let isLastChunk = processedBytesCount + chunk.count == accumulatedWithoutSuffix.count

        if isLast, isLastChunk, var finalizingWorker = worker as? FinalizingDecryptModeWorker {
          chunk = try finalizingWorker.willDecryptLast(bytes: chunk + accumulated.suffix(worker.additionalBufferSize)) // tag size
        }

        if !chunk.isEmpty {
          plaintext += worker.decrypt(block: chunk)
        }

        if isLast, isLastChunk, var finalizingWorker = worker as? FinalizingDecryptModeWorker {
          plaintext = Array(try finalizingWorker.didDecryptLast(bytes: plaintext.slice))
        }

        processedBytesCount += chunk.count
      }
    }
    accumulated.removeFirst(processedBytesCount)

    if isLast {
      if accumulatedWithoutSuffix.isEmpty, var finalizingWorker = worker as? FinalizingDecryptModeWorker {
        try finalizingWorker.willDecryptLast(bytes: self.accumulated.suffix(self.worker.additionalBufferSize))
        plaintext = Array(try finalizingWorker.didDecryptLast(bytes: plaintext.slice))
      }
      plaintext = self.padding.remove(from: plaintext, blockSize: self.blockSize)
    }

    return plaintext
  }

  public func seek(to position: Int) throws {
    guard var worker = self.worker as? SeekableModeWorker else {
      throw Error.unsupported
    }

    try worker.seek(to: position)
    self.worker = worker

    accumulated = []
  }
}
