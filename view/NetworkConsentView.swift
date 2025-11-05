import SwiftUI

struct NetworkConsentView: View {
    let feature: NetworkConsentFeature
    let onDecline: () -> Void
    let onAccept: () -> Void

    private struct ConsentSection: Identifiable {
        let id = UUID()
        let title: String
        let text: String
    }

    private var sections: [ConsentSection] {
        let sharedOutputs = "You will receive annotated timelines, summary statistics, and alert recommendations that are derived from the captured data and kept within this session."
        let sharedResponsibilities = "You agree that you are authorised to inspect traffic on this Mac and any connected networks, will notify other users of the capture, and will stop analysis immediately if sensitive information appears."
        let sharedUsage = "All captured information stays on this device. Aman does not transmit samples or results unless you explicitly export them."

        switch feature {
        case .analyzer:
            return [
                ConsentSection(
                    title: "Purpose",
                    text: "Network Analyzer baselines live traffic from this Mac to highlight unusual activity and provide you with situational awareness."
                ),
                ConsentSection(
                    title: "Data Collected",
                    text: "During the session Aman records per-second throughput metrics (bytes, packets, and flows), protocol and destination tags derived from the capture, and, when you enable payload inspection, high-level summaries of packet contents."
                ),
                ConsentSection(
                    title: "How Data Is Processed",
                    text: "Captured metrics feed local anomaly detectors that examine spikes, seasonality shifts, emerging talkers, and correlated deviations. Processing happens only on your Mac."
                ),
                ConsentSection(
                    title: "Outputs",
                    text: sharedOutputs
                ),
                ConsentSection(
                    title: "Data Usage",
                    text: sharedUsage
                ),
                ConsentSection(
                    title: "User Responsibilities",
                    text: sharedResponsibilities
                ),
                ConsentSection(
                    title: "Consent Acknowledgment",
                    text: "By choosing to continue you confirm that you understand what is collected, why it is analysed, and that you provide informed consent for this Network Analyzer session."
                )
            ]
        case .mapping:
            return [
                ConsentSection(
                    title: "Purpose",
                    text: "Network Mapping surveys only the IP ranges you authorise so that you can review live host inventory, subnet layout, and exposed services for this session."
                ),
                ConsentSection(
                    title: "Data Collected",
                    text: "Aman issues lightweight discovery probes you trigger (ARP who-has, ICMP echo, TCP SYN/CONNECT, and select UDP handshakes) against those authorised ranges. It records only the responding host address, port or service identifiers, banner snippets, and the timestamp/latency of each response. Raw packet captures are not retained."
                ),
                ConsentSection(
                    title: "How Data Is Processed",
                    text: "The responses are correlated locally on this Mac to populate host cards, port inventories, and topology diagrams. Results are kept in memory for this window and are never transmitted or synced elsewhere unless you export them."
                ),
                ConsentSection(
                    title: "Outputs",
                    text: "You receive discovery timelines, host/service summaries, and optional topology visualisations generated from the authorised probes."
                ),
                ConsentSection(
                    title: "Data Usage",
                    text: "Captured details remain on-device and are cleared when you close the Network Security window. Aman never runs discovery or stores data unless you initiate it, and exports happen only when you explicitly request them."
                ),
                ConsentSection(
                    title: "User Responsibilities",
                    text: "Only scan networks you control or have explicit permission to assess, respect published policies and rate limits, notify affected parties when appropriate, and stop if any probe could violate contractual or regulatory boundaries."
                ),
                ConsentSection(
                    title: "Consent Acknowledgment",
                    text: "By continuing you affirm that you are authorised to enumerate the selected networks, understand what is collected and how it is used, and consent to perform Network Mapping for this session."
                )
            ]
        }
    }

    private var title: String {
        "Consent for \(feature.displayName)"
    }

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.title2.bold())
                Text("Please review the details below before continuing.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.bottom, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ForEach(sections) { section in
                        VStack(alignment: .leading, spacing: 8) {
                            Text(section.title)
                                .font(.headline)
                            Text(section.text)
                                .font(.body)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(nsColor: .controlBackgroundColor))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Divider()
                .padding(.vertical, 16)

            HStack {
                Button("Decline") {
                    onDecline()
                }
                .buttonStyle(.borderless)

                Spacer()

                Button("I Consent") {
                    onAccept()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(minWidth: 520, minHeight: 600)
    }
}
