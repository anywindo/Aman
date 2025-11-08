//
//  RSA+Signature.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

// MARK: Signatures & Verification

extension RSA: Signature {
  public func sign(_ bytes: ArraySlice<UInt8>) throws -> Array<UInt8> {
    try self.sign(Array(bytes), variant: .message_pkcs1v15_SHA256)
  }

  
  public func sign(_ bytes: Array<UInt8>, variant: SignatureVariant) throws -> Array<UInt8> {
    guard let d = d else { throw RSA.Error.noPrivateKey }

    let hashedAndEncoded = try RSA.hashedAndEncoded(bytes, variant: variant, keySizeInBytes: self.keySizeBytes)

    let signedData = BigUInteger(Data(hashedAndEncoded)).power(d, modulus: self.n).serialize().byteArray

    return variant.formatSignedBytes(signedData, blockSize: self.keySizeBytes)
  }

  public func verify(signature: ArraySlice<UInt8>, for expectedData: ArraySlice<UInt8>) throws -> Bool {
    try self.verify(signature: Array(signature), for: Array(expectedData), variant: .message_pkcs1v15_SHA256)
  }

 
  public func verify(signature: Array<UInt8>, for bytes: Array<UInt8>, variant: SignatureVariant) throws -> Bool {
    guard signature.count == self.keySizeBytes else { throw Error.invalidSignatureLength }

    var expectedData = try RSA.hashedAndEncoded(bytes, variant: variant, keySizeInBytes: self.keySizeBytes)
    if expectedData.count == self.keySizeBytes && expectedData.prefix(1) == [0x00] { expectedData = Array(expectedData.dropFirst()) }

    let signatureResult = BigUInteger(Data(signature)).power(self.e, modulus: self.n).serialize().byteArray

    guard signatureResult == expectedData else { return false }

    return true
  }

 
  fileprivate static func hashedAndEncoded(_ bytes: [UInt8], variant: SignatureVariant, keySizeInBytes: Int) throws -> Array<UInt8> {
    let hashedMessage = variant.calculateHash(bytes)

    guard variant.enforceLength(hashedMessage, keySizeInBytes: keySizeInBytes) else { throw RSA.Error.invalidMessageLengthForSigning }

  
    let t = variant.encode(hashedMessage)

    if case .raw = variant { return t }

    if keySizeInBytes < t.count + 11 { throw RSA.Error.invalidMessageLengthForSigning }

   
    let padded = variant.pad(bytes: t, to: keySizeInBytes)

    guard padded.count == keySizeInBytes else { throw RSA.Error.invalidMessageLengthForSigning }

    return padded
  }
}

extension RSA {
  public enum SignatureVariant {
    case raw
    case message_pkcs1v15_MD5
    case message_pkcs1v15_SHA1
    case message_pkcs1v15_SHA224
    case message_pkcs1v15_SHA256
    case message_pkcs1v15_SHA384
    case message_pkcs1v15_SHA512
    case message_pkcs1v15_SHA512_224
    case message_pkcs1v15_SHA512_256
    case message_pkcs1v15_SHA3_256
    case message_pkcs1v15_SHA3_384
    case message_pkcs1v15_SHA3_512
    case digest_pkcs1v15_RAW
    case digest_pkcs1v15_MD5
    case digest_pkcs1v15_SHA1
    case digest_pkcs1v15_SHA224
    case digest_pkcs1v15_SHA256
    case digest_pkcs1v15_SHA384
    case digest_pkcs1v15_SHA512
    case digest_pkcs1v15_SHA512_224
    case digest_pkcs1v15_SHA512_256
    case digest_pkcs1v15_SHA3_256
    case digest_pkcs1v15_SHA3_384
    case digest_pkcs1v15_SHA3_512
    
    internal var identifier: Array<UInt8> {
      switch self {
        case .raw, .digest_pkcs1v15_RAW: return []
        case .message_pkcs1v15_MD5, .digest_pkcs1v15_MD5: return Array<UInt8>(arrayLiteral: 0x2a, 0x86, 0x48, 0x86, 0xf7, 0x0d, 0x02, 0x05)
        case .message_pkcs1v15_SHA1, .digest_pkcs1v15_SHA1: return Array<UInt8>(arrayLiteral: 0x2b, 0x0e, 0x03, 0x02, 0x1a)
        case .message_pkcs1v15_SHA256, .digest_pkcs1v15_SHA256: return Array<UInt8>(arrayLiteral: 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x01)
        case .message_pkcs1v15_SHA384, .digest_pkcs1v15_SHA384: return Array<UInt8>(arrayLiteral: 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x02)
        case .message_pkcs1v15_SHA512, .digest_pkcs1v15_SHA512: return Array<UInt8>(arrayLiteral: 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x03)
        case .message_pkcs1v15_SHA224, .digest_pkcs1v15_SHA224: return Array<UInt8>(arrayLiteral: 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x04)
        case .message_pkcs1v15_SHA512_224, .digest_pkcs1v15_SHA512_224: return Array<UInt8>(arrayLiteral: 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x05)
        case .message_pkcs1v15_SHA512_256, .digest_pkcs1v15_SHA512_256: return Array<UInt8>(arrayLiteral: 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x06)
        case .message_pkcs1v15_SHA3_256, .digest_pkcs1v15_SHA3_256: return Array<UInt8>(arrayLiteral: 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x08)
        case .message_pkcs1v15_SHA3_384, .digest_pkcs1v15_SHA3_384: return Array<UInt8>(arrayLiteral: 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x09)
        case .message_pkcs1v15_SHA3_512, .digest_pkcs1v15_SHA3_512: return Array<UInt8>(arrayLiteral: 0x60, 0x86, 0x48, 0x01, 0x65, 0x03, 0x04, 0x02, 0x0A)
      }
    }
    
