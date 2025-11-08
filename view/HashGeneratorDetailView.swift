//
//  HashGeneratorDetailView.swift
//  Aman
//
//  Detail pane for displaying generated hash digests.
//

import SwiftUI
import AppKit

struct HashGeneratorDetailView: View {
    @ObservedObject var viewModel: HashGeneratorViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            if viewModel.results.isEmpty {
                ContentUnavailableView("No digests yet", systemImage: "number.square", description: Text("Run the generator to populate results."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        ForEach(viewModel.results) { result in
                            HashResultRow(result: result)
                            Divider()
                        }
                    }
                    .padding(.horizontal, 6)
                    .padding(.bottom, 8)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Generated Digests")
                    .font(.title3.weight(.semibold))
                Text(resultsSubtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if viewModel.isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
            }
        }
    }

    private var resultsSubtitle: String {
        switch viewModel.selection {
        case .all:
            return "\(viewModel.results.count) algorithms"
        case .single(let algorithm):
            return algorithm.displayName
        }
    }
}

private struct HashResultRow: View {
    let result: HashGeneratorViewModel.HashResult
    @State private var copied = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(result.algorithm.displayName)
                        .font(.headline)
                    Text(result.algorithm.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if case .digest(let digest) = result.outcome {
                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(digest, forType: .string)
                        copied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            copied = false
                        }
                    } label: {
                        Label(copied ? "Copied" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                    }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Copy digest to clipboard")
                }
            }

            switch result.outcome {
            case .digest(let digest):
                ScrollView(.horizontal, showsIndicators: false) {
                    Text(digest)
                        .lineLimit(1)
                        .font(.system(.body, design: .monospaced))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                        )
                }
            case .failure(let message):
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            StrengthBar(bits: result.algorithm.digestBitLength, progress: result.algorithm.normalizedStrength)
        }
    }
}

private struct StrengthBar: View {
    let bits: Int
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Digest strength")
                    .font(.caption.weight(.semibold))
                Spacer()
                Text("\(bits)-bit")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress)
                .progressViewStyle(.linear)
        }
    }
}
