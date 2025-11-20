// 
//  [Data+Extension].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

extension Data {
  public func checksum() -> UInt16 {
    let s = self.withUnsafeBytes { buf in
        return buf.lazy.map(UInt32.init).reduce(UInt32(0), +)
    }
    return UInt16(s % 65535)
  }

  public func md5() -> Data {
    Data( Digest.md5(byteArray))
  }

  public func sha1() -> Data {
    Data( Digest.sha1(byteArray))
  }

  public func sha224() -> Data {
    Data( Digest.sha224(byteArray))
  }

  public func sha256() -> Data {
    Data( Digest.sha256(byteArray))
  }

  public func sha384() -> Data {
    Data( Digest.sha384(byteArray))
  }

  public func sha512() -> Data {
    Data( Digest.sha512(byteArray))
  }

  public func sha3(_ variant: SHA3.Variant) -> Data {
    Data( Digest.sha3(byteArray, variant: variant))
  }

  public func crc32(seed: UInt32? = nil, reflect: Bool = true) -> Data {
    Data( Checksum.crc32(byteArray, seed: seed, reflect: reflect).bytes())
  }

  public func crc32c(seed: UInt32? = nil, reflect: Bool = true) -> Data {
    Data( Checksum.crc32c(byteArray, seed: seed, reflect: reflect).bytes())
  }

  public func crc16(seed: UInt16? = nil) -> Data {
    Data( Checksum.crc16(byteArray, seed: seed).bytes())
  }

  public func encrypt(cipher: Cipher) throws -> Data {
    Data( try cipher.encrypt(byteArray.slice))
  }

  public func decrypt(cipher: Cipher) throws -> Data {
    Data( try cipher.decrypt(byteArray.slice))
  }

  public func authenticate(with authenticator: Authenticator) throws -> Data {
    Data( try authenticator.authenticate(byteArray))
  }
}

extension Data {
  public init(hex: String) {
    self.init(Array<UInt8>(hex: hex))
  }

  public var byteArray: Array<UInt8> {
    Array(self)
  }

  public func toHexString() -> String {
    self.byteArray.toHexString()
  }
}
