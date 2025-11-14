//
//  BlockEncryptor.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

@usableFromInline
final class BlockEncryptor: Cryptor, Updatable {

  public enum Error: Swift.Error {
    case unsupported
  }

  private let blockSize: Int
  private var worker: CipherModeWorker
  private let padding: Padding
  
  private var accumulated = Array<UInt8>(reserveCapacity: 16)

  private var lastBlockRemainder = 0

  @usableFromInline
  init(blockSize: Int, padding: Padding, _ worker: CipherModeWorker) throws {
    self.blockSize = blockSize
    self.padding = padding
    self.worker = worker
  }

  // MARK: Updatable

  public func update(withBytes bytes: ArraySlice<UInt8>, isLast: Bool) throws -> Array<UInt8> {
    self.accumulated += bytes

    if isLast {
      self.accumulated = self.padding.add(to: self.accumulated, blockSize: self.blockSize)
    }

    var encrypted = Array<UInt8>(reserveCapacity: accumulated.count)
    for chunk in self.accumulated.batched(by: self.blockSize) {
      if isLast || chunk.count == self.blockSize {
        encrypted += self.worker.encrypt(block: chunk)
      }
    }

    
    self.accumulated.removeFirst(encrypted.count)

    if var finalizingWorker = worker as? FinalizingEncryptModeWorker, isLast == true {
      encrypted = Array(try finalizingWorker.finalize(encrypt: encrypted.slice))
    }

    return encrypted
  }

  @usableFromInline
  func seek(to: Int) throws {
    throw Error.unsupported
  }
}
