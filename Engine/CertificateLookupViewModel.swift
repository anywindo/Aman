//
//  CertificateLookupViewModel.swift
//  Aman - Engine
//
//  Created by Aman Team on [Tanggal diedit, ex: 08/11/25].
//

import Foundation

@MainActor
final class CertificateLookupViewModel: ObservableObject {
    @Published var query: String = ""
    @Published private(set) var results: [CertificateEntry] = []
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let client: CRTShClient

    init(client: CRTShClient = CRTShClient()) {
        self.client = client
    }

    func performLookup() {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            results = []
            error = nil
            return
        }

        Task {
            await fetchCertificates(for: trimmed)
        }
    }

    func fetchCertificates(for domain: String) async {
        isLoading = true
        error = nil

        do {
            let entries = try await client.searchCertificates(for: domain)
            results = entries.sorted { lhs, rhs in
                lhs.entryTimestamp > rhs.entryTimestamp
            }
        } catch let err {
            results = []
            self.error = (err as? CRTError)?.localizedDescription ?? err.localizedDescription
        }

        isLoading = false
    }

    func clear() {
        query = ""
        results = []
        error = nil
    }
}
