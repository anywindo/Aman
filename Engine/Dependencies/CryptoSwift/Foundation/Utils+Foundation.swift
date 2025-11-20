// 
//  [Utils+Foundation].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

func perf(_ text: String, closure: () -> Void) {
  let measurementStart = Date()

  closure()

  let measurementStop = Date()
  let executionTime = measurementStop.timeIntervalSince(measurementStart)

  print("\(text) \(executionTime)")
}
