// 
//  [Padding].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public protocol PaddingProtocol {
  func add(to: Array<UInt8>, blockSize: Int) -> Array<UInt8>
  func remove(from: Array<UInt8>, blockSize: Int?) -> Array<UInt8>
}

public enum Padding: PaddingProtocol {
  case noPadding, zeroPadding, pkcs7, pkcs5, eme_pkcs1v15, emsa_pkcs1v15, iso78164, iso10126

  public func add(to: Array<UInt8>, blockSize: Int) -> Array<UInt8> {
    switch self {
      case .noPadding:
        return to
      case .zeroPadding:
        return ZeroPadding().add(to: to, blockSize: blockSize)
      case .pkcs7:
        return PKCS7.Padding().add(to: to, blockSize: blockSize)
      case .pkcs5:
        return PKCS5.Padding().add(to: to, blockSize: blockSize)
      case .eme_pkcs1v15:
        return EMEPKCS1v15Padding().add(to: to, blockSize: blockSize)
      case .emsa_pkcs1v15:
        return EMSAPKCS1v15Padding().add(to: to, blockSize: blockSize)
      case .iso78164:
        return ISO78164Padding().add(to: to, blockSize: blockSize)
      case .iso10126:
        return ISO10126Padding().add(to: to, blockSize: blockSize)
    }
  }

  public func remove(from: Array<UInt8>, blockSize: Int?) -> Array<UInt8> {
    switch self {
      case .noPadding:
        return from 
      case .zeroPadding:
        return ZeroPadding().remove(from: from, blockSize: blockSize)
      case .pkcs7:
        return PKCS7.Padding().remove(from: from, blockSize: blockSize)
      case .pkcs5:
        return PKCS5.Padding().remove(from: from, blockSize: blockSize)
      case .eme_pkcs1v15:
        return EMEPKCS1v15Padding().remove(from: from, blockSize: blockSize)
      case .emsa_pkcs1v15:
        return EMSAPKCS1v15Padding().remove(from: from, blockSize: blockSize)
      case .iso78164:
        return ISO78164Padding().remove(from: from, blockSize: blockSize)
      case .iso10126:
        return ISO10126Padding().remove(from: from, blockSize: blockSize)
    }
  }
}
