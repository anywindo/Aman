//
//  EnrichmentService.swift
//  Aman
//
//  GeoIP detail and RDAP/WHOIS enrichment with TTL caching.
//

import Foundation

final class EnrichmentService {
    struct GeoASN {
        let city: String?
        let region: String?
        let country: String?
        let lat: Double?
        let lon: Double?
        let isp: String?
        let asn: String?
    }

    struct RDAPResult {
        let registry: String?
        let registrationDate: Date?
    }

    private let session: URLSession
    private let ipCache = TTLCache<String, GeoASN>()
    private let asnCache = TTLCache<String, RDAPResult>()
    private let rdapIPCache = TTLCache<String, RDAPResult>()
    private let defaultTTL: TimeInterval

    init(
        session: URLSession = InternetSecurityToolkit.makeDefaultSession(),
        ttl: TimeInterval = 45 * 60
    ) {
        self.session = session
        self.defaultTTL = ttl
    }

    // MARK: - GeoIP

    func fetchGeoAndASN(publicIP: String) async throws -> GeoASN {
        if let cached = await ipCache.get(publicIP) {
            return cached
        }

        guard let url = URL(string: "https://ipinfo.io/\(publicIP)/json") else {
            throw URLError(.badURL)
        }
        var req = URLRequest(url: url)
        req.timeoutInterval = 15

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw URLError(.badServerResponse)
        }

        struct IPInfo: Decodable {
            let ip: String
            let city: String?
            let region: String?
            let country: String?
            let org: String?
            let loc: String?
        }

        let decoded = try JSONDecoder().decode(IPInfo.self, from: data)
        let ispOrg = decoded.org
        let asnToken = ispOrg?
            .split(separator: " ")
            .first
            .map(String.init)
            .flatMap { $0.uppercased().hasPrefix("AS") ? $0 : nil }

        var lat: Double?
        var lon: Double?
        if let loc = decoded.loc {
            let parts = loc.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
            if parts.count == 2 {
                lat = Double(parts[0])
                lon = Double(parts[1])
            }
        }

        let result = GeoASN(
            city: decoded.city,
            region: decoded.region,
            country: decoded.country,
            lat: lat,
            lon: lon,
            isp: ispOrg,
            asn: asnToken
        )

        await ipCache.set(publicIP, value: result, ttl: defaultTTL)
        return result
    }

    // MARK: - RDAP for IP

    func fetchRDAPForIP(publicIP: String) async throws -> RDAPResult {
        if let cached = await rdapIPCache.get(publicIP) {
            return cached
        }

        // Try ARIN first; if not found, try other RIRs
        let rdapURLs = [
            "https://rdap.arin.net/registry/ip/\(publicIP)",
            "https://rdap.apnic.net/ip/\(publicIP)",
            "https://rdap.db.ripe.net/ip/\(publicIP)",
            "https://rdap.lacnic.net/rdap/ip/\(publicIP)",
            "https://rdap.afrinic.net/rdap/ip/\(publicIP)"
        ]

        if let result = try await firstRDAPHit(from: rdapURLs) {
            await rdapIPCache.set(publicIP, value: result, ttl: defaultTTL)
            return result
        }

        // If all fail
        throw URLError(.cannotLoadFromNetwork)
    }

    // MARK: - RDAP for ASN

    func fetchRDAPForASN(asn: String) async throws -> RDAPResult {
        if let cached = await asnCache.get(asn) {
            return cached
        }

        // Normalize "AS12345" -> "12345"
        let digits = asn.uppercased().replacingOccurrences(of: "AS", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let rdapURLs = [
            "https://rdap.arin.net/registry/autnum/\(digits)",
            "https://rdap.apnic.net/autnum/\(digits)",
            "https://rdap.db.ripe.net/autnum/\(digits)",
            "https://rdap.lacnic.net/rdap/autnum/\(digits)",
            "https://rdap.afrinic.net/rdap/autnum/\(digits)"
        ]

        if let result = try await firstRDAPHit(from: rdapURLs) {
            await asnCache.set(asn, value: result, ttl: defaultTTL)
            return result
        }

        throw URLError(.cannotLoadFromNetwork)
    }

    // MARK: - Helpers

    private func firstRDAPHit(from urls: [String]) async throws -> RDAPResult? {
        for raw in urls {
            guard let url = URL(string: raw) else { continue }
            var req = URLRequest(url: url)
            req.timeoutInterval = 15

            do {
                let (data, resp) = try await session.data(for: req)
                guard let http = resp as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                    continue
                }
                if let parsed = parseRDAP(data: data) {
                    return parsed
                }
            } catch {
                // Try next
                continue
            }
        }
        return nil
    }

    private func parseRDAP(data: Data) -> RDAPResult? {
        // RDAP has "events": [{"eventAction":"registration","eventDate":"..."}]
        // Also "port43" or "rir" style hints; we'll derive registry from "objectClassName" or "handle" keys if present.
        struct RDAPEvent: Decodable {
            let eventAction: String?
            let eventDate: String?
        }
        struct RDAPDoc: Decodable {
            let events: [RDAPEvent]?
            let objectClassName: String?
            let port43: String?
            let handle: String?
            let publication: String?
            let registry: String?
            let name: String?
        }

        guard let json = try? JSONDecoder().decode(RDAPDoc.self, from: data) else { return nil }

        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        var regDate: Date?
        if let events = json.events {
            // Prefer "registration" then "allocated" then "created"
            let preferred = ["registration", "allocated", "created"]
            for key in preferred {
                if let dateString = events.first(where: { ($0.eventAction ?? "").lowercased().contains(key) })?.eventDate {
                    regDate = iso.date(from: dateString) ?? ISO8601DateFormatter().date(from: dateString)
                    if regDate != nil { break }
                }
            }
        }

        // Guess registry source
        let registryGuess = json.port43 ?? json.registry ?? json.objectClassName ?? json.name ?? json.handle

        return RDAPResult(registry: registryGuess, registrationDate: regDate)
    }
}
