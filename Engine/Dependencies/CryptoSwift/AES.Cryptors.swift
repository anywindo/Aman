//
//  AES.Cryptors.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

// MARK: Cryptors

extension AES: Cryptors {
  @inlinable
  public func makeEncryptor() throws -> Cryptor & Updatable {
    let blockSize = blockMode.customBlockSize ?? AES.blockSize
    let worker = try blockMode.worker(blockSize: blockSize, cipherOperation: encrypt, encryptionOperation: encrypt)
    if worker is StreamModeWorker {
      return try StreamEncryptor(blockSize: blockSize, padding: padding, worker)
    }
    return try BlockEncryptor(blockSize: blockSize, padding: padding, worker)
  }

  @inlinable
  public func makeDecryptor() throws -> Cryptor & Updatable {
    let blockSize = blockMode.customBlockSize ?? AES.blockSize
    let cipherOperation: CipherOperationOnBlock = blockMode.options.contains(.useEncryptToDecrypt) == true ? encrypt : decrypt
    let worker = try blockMode.worker(blockSize: blockSize, cipherOperation: cipherOperation, encryptionOperation: encrypt)
    if worker is StreamModeWorker {
      return try StreamDecryptor(blockSize: blockSize, padding: padding, worker)
    }
    return try BlockDecryptor(blockSize: blockSize, padding: padding, worker)
  }
}
