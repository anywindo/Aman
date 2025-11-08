//
//  CBCMAC.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

public final class CBCMAC: CMAC {
  public override func authenticate(_ bytes: Array<UInt8>) throws -> Array<UInt8> {
    var inBytes = bytes
    bitPadding(to: &inBytes, blockSize: CMAC.BlockSize)
    let blocks = inBytes.batched(by: CMAC.BlockSize)

    var lastBlockEncryptionResult: [UInt8] = CBCMAC.Zero
    try blocks.forEach { block in
      let aes = try AES(key: Array(key), blockMode: CBC(iv: lastBlockEncryptionResult), padding: .noPadding)
      lastBlockEncryptionResult = try aes.encrypt(block)
    }

    return lastBlockEncryptionResult
  }
}
