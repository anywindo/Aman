import SwiftUI

struct NetworkAnalyzerPreferencesSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var viewModel: NetworkAnalyzerViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 12) {
                        Text("Capture Mode")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Capture Mode", selection: $viewModel.selectedCaptureMode) {
                            ForEach(viewModel.captureAdapters) { adapter in
                                Text(adapter.title).tag(adapter.mode)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                        Spacer()
                    }

                    if let adapter = viewModel.captureAdapters.first(where: { $0.mode == viewModel.selectedCaptureMode }) {
                        Text(adapter.availabilityMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            } label: {
                Label("Capture", systemImage: "network")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(spacing: 10) {
                        Image(systemName: "lock.shield")
                            .foregroundStyle(.orange)
                        Text("Payload Inspection")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Toggle("Enable", isOn: Binding(
                            get: { viewModel.payloadInspectionEnabled },
                            set: { viewModel.setPayloadInspection($0) }
                        ))
                        .toggleStyle(.switch)
                        .labelsHidden()
                        .disabled(!currentAdapterSupportsPayload)
                        .help("Capture full packet payloads (may include sensitive data). Requires privileged capture.")
                    }

                    Toggle(isOn: $viewModel.payloadConsentGranted) {
                        Text("I understand payloads may contain sensitive data and consent to collect them on this host.")
                            .font(.caption)
                    }
                    .toggleStyle(.checkbox)
                    .onChange(of: viewModel.payloadConsentGranted) { granted in
                        if viewModel.payloadInspectionEnabled && !granted {
                            viewModel.setPayloadInspection(false)
                        }
                    }
                }
            } label: {
                Label("Privacy", systemImage: "hand.raised")
            }

            GroupBox {
                VStack(alignment: .leading, spacing: 12) {
                    HStack(spacing: 12) {
                        Text("Algorithm")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Picker("Algorithm", selection: $viewModel.selectedAlgorithm) {
                            ForEach(NetworkAnalyzerViewModel.AnalyzerAlgorithm.allCases) { alg in
                                Text(alg.title).tag(alg)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                    }

                    HStack(spacing: 12) {
                        LabeledSlider(
                            title: "Window (s)",
                            value: Binding(
                                get: { Double(viewModel.windowSeconds) },
                                set: { viewModel.windowSeconds = Int($0.rounded()) }
                            ),
                            range: 5...600,
                            step: 1,
                            display: { "\(Int($0))" }
                        )

                        LabeledSlider(
                            title: "Z Threshold",
                            value: $viewModel.zThreshold,
                            range: 0.5...10.0,
                            step: 0.1,
                            display: { String(format: "%.1f", $0) }
                        )

                        if viewModel.selectedAlgorithm == .ewma {
                            LabeledSlider(
                                title: "EWMA α",
                                value: $viewModel.ewmaAlpha,
                                range: 0.05...0.9,
                                step: 0.05,
                                display: { String(format: "%.2f", $0) }
                            )
                        }
                    }

                    LabeledSlider(
                        title: "Time Range (s)",
                        value: Binding(
                            get: { viewModel.selectedTimeRange },
                            set: { viewModel.setTimeRange($0) }
                        ),
                        range: 10...600,
                        step: 10,
                        display: { String(format: "%.0f", $0) }
                    )
                }
            } label: {
                Label("Analyzer", systemImage: "waveform.path.ecg")
            }

            HStack {
                Spacer()
                Button("Close") { dismiss() }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(minWidth: 520)
    }

    private var currentAdapterSupportsPayload: Bool {
        viewModel.captureAdapters.first(where: { $0.mode == viewModel.selectedCaptureMode })?.supportsPayloadInspection ?? false
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: "gearshape")
                .foregroundStyle(.tint)
            VStack(alignment: .leading, spacing: 2) {
                Text("Analyzer Preferences")
                    .font(.title3.weight(.semibold))
                Text("Configure capture and analysis defaults.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
    }
}

// Reusable small slider with a compact labeled field
private struct LabeledSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let display: (Double) -> String

    init(title: String,
         value: Binding<Double>,
         range: ClosedRange<Double>,
         step: Double,
         display: @escaping (Double) -> String) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.display = display
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(display(value))
                    .font(.caption.monospacedDigit())
            }
            Slider(value: $value, in: range, step: step)
                .frame(minWidth: 160)
        }
    }
}
