// 
//  [Whirlpool].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation
public struct Whirlpool {
    private var nessie = NESSIEstruct()

    public init() {
        NESSIEinit(&nessie)
    }

    
    public mutating func update(data: Data) {
        let dataArray = [UInt8](data) 
        NESSIEadd(dataArray, UInt(dataArray.count * 8), &nessie)
    }

    public mutating func finalize() -> Data {
        var result = [UInt8](repeating: 0, count: 64)

        NESSIEfinalize(&nessie, &result)

        return Data(result)
    }

    public static func hash(data: Data) -> Data {
        var whirlpool = Whirlpool()
        whirlpool.update(data: data)
        return whirlpool.finalize()
    }
}
