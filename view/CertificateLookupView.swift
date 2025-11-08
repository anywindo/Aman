//
//  CertificateLookupView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI

struct CertificateLookupView: View {
    @ObservedObject var viewModel: CertificateLookupViewModel
    @Binding var selectedEntryID: CertificateEntry.ID?

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            searchControls
            resultsList
            footer
        }
        .padding(24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Certificate Transparency Lookup")
                .font(.title2.bold())
            Text("Query crt.sh for recent certificates and subdomains issued for your perimeter.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var searchControls: some View {
        HStack(spacing: 12) {
            TextField("example.com", text: $viewModel.query)
                .textFieldStyle(.roundedBorder)
                .onSubmit {
                    viewModel.performLookup()
                }

            Button {
                viewModel.performLookup()
            } label: {
                Label("Search", systemImage: "magnifyingglass")
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isLoading)

            if viewModel.isLoading {
                ProgressView()
                    .progressViewStyle(.circular)
            }

            Spacer()

            if !viewModel.results.isEmpty {
                Button(role: .destructive) {
                    viewModel.clear()
                    selectedEntryID = nil
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        if let error = viewModel.error {
            VStack(alignment: .leading, spacing: 8) {
                Label("Lookup failed", systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.headline)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        } else if viewModel.results.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Label("No results yet", systemImage: "questionmark.circle")
                    .font(.headline)
                Text("Run a lookup to enumerate subdomains and certificates observed by crt.sh.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 24)
        } else {
            List(selection: $selectedEntryID) {
                ForEach(viewModel.results) { entry in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(entry.commonName.isEmpty ? entry.nameValue : entry.commonName)
                            .font(.headline)
                        Text(entry.nameValue)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        HStack(spacing: 16) {
                            Label(entry.issuerName, systemImage: "building.columns")
                            Label(compactDateRange(for: entry), systemImage: "calendar")
                        }
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .listStyle(.inset)
        }
    }

    private var footer: some View {
        HStack {
            Spacer()
            Text("\(viewModel.results.count) subdomain(s) detected")
                .font(.footnote.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }

    private func compactDateRange(for entry: CertificateEntry) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        let displayFormatter = DateFormatter()
        displayFormatter.dateStyle = .medium

        let start = formatter.date(from: entry.notBefore)
        let end = formatter.date(from: entry.notAfter)

        let startString = start.map { displayFormatter.string(from: $0) } ?? entry.notBefore
        let endString = end.map { displayFormatter.string(from: $0) } ?? entry.notAfter
        return "\(startString) → \(endString)"
    }
}
