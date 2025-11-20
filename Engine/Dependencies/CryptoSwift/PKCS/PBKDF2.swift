// 
//  [PBKDF2].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

#if canImport(Darwin)
import Darwin
#elseif canImport(Android)
import Android
#elseif canImport(Glibc)
import Glibc
#elseif canImport(Musl)
import Musl
#elseif canImport(ucrt)
import ucrt
#elseif canImport(WASILibc)
import WASILibc
#endif

public extension PKCS5 {

  struct PBKDF2 {
    public enum Error: Swift.Error {
      case invalidInput
      case derivedKeyTooLong
    }

    private let salt: Array<UInt8> 
    fileprivate let iterations: Int
    private let numBlocks: Int
    private let dkLen: Int
    fileprivate let prf: HMAC


    public init(password: Array<UInt8>, salt: Array<UInt8>, iterations: Int = 4096 /* c */, keyLength: Int? = nil /* dkLen */, variant: HMAC.Variant = .sha2(.sha256)) throws {
      precondition(iterations > 0)

      let prf = HMAC(key: password, variant: variant)

      guard iterations > 0 && !salt.isEmpty else {
        throw Error.invalidInput
      }

      self.dkLen = keyLength ?? variant.digestLength
      let keyLengthFinal = Double(dkLen)
      let hLen = Double(prf.variant.digestLength)
      if keyLengthFinal > (pow(2, 32) - 1) * hLen {
        throw Error.derivedKeyTooLong
      }

      self.salt = salt
      self.iterations = iterations
      self.prf = prf

      self.numBlocks = Int(ceil(Double(keyLengthFinal) / hLen)) 
    }

    public func calculate() throws -> Array<UInt8> {
      var ret = Array<UInt8>()
      ret.reserveCapacity(self.numBlocks * self.prf.variant.digestLength)
      for i in 1...self.numBlocks {
        if let value = try calculateBlock(self.salt, blockNum: i) {
          ret.append(contentsOf: value)
        }
      }
      return Array(ret.prefix(self.dkLen))
    }

    public func callAsFunction() throws -> Array<UInt8> {
      try calculate()
    }
  }
}

private extension PKCS5.PBKDF2 {
  func ARR(_ i: Int) -> Array<UInt8> {
    var inti = Array<UInt8>(repeating: 0, count: 4)
    inti[0] = UInt8((i >> 24) & 0xff)
    inti[1] = UInt8((i >> 16) & 0xff)
    inti[2] = UInt8((i >> 8) & 0xff)
    inti[3] = UInt8(i & 0xff)
    return inti
  }


  func calculateBlock(_ salt: Array<UInt8>, blockNum: Int) throws -> Array<UInt8>? {
    guard let u1 = try? prf.authenticate(salt + ARR(blockNum)) else { // blockNum.bytes() is slower
      return nil
    }

    var u = u1
    var ret = u
    if iterations > 1 {

      for _ in 2...iterations {
        u = try prf.authenticate(u)
        for x in 0..<ret.count {
          ret[x] = ret[x] ^ u[x]
        }
      }
    }
    return ret
  }
}
