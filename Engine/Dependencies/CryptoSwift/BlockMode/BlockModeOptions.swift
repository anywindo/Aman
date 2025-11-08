// 
//  [BlockModeOptions].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

public struct BlockModeOption: OptionSet {
  public let rawValue: Int

  public init(rawValue: Int) {
    self.rawValue = rawValue
  }

  @usableFromInline
  static let none = BlockModeOption(rawValue: 1 << 0)

  @usableFromInline
  static let initializationVectorRequired = BlockModeOption(rawValue: 1 << 1)

  @usableFromInline
  static let paddingRequired = BlockModeOption(rawValue: 1 << 2)

  @usableFromInline
  static let useEncryptToDecrypt = BlockModeOption(rawValue: 1 << 3)
}
