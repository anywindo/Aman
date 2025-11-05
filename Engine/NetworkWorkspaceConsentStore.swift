//
//  NetworkWorkspaceConsentStore.swift
//  Aman
//
//  Persists consent decisions for Network Analyzer and Network Mapping tooling.
//

import Foundation

enum NetworkConsentFeature: String, CaseIterable {
    case analyzer
    case mapping

    var defaultsKey: String {
        switch self {
        case .analyzer:
            return "com.arwindo.aman.network.consent.analyzer"
        case .mapping:
            return "com.arwindo.aman.network.consent.mapping"
        }
    }

    var displayName: String {
        switch self {
        case .analyzer:
            return "Network Analyzer"
        case .mapping:
            return "Network Mapping"
        }
    }
}

final class NetworkWorkspaceConsentStore: ObservableObject {
    @Published private var grantedFeatures: Set<NetworkConsentFeature> = []

    func hasConsent(for feature: NetworkConsentFeature) -> Bool {
        grantedFeatures.contains(feature)
    }

    func recordConsent(_ granted: Bool, for feature: NetworkConsentFeature) {
        if granted {
            grantedFeatures.insert(feature)
        } else {
            grantedFeatures.remove(feature)
        }
    }
}
