// 
//  [CRTShClient].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

struct CertificateEntry: Codable, Identifiable, Hashable {
    let id: Int
    let issuerCAID: Int
    let issuerName: String
    let commonName: String
    let nameValue: String
    let entryTimestamp: String
    let notBefore: String
    let notAfter: String
    let serialNumber: String
    let resultCount: Int

    enum CodingKeys: String, CodingKey {
        case issuerCAID = "issuer_ca_id"
        case issuerName = "issuer_name"
        case commonName = "common_name"
        case nameValue = "name_value"
        case id
        case entryTimestamp = "entry_timestamp"
        case notBefore = "not_before"
        case notAfter = "not_after"
        case serialNumber = "serial_number"
        case resultCount = "result_count"
    }
}

enum CRTError: LocalizedError {
    case invalidURL
    case requestFailed
    case decodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Unable to form a crt.sh query URL."
        case .requestFailed:
            return "The certificate lookup request failed."
        case .decodingFailed:
            return "crt.sh returned data in an unexpected format."
        }
    }
}

final class CRTShClient {
    private let baseURL = "https://crt.sh/json?q="
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func searchCertificates(for domain: String) async throws -> [CertificateEntry] {
        guard !domain.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let encoded = domain.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: baseURL + encoded) else {
            throw CRTError.invalidURL
        }

        let (data, response) = try await session.data(from: url)

        guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
            throw CRTError.requestFailed
        }

        do {
            return try JSONDecoder().decode([CertificateEntry].self, from: data)
        } catch {
            throw CRTError.decodingFailed
        }
    }
}