    internal func calculateHash(_ bytes: Array<UInt8>) -> Array<UInt8> {
      switch self {
        case .message_pkcs1v15_MD5:
          return Digest.md5(bytes)
        case .message_pkcs1v15_SHA1:
          return Digest.sha1(bytes)
        case .message_pkcs1v15_SHA224:
          return Digest.sha224(bytes)
        case .message_pkcs1v15_SHA256:
          return Digest.sha256(bytes)
        case .message_pkcs1v15_SHA384:
          return Digest.sha384(bytes)
        case .message_pkcs1v15_SHA512:
          return Digest.sha512(bytes)
        case .message_pkcs1v15_SHA512_224:
          return Digest.sha2(bytes, variant: .sha224)
        case .message_pkcs1v15_SHA512_256:
          return Digest.sha2(bytes, variant: .sha256)
        case .message_pkcs1v15_SHA3_256:
          return Digest.sha3(bytes, variant: .sha256)
        case .message_pkcs1v15_SHA3_384:
          return Digest.sha3(bytes, variant: .sha384)
        case .message_pkcs1v15_SHA3_512:
          return Digest.sha3(bytes, variant: .sha512)
        case .raw,
            .digest_pkcs1v15_RAW,
            .digest_pkcs1v15_MD5,
            .digest_pkcs1v15_SHA1,
            .digest_pkcs1v15_SHA224,
            .digest_pkcs1v15_SHA256,
            .digest_pkcs1v15_SHA384,
            .digest_pkcs1v15_SHA512,
            .digest_pkcs1v15_SHA512_224,
            .digest_pkcs1v15_SHA512_256,
            .digest_pkcs1v15_SHA3_256,
            .digest_pkcs1v15_SHA3_384,
            .digest_pkcs1v15_SHA3_512:
        return bytes
      }
    }
    
    internal func enforceLength(_ bytes: Array<UInt8>, keySizeInBytes: Int) -> Bool {
      switch self {
        case .raw, .digest_pkcs1v15_RAW:
          return bytes.count <= keySizeInBytes
        case .digest_pkcs1v15_MD5:
          return bytes.count <= 16
        case .digest_pkcs1v15_SHA1:
          return bytes.count <= 20
        case .digest_pkcs1v15_SHA224:
          return bytes.count <= 28
        case .digest_pkcs1v15_SHA256, .digest_pkcs1v15_SHA3_256:
          return bytes.count <= 32
        case .digest_pkcs1v15_SHA384, .digest_pkcs1v15_SHA3_384:
          return bytes.count <= 48
        case .digest_pkcs1v15_SHA512, .digest_pkcs1v15_SHA3_512:
          return bytes.count <= 64
        case .digest_pkcs1v15_SHA512_224:
          return bytes.count <= 28
        case .digest_pkcs1v15_SHA512_256:
          return bytes.count <= 32
        case .message_pkcs1v15_MD5,
            .message_pkcs1v15_SHA1,
            .message_pkcs1v15_SHA224,
            .message_pkcs1v15_SHA256,
            .message_pkcs1v15_SHA384,
            .message_pkcs1v15_SHA512,
            .message_pkcs1v15_SHA512_224,
            .message_pkcs1v15_SHA512_256,
            .message_pkcs1v15_SHA3_256,
            .message_pkcs1v15_SHA3_384,
            .message_pkcs1v15_SHA3_512:
        return true
      }
    }

    internal func encode(_ bytes: Array<UInt8>) -> Array<UInt8> {
      switch self {
        case .raw, .digest_pkcs1v15_RAW:
          return bytes

        default:
          let asn: ASN1.Node = .sequence(nodes: [
            .sequence(nodes: [
              .objectIdentifier(data: Data(self.identifier)),
              .null
            ]),
            .octetString(data: Data(bytes))
          ])

          return ASN1.Encoder.encode(asn)
      }
    }

    internal func pad(bytes: Array<UInt8>, to blockSize: Int) -> Array<UInt8> {
      switch self {
        case .raw:
          return bytes
        default:
          return Padding.emsa_pkcs1v15.add(to: bytes, blockSize: blockSize)
      }
    }

   
    internal func formatSignedBytes(_ bytes: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
      switch self {
        default:
          return Array<UInt8>(repeating: 0x00, count: blockSize - bytes.count) + bytes
      }
    }
  }
}
