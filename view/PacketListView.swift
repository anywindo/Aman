//
//  PacketListView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI

struct PacketListView: View {
    let packets: [PacketSample]
    @Binding var selection: PacketSample.ID?

    var body: some View {
        Table(packets, selection: $selection) {
            TableColumn("No.") { packet in
                Text("\(packet.id)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.primary)
            }
            .width(50)

            TableColumn("Time") { packet in
                Text(Self.timeFormatter.string(from: packet.timestamp))
                    .font(.caption.monospaced())
            }
            .width(150)

            TableColumn("Δt") { packet in
                Text(Self.relativeFormatter.string(from: packet.relativeTime as NSNumber) ?? String(format: "%.6f", packet.relativeTime))
                    .font(.caption.monospacedDigit())
            }
            .width(90)

            TableColumn("Source") { packet in
                Text(sourceHost(for: packet))
                    .font(.caption.monospaced())
                    .lineLimit(1)
            }
            .width(min: 160, ideal: 220)

            TableColumn("Src Port") { packet in
                Text(packet.sourcePort ?? "–")
                    .font(.caption.monospacedDigit())
                    .frame(width: 60, alignment: .trailing)
            }

            TableColumn("Destination") { packet in
                Text(destinationHost(for: packet))
                    .font(.caption.monospaced())
                    .lineLimit(1)
            }
            .width(min: 160, ideal: 220)

            TableColumn("Dst Port") { packet in
                Text(packet.destinationPort ?? "–")
                    .font(.caption.monospacedDigit())
                    .frame(width: 60, alignment: .trailing)
            }

            TableColumn("Protocol") { packet in
                Text(packet.protocolName)
                    .font(.caption.weight(.semibold))
            }
            .width(90)

            TableColumn("Length") { packet in
                Text("\(packet.length)")
                    .font(.caption.monospacedDigit())
            }
            .width(70)

            TableColumn("Info") { packet in
                Text(packet.info.isEmpty ? "–" : packet.info)
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
        }
        .tableStyle(.inset(alternatesRowBackgrounds: true))
        .frame(minHeight: 320)
    }

    private static let timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter
    }()

    private static let relativeFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.minimumFractionDigits = 3
        formatter.maximumFractionDigits = 6
        return formatter
    }()

    private func sourceHost(for packet: PacketSample) -> String {
        if let ip = packet.sourceIP, !ip.isEmpty { return ip }
        return packet.source.isEmpty ? "–" : packet.source
    }

    private func destinationHost(for packet: PacketSample) -> String {
        if let ip = packet.destinationIP, !ip.isEmpty { return ip }
        return packet.destination.isEmpty ? "–" : packet.destination
    }
}
