//
//  StreamDecryptor.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

@usableFromInline
final class StreamDecryptor: Cryptor, Updatable {

  @usableFromInline
  enum Error: Swift.Error {
    case unsupported
  }

  @usableFromInline
  internal let blockSize: Int

  @usableFromInline
  internal var worker: CipherModeWorker

  @usableFromInline
  internal let padding: Padding

  @usableFromInline
  internal var accumulated = Array<UInt8>()

  @usableFromInline
  internal var lastBlockRemainder = 0

  @usableFromInline
  init(blockSize: Int, padding: Padding, _ worker: CipherModeWorker) throws {
    self.blockSize = blockSize
    self.padding = padding
    self.worker = worker
  }

  // MARK: Updatable

  @inlinable
  public func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool) throws -> Array<UInt8> {
    self.accumulated += bytes

    let toProcess = self.accumulated.prefix(max(self.accumulated.count - self.worker.additionalBufferSize, 0))

    if var finalizingWorker = worker as? FinalizingDecryptModeWorker, isLast == true {
     
      try finalizingWorker.willDecryptLast(bytes: self.accumulated.slice)
    }

    var processedBytesCount = 0
    var plaintext = Array<UInt8>(reserveCapacity: bytes.count + self.worker.additionalBufferSize)
    for chunk in toProcess.batched(by: self.blockSize) {
      plaintext += self.worker.decrypt(block: chunk)
      processedBytesCount += chunk.count
    }

    if var finalizingWorker = worker as? FinalizingDecryptModeWorker, isLast == true {
      plaintext = Array(try finalizingWorker.didDecryptLast(bytes: plaintext.slice))
    }

    
    if self.padding != .noPadding {
      self.lastBlockRemainder = plaintext.count.quotientAndRemainder(dividingBy: self.blockSize).remainder
    }

    if isLast {
      
      plaintext = self.padding.remove(from: plaintext, blockSize: self.blockSize - self.lastBlockRemainder)
    }

    self.accumulated.removeFirst(processedBytesCount) // super-slow

    if var finalizingWorker = worker as? FinalizingDecryptModeWorker, isLast == true {
      plaintext = Array(try finalizingWorker.finalize(decrypt: plaintext.slice))
    }

    return plaintext
  }

  @inlinable
  public func seek(to position: Int) throws {
    guard var worker = self.worker as? SeekableModeWorker else {
      throw Error.unsupported
    }

    try worker.seek(to: position)
    self.worker = worker
  }
}
