//
//  AuditDomain.swift
//  Aman
//
//  Created by Codex.
//

import Foundation

enum AuditDomain: String, CaseIterable, Identifiable {
    case all = "All"
    case compliance = "Compliance"
    case privacy = "Privacy"
    case security = "Security"
    case network = "Network"
    case accounts = "Accounts"

    var id: String { rawValue }

    var title: String { rawValue }

    var iconName: String {
        switch self {
        case .all: return "list.bullet"
        case .compliance: return "checkmark.shield"
        case .privacy: return "lock.circle"
        case .security: return "shield.fill"
        case .network: return "dot.radiowaves.left.and.right"
        case .accounts: return "person.2.circle"
        }
    }
}
