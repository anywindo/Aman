//
//  SlowModule.swift
//  Aman
//
//  Created by Samet Sazak
//

import Foundation

class SlowModule: SystemCheck {
    init() {
        super.init(
            name: "Slow Module",
            description: "A module that takes a long time to complete",
            category: "Performance",
            remediation: "None",
            severity: "Low",
            documentation: "",
            mitigation: "",
            checkstatus: "",
            docID: 0
        )
    }

    override func check() {
        sleep(30)
        status = "Module completed"
        checkstatus = "Green"
    }
}
