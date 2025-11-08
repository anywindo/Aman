// 
//  [DataConversion].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

extension CS.BigUInt {
    //MARK: NSData Conversion

    public init(_ buffer: UnsafeRawBufferPointer) {
        precondition(Word.bitWidth % 8 == 0)

        self.init()

        let length = buffer.count
        guard length > 0 else { return }
        let bytesPerDigit = Word.bitWidth / 8
        var index = length / bytesPerDigit
        var c = bytesPerDigit - length % bytesPerDigit
        if c == bytesPerDigit {
            c = 0
            index -= 1
        }

        var word: Word = 0
        for byte in buffer {
            word <<= 8
            word += Word(byte)
            c += 1
            if c == bytesPerDigit {
                self[index] = word
                index -= 1
                c = 0
                word = 0
            }
        }
        assert(c == 0 && word == 0 && index == -1)
    }



    public init(_ data: Data) {
        precondition(Word.bitWidth % 8 == 0)

        self.init()

        let length = data.count
        guard length > 0 else { return }
        let bytesPerDigit = Word.bitWidth / 8
        var index = length / bytesPerDigit
        var c = bytesPerDigit - length % bytesPerDigit
        if c == bytesPerDigit {
            c = 0
            index -= 1
        }
        let word: Word = data.withUnsafeBytes { buffPtr in
            var word: Word = 0
            let p = buffPtr.bindMemory(to: UInt8.self)
            for byte in p {
                word <<= 8
                word += Word(byte)
                c += 1
                if c == bytesPerDigit {
                    self[index] = word
                    index -= 1
                    c = 0
                    word = 0
                }
            }
            return word
        }
        assert(c == 0 && word == 0 && index == -1)
    }

    public func serialize() -> Data {
        precondition(Word.bitWidth % 8 == 0)

        let byteCount = (self.bitWidth + 7) / 8

        guard byteCount > 0 else { return Data() }

        var data = Data(count: byteCount)
        data.withUnsafeMutableBytes { buffPtr in
            let p = buffPtr.bindMemory(to: UInt8.self)
            var i = byteCount - 1
            for var word in self.words {
                for _ in 0 ..< Word.bitWidth / 8 {
                    p[i] = UInt8(word & 0xFF)
                    word >>= 8
                    if i == 0 {
                        assert(word == 0)
                        break
                    }
                    i -= 1
                }
            }
        }
        return data
    }
}

extension CS.BigInt {
    

    public init(_ buffer: UnsafeRawBufferPointer) {
        precondition(Word.bitWidth % 8 == 0)
        
        self.init()
        
        let length = buffer.count
        
      
        guard length > 1, let firstByte = buffer.first else { return }

       
        self.sign = firstByte & 0b1 == 0 ? .plus : .minus

        self.magnitude = CS.BigUInt(UnsafeRawBufferPointer(rebasing: buffer.dropFirst(1)))
    }
    
   
    public init(_ data: Data) {
        precondition(Word.bitWidth % 8 == 0)

        self.init()
        
        guard data.count > 1, let firstByte = data.first else { return }
        
        self.sign = firstByte & 0b1 == 0 ? .plus : .minus
        
        self.magnitude = CS.BigUInt(data.dropFirst(1))
    }
    
    public func serialize() -> Data {
        let magnitudeData = self.magnitude.serialize()
        
        guard magnitudeData.count > 0 else { return magnitudeData }
        
        var data = Data(capacity: magnitudeData.count + 1)
        

        data.append(self.sign == .plus ? 0 : 1)
        
        data.append(magnitudeData)
        return data
    }
}
