// 
//  [CipherModeWorker].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public protocol CipherModeWorker {
  var cipherOperation: CipherOperationOnBlock { get }

  var additionalBufferSize: Int { get }

  @inlinable
  mutating func encrypt(block plaintext: ArraySlice<UInt8>) -> Array<UInt8>

  @inlinable
  mutating func decrypt(block ciphertext: ArraySlice<UInt8>) -> Array<UInt8>
}

public protocol BlockModeWorker: CipherModeWorker {
  var blockSize: Int { get }
}

public protocol CounterModeWorker: CipherModeWorker {
  associatedtype Counter
  var counter: Counter { get set }
}

public protocol SeekableModeWorker: CipherModeWorker {
  mutating func seek(to position: Int) throws
}

public protocol StreamModeWorker: CipherModeWorker {
}

public protocol FinalizingEncryptModeWorker: CipherModeWorker {

  mutating func finalize(encrypt ciphertext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8>
}

public protocol FinalizingDecryptModeWorker: CipherModeWorker {

  @discardableResult
  mutating func willDecryptLast(bytes ciphertext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8>
  mutating func didDecryptLast(bytes plaintext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8>

  mutating func finalize(decrypt plaintext: ArraySlice<UInt8>) throws -> ArraySlice<UInt8>
}
