//
//  CertificateLookupDetailView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI

struct CertificateLookupDetailView: View {
    let entry: CertificateEntry?

    var body: some View {
        if let entry {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(for: entry)
                    fields(for: entry)
                    issuerSection(for: entry)
                }
                .padding(32)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            VStack(spacing: 12) {
                Text("Select a certificate")
                    .font(.title3.bold())
                Text("Choose an entry from the lookup results to inspect validity windows, issuer, and serial metadata.")
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func header(for entry: CertificateEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(entry.commonName.isEmpty ? entry.nameValue : entry.commonName)
                .font(.title2.bold())
            Text(entry.nameValue)
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    private func fields(for entry: CertificateEntry) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledRow(title: "Entry Timestamp", value: entry.entryTimestamp)
            labeledRow(title: "Valid From", value: entry.notBefore)
            labeledRow(title: "Valid Until", value: entry.notAfter)
            labeledRow(title: "Serial Number", value: entry.serialNumber)
            labeledRow(title: "Result Count", value: "\(entry.resultCount)")
        }
    }

    private func issuerSection(for entry: CertificateEntry) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Issuer")
                .font(.headline)
            labeledRow(title: "Issuer Name", value: entry.issuerName)
            labeledRow(title: "Issuer CA ID", value: "\(entry.issuerCAID)")
        }
    }

    private func labeledRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body)
        }
        .padding(.vertical, 4)
    }
}
