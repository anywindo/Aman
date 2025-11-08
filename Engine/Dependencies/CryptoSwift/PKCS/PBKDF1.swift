// 
//  [PBKDF1].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public extension PKCS5 {

  struct PBKDF1 {
    public enum Error: Swift.Error {
      case invalidInput
      case derivedKeyTooLong
    }

    public enum Variant {
      case md5, sha1

      @usableFromInline
      var size: Int {
        switch self {
          case .md5:
            return MD5.digestLength
          case .sha1:
            return SHA1.digestLength
        }
      }

      @usableFromInline
      func calculateHash(_ bytes: Array<UInt8>) -> Array<UInt8> {
        switch self {
          case .sha1:
            return Digest.sha1(bytes)
          case .md5:
            return Digest.md5(bytes)
        }
      }
    }

    @usableFromInline
    let iterations: Int // c

    @usableFromInline
    let variant: Variant

    @usableFromInline
    let keyLength: Int

    @usableFromInline
    let t1: Array<UInt8>

      public init(password: Array<UInt8>, salt: Array<UInt8>, variant: Variant = .sha1, iterations: Int = 4096 /* c */, keyLength: Int? = nil /* dkLen */ ) throws {
      precondition(iterations > 0)
      precondition(salt.count == 8)

      let keyLength = keyLength ?? variant.size

      if keyLength > variant.size {
        throw Error.derivedKeyTooLong
      }

      let t1 = variant.calculateHash(password + salt)

      self.iterations = iterations
      self.variant = variant
      self.keyLength = keyLength
      self.t1 = t1
    }

    @inlinable
    public func calculate() -> Array<UInt8> {
      var t = self.t1
      for _ in 2...self.iterations {
        t = self.variant.calculateHash(t)
      }
      return Array(t[0..<self.keyLength])
    }

    public func callAsFunction() -> Array<UInt8> {
      calculate()
    }
  }
}
