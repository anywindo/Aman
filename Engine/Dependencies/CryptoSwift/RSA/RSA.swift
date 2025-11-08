//
//  RSA.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//


import Foundation



public final class RSA: DERCodable {
  
  public enum Error: Swift.Error {
    
    case noPrivateKey
    
    case invalidInverseNotCoprimes
    
    case unsupportedRSAVersion
    
    case invalidPrimes
    
    case noPrimes
    
    case unableToCalculateCoefficient
    
    case invalidSignatureLength
    
    case invalidMessageLengthForSigning
    
    case invalidMessageLengthForEncryption
    
    case invalidDecryption
  }

  
  public let n: BigUInteger

  
  public let e: BigUInteger

  
  public let d: BigUInteger?

  
  public let keySize: Int

  
  public let keySizeBytes: Int

  
  public let primes: (p: BigUInteger, q: BigUInteger)?

  
  public init(n: BigUInteger, e: BigUInteger, d: BigUInteger? = nil) {
    self.n = n
    self.e = e
    self.d = d
    self.primes = nil

    self.keySize = n.bitWidth
    self.keySizeBytes = n.byteWidth
  }

  
  public convenience init(n: Array<UInt8>, e: Array<UInt8>, d: Array<UInt8>? = nil) {
    if let d = d {
      self.init(n: BigUInteger(Data(n)), e: BigUInteger(Data(e)), d: BigUInteger(Data(d)))
    } else {
      self.init(n: BigUInteger(Data(n)), e: BigUInteger(Data(e)))
    }
  }

  
  public convenience init(keySize: Int) throws {
  
    let p = BigUInteger.generatePrime(keySize / 2)
    let q = BigUInteger.generatePrime(keySize / 2)

    
    let n = p * q

   
    let e: BigUInteger = 65537
    let phi = (p - 1) * (q - 1)
    guard let d = e.inverse(phi) else {
      throw RSA.Error.invalidInverseNotCoprimes
    }

    
    try self.init(n: n, e: e, d: d, p: p, q: q)
  }

  
  public init(n: BigUInteger, e: BigUInteger, d: BigUInteger, p: BigUInteger, q: BigUInteger) throws {
   
    guard n == p * q else { throw Error.invalidPrimes }

    
    let phi = (p - 1) * (q - 1)
    guard d == e.inverse(phi) else { throw Error.invalidPrimes }

    
    self.n = n
    self.e = e
    self.d = d
    self.primes = (p, q)

    self.keySize = n.bitWidth
    self.keySizeBytes = n.byteWidth
  }
}

// MARK: BigUInt Extension

internal extension CS.BigUInt {
  
  var byteWidth: Int {
    let bytes = self.bitWidth / 8
    return self.bitWidth % 8 == 0 ? bytes : bytes + 1
  }
}

// MARK: DER Initializers (See #892)

extension RSA {
 
  internal convenience init(publicDER der: Array<UInt8>) throws {
    let asn = try ASN1.Decoder.decode(data: Data(der))

    
    guard case .sequence(let params) = asn else { throw DER.Error.invalidDERFormat }
    guard params.count == 2 else { throw DER.Error.invalidDERFormat }

    guard case .integer(let modulus) = params[0] else { throw DER.Error.invalidDERFormat }
    guard case .integer(let publicExponent) = params[1] else { throw DER.Error.invalidDERFormat }

    self.init(n: BigUInteger(modulus), e: BigUInteger(publicExponent))
  }

  
  internal convenience init(privateDER der: Array<UInt8>) throws {
    let asn = try ASN1.Decoder.decode(data: Data(der))

    
    guard case .sequence(let params) = asn else { throw DER.Error.invalidDERFormat }
    guard params.count == 9 else { throw DER.Error.invalidDERFormat }
    guard case .integer(let version) = params[0] else { throw DER.Error.invalidDERFormat }
    guard case .integer(let modulus) = params[1] else { throw DER.Error.invalidDERFormat }
    guard case .integer(let publicExponent) = params[2] else { throw DER.Error.invalidDERFormat }
    guard case .integer(let privateExponent) = params[3] else { throw DER.Error.invalidDERFormat }
    guard case .integer(let prime1) = params[4] else { throw DER.Error.invalidDERFormat }
    guard case .integer(let prime2) = params[5] else { throw DER.Error.invalidDERFormat }
    guard case .integer(let exponent1) = params[6] else { throw DER.Error.invalidDERFormat }
    guard case .integer(let exponent2) = params[7] else { throw DER.Error.invalidDERFormat }
    guard case .integer(let coefficient) = params[8] else { throw DER.Error.invalidDERFormat }

    
    guard version == Data(hex: "0x00") else { throw Error.unsupportedRSAVersion }

    
    let phi = (BigUInteger(prime1) - 1) * (BigUInteger(prime2) - 1)
    guard let d = BigUInteger(publicExponent).inverse(phi) else { throw Error.invalidPrimes }
    guard BigUInteger(privateExponent) == d else { throw Error.invalidPrimes }

    
    guard let calculatedCoefficient = BigUInteger(prime2).inverse(BigUInteger(prime1)) else { throw RSA.Error.unableToCalculateCoefficient }
    guard calculatedCoefficient == BigUInteger(coefficient) else { throw RSA.Error.invalidPrimes }

    
    guard (d % (BigUInteger(prime1) - 1)) == BigUInteger(exponent1) else { throw RSA.Error.invalidPrimes }
    guard (d % (BigUInteger(prime2) - 1)) == BigUInteger(exponent2) else { throw RSA.Error.invalidPrimes }

   
    try self.init(n: BigUInteger(modulus), e: BigUInteger(publicExponent), d: BigUInteger(privateExponent), p: BigUInteger(prime1), q: BigUInteger(prime2))
  }

  
  public convenience init(rawRepresentation raw: Data) throws {
    do { try self.init(privateDER: raw.byteArray) } catch {
      try self.init(publicDER: raw.byteArray)
    }
  }
}

