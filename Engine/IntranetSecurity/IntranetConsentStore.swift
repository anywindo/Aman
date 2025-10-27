//
//  IntranetConsentStore.swift
//  Aman
//
//  Persists user consent and runtime preferences for the intranet security scanner.
//

import Foundation

struct IntranetConsentState {
    var consented: Bool
    var targets: [String]

    init(
        consented: Bool,
        testMode: Bool = false,
        targets: [String],
        rateLimitMilliseconds: UInt = 250,
        maxParallelTargets: Int = 1,
        enableCVEMapping: Bool = true,
        authorizedNetworks: [String] = ["10.0.0.0/8", "172.16.0.0/12", "192.168.0.0/16"]
    ) {
        self.consented = consented
        self.targets = targets
    }
}

final class IntranetConsentStore {
    static let shared = IntranetConsentStore()

    private let defaults: UserDefaults

    private let consentKey = "com.arwindo.aman.intranet.consent"
    private let testModeKey = "com.arwindo.aman.intranet.testmode"
    private let targetsKey = "com.arwindo.aman.intranet.targets"
    private let rateLimitKey = "com.arwindo.aman.intranet.ratelimit"
    private let parallelKey = "com.arwindo.aman.intranet.parallel"
    private let cveKey = "com.arwindo.aman.intranet.cve"
    private let authorizedKey = "com.arwindo.aman.intranet.authorized"

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func currentState() -> IntranetConsentState {
        let consented = defaults.bool(forKey: consentKey)
        let targets = defaults.array(forKey: targetsKey) as? [String] ?? []

        return IntranetConsentState(
            consented: consented,
            targets: targets
        )
    }

    func save(state: IntranetConsentState) {
        defaults.set(state.consented, forKey: consentKey)
        defaults.set(state.targets, forKey: targetsKey)
    }

    // Legacy helper removed – configuration is now assembled directly in the view model.
}
