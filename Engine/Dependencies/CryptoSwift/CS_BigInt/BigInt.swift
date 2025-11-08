// 
//  [BigInt].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

//MARK: CS.BigInt

extension CS {

  
  public struct BigInt: SignedInteger {
      public enum Sign {
          case plus
          case minus
      }

      public typealias Magnitude = BigUInt

      public typealias Word = BigUInt.Word

      public static var isSigned: Bool {
          return true
      }

      public var magnitude: BigUInt

      public var sign: Sign

      public init(sign: Sign, magnitude: BigUInt) {
          self.sign = (magnitude.isZero ? .plus : sign)
          self.magnitude = magnitude
      }


      public var isZero: Bool {
          return magnitude.isZero
      }

    public func signum() -> CS.BigInt {
          switch sign {
          case .plus:
              return isZero ? 0 : 1
          case .minus:
              return -1
          }
      }
  }

}