// MARK: DER Exports (See #892)

extension RSA {
  
  func publicKeyDER() throws -> Array<UInt8> {
    let mod = self.n.serialize()
    let exp = self.e.serialize()
    let pubKeyAsnNode: ASN1.Node =
      .sequence(nodes: [
        .integer(data: DER.i2ospData(x: mod.byteArray, size: self.keySizeBytes)),
        .integer(data: DER.i2ospData(x: exp.byteArray, size: exp.byteArray.count))
      ])
    return ASN1.Encoder.encode(pubKeyAsnNode)
  }

  
  func privateKeyDER() throws -> Array<UInt8> {
    
    guard let d = d else { throw RSA.Error.noPrivateKey }
    guard let primes = primes else { throw RSA.Error.noPrimes }
    guard let coefficient = primes.q.inverse(primes.p) else { throw RSA.Error.unableToCalculateCoefficient }

    let paramWidth = self.keySizeBytes / 2
    let mod = self.n.serialize()
    let privateKeyAsnNode: ASN1.Node =
      .sequence(nodes: [
        .integer(data: Data(hex: "0x00")),
        .integer(data: DER.i2ospData(x: mod.byteArray, size: self.keySizeBytes)),
        .integer(data: DER.i2ospData(x: self.e.serialize().byteArray, size: 3)),
        .integer(data: DER.i2ospData(x: d.serialize().byteArray, size: self.keySizeBytes)),
        .integer(data: DER.i2ospData(x: primes.p.serialize().byteArray, size: paramWidth)),
        .integer(data: DER.i2ospData(x: primes.q.serialize().byteArray, size: paramWidth)),
        .integer(data: DER.i2ospData(x: (d % (primes.p - 1)).serialize().byteArray, size: paramWidth)),
        .integer(data: DER.i2ospData(x: (d % (primes.q - 1)).serialize().byteArray, size: paramWidth)),
        .integer(data: DER.i2ospData(x: coefficient.serialize().byteArray, size: paramWidth))
      ])

    return ASN1.Encoder.encode(privateKeyAsnNode)
  }

  
  public func externalRepresentation() throws -> Data {
    if self.d != nil {
      return try Data(self.privateKeyDER())
    } else {
      return try Data(self.publicKeyDER())
    }
  }

  public func publicKeyExternalRepresentation() throws -> Data {
    return try Data(self.publicKeyDER())
  }
}

// MARK: CS.BigUInt extension

extension BigUInteger {

  public static func generatePrime(_ width: Int) -> BigUInteger {
    while true {
      var random = BigUInteger.randomInteger(withExactWidth: width)
      random |= BigUInteger(1)
      if random.isPrime() {
        return random
      }
    }
  }
}

// MARK: CustomStringConvertible Conformance

extension RSA: CustomStringConvertible {
  public var description: String {
    if self.d != nil {
      return "CryptoSwift.RSA.PrivateKey<\(self.keySize)>"
    } else {
      return "CryptoSwift.RSA.PublicKey<\(self.keySize)>"
    }
  }
}
