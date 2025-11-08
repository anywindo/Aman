//
//  HashGeneratorView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI
import UniformTypeIdentifiers
import AppKit

struct HashGeneratorView: View {
    @ObservedObject var viewModel: HashGeneratorViewModel
    @State private var showingFileImporter = false

    @State private var selectedAlgorithms: Set<HashAlgorithm> = [.sha256]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
            modePicker
            inputSection
            algorithmMultiSelect
            actionRow

            Divider()
            Text("Results appear in the right-hand pane after you generate.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding(24)
        .fileImporter(
            isPresented: $showingFileImporter,
            allowedContentTypes: [.data],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                viewModel.setFileURL(urls.first)
            case .failure:
                viewModel.error = "Unable to open the selected file."
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Hash Generator")
                .font(.title2.bold())
            Text("Choose the algorithms you need, then hash text or files for quick comparisons.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Input type")
                .font(.headline)
            InputModeCardPicker(selection: $viewModel.inputMode)
        }
        .onChange(of: viewModel.inputMode) { newMode in
            Task { @MainActor in
                viewModel.error = nil
                switch newMode {
                case .text:
                    viewModel.fileURL = nil
                case .file:
                    viewModel.textInput = ""
                }
            }
        }
    }

    @ViewBuilder
    private var inputSection: some View {
        switch viewModel.inputMode {
        case .text:
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("Text to hash")
                        .font(.headline)
                    Spacer()
                    Text("\(viewModel.textInput.count) chars")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(nsColor: .controlBackgroundColor))
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .stroke(Color.primary.opacity(0.12), lineWidth: 1)

                    TextEditor(text: $viewModel.textInput)
                        .font(.system(.body, design: .monospaced))
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(height: 100)
                        .background(Color.clear)
                }
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(Color.primary.opacity(0.06))
                )
            }
        case .file:
            VStack(alignment: .leading, spacing: 12) {
                Text("Selected file")
                    .font(.headline)
                HStack(spacing: 12) {
                    if let url = viewModel.fileURL {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(url.lastPathComponent)
                                .font(.body.weight(.semibold))
                            Text(url.path)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("No file selected.")
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        showingFileImporter = true
                    } label: {
                        Label("Choose…", systemImage: "doc.text.magnifyingglass")
                    }
                }
            }
        }
    }

    // MARK: - Multi-select algorithms (replaces dropdown)
    private var algorithmMultiSelect: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Algorithms")
                    .font(.headline)
                Spacer()
                Text(selectionSummary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 8) {
                Button {
                    selectedAlgorithms = Set(HashAlgorithm.ordered)
                } label: {
                    Label("Select All", systemImage: "checkmark.circle")
                }
                .buttonStyle(.bordered)

                Button {
                    selectedAlgorithms.removeAll()
                } label: {
                    Label("Clear", systemImage: "xmark.circle")
                }
                .buttonStyle(.bordered)
            }

            let columns = [GridItem(.adaptive(minimum: 220, maximum: 320), spacing: 12)]
            LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
                ForEach(HashAlgorithm.ordered) { algorithm in
                    AlgorithmToggleCard(
                        algorithm: algorithm,
                        isSelected: selectedAlgorithms.contains(algorithm),
                        onToggle: {
                            if selectedAlgorithms.contains(algorithm) {
                                selectedAlgorithms.remove(algorithm)
                            } else {
                                selectedAlgorithms.insert(algorithm)
                            }
                        }
                    )
                }
            }
        }
    }

    private var selectionSummary: String {
        if selectedAlgorithms.isEmpty {
            return "All algorithms will be used"
        }
        if selectedAlgorithms.count == 1 {
            return "1 algorithm selected"
        }
        return "\(selectedAlgorithms.count) algorithms selected"
    }

    private var actionRow: some View {
        HStack(spacing: 12) {
            Button {
                if selectedAlgorithms.isEmpty {
                    viewModel.setSelection(.all)
                } else if selectedAlgorithms.count == 1, let only = selectedAlgorithms.first {
                    viewModel.setSelection(.single(only))
                } else {
                    viewModel.setSelection(.all)
                    viewModel.error = "Multiple algorithms selected: hashing all supported algorithms."
                }
                viewModel.generate()
            } label: {
                Label(
                    viewModel.isProcessing ? "Generating…" : "Generate Hashes",
                    systemImage: "bolt.fill"
                )
                .frame(minWidth: 170)
            }
            .buttonStyle(.borderedProminent)
            .disabled(viewModel.isProcessing)

            Button {
                viewModel.clear()
                selectedAlgorithms = [.sha256]
            } label: {
                Label("Clear", systemImage: "trash")
            }
            .buttonStyle(.bordered)
            .disabled(viewModel.isProcessing)

            if viewModel.isProcessing {
                ProgressView()
                    .progressViewStyle(.circular)
            }

            Spacer()

            if let error = viewModel.error {
                Label(error, systemImage: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .font(.footnote)
            }
        }
    }
}

// MARK: - Algorithm toggle card

private struct AlgorithmToggleCard: View {
    let algorithm: HashAlgorithm
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    Text(algorithm.displayName)
                        .font(.body.weight(.semibold))
                    Spacer()
                }
                Text(shortDescription(for: algorithm))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.10) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func shortDescription(for algorithm: HashAlgorithm) -> String {
        algorithm.explanation
    }
}

// MARK: - Input Mode Card Picker

private struct InputModeCardPicker: View {
    @Binding var selection: HashGeneratorViewModel.InputMode

    var body: some View {
        HStack(spacing: 12) {
            modeCard(
                icon: "text.alignleft",
                title: "Text",
                subtitle: "Type or paste inline",
                mode: .text
            )
            modeCard(
                icon: "doc",
                title: "File",
                subtitle: "Pick a local file",
                mode: .file
            )
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func modeCard(icon: String, title: String, subtitle: String, mode: HashGeneratorViewModel.InputMode) -> some View {
        let isSelected = selection == mode
        Button {
            selection = mode
        } label: {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.body.weight(.semibold))
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? Color.accentColor : .secondary.opacity(0.6))
            }
            .padding(.vertical, 10)
            .padding(.horizontal, 12)
            .frame(maxWidth: 260)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.primary.opacity(0.04))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.55) : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

