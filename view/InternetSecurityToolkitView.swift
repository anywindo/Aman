//
//  InternetSecurityToolkitView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI
import MapKit

struct InternetSecurityToolkitView: View {
    @Binding var selection: InternetSecurityCheckResult.Kind?
    let results: [InternetSecurityCheckResult.Kind: InternetSecurityCheckResult]
    let runningChecks: Set<InternetSecurityCheckResult.Kind>
    let isSuiteRunning: Bool
    let lastError: String?
    let onRunSuite: () -> Void
    let onRunCheck: (InternetSecurityCheckResult.Kind) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header

                if let lastError {
                    Text(lastError)
                        .font(.subheadline)
                        .foregroundStyle(.red)
                        .padding(.horizontal)
                }

                ForEach(InternetSecurityCheckResult.Kind.allCases) { kind in
                    InternetSecurityCard(
                        kind: kind,
                        result: results[kind],
                        isRunning: runningChecks.contains(kind),
                        isSelected: selection == kind,
                        onSelect: { selection = kind },
                        onRun: { onRunCheck(kind) }
                    )
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 24)
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Internet Security Toolkit")
                    .font(.title2.bold())
                Text("Run privacy checks to spot DNS, proxy, and firewall risks.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                onRunSuite()
            } label: {
                HStack(spacing: 8) {
                    if isSuiteRunning {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.7)
                    }
                    Text(isSuiteRunning ? "Running…" : "Run All")
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 14)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color.accentColor.opacity(isSuiteRunning ? 0.35 : 0.2))
                )
            }
            .buttonStyle(.plain)
            .disabled(isSuiteRunning)
        }
    }
}

private struct InternetSecurityCard: View {
    let kind: InternetSecurityCheckResult.Kind
    let result: InternetSecurityCheckResult?
    let isRunning: Bool
    let isSelected: Bool
    let onSelect: () -> Void
    let onRun: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    Text(kind.title)
                        .font(.headline)

                    Spacer()

                    statusBadge
                }

                Text(summaryText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    if isRunning {
                        ProgressView()
                            .progressViewStyle(.linear)
                            .frame(maxWidth: 120)
                        Text("Running…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Run") {
                            onRun()
                        }
                        .font(.callout.weight(.medium))
                        .buttonStyle(.borderedProminent)
                    }

                    Spacer()

                    if let result {
                        Text("Last run \(Self.timestampFormatter.localizedString(for: result.finishedAt, relativeTo: Date()))")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: isRunning)
    }

    private var summaryText: String {
        if isRunning {
            return "Check in progress…"
        }
        if let result {
            return result.headline
        }
        return kind.summary
    }

    private var statusBadge: some View {
        Group {
            if isRunning {
                label(text: "Running", color: .blue.opacity(0.75))
            } else if let status = result?.status {
                label(text: statusLabel(for: status), color: statusColor(for: status))
            } else {
                label(text: "Not Run", color: Color.gray.opacity(0.45))
            }
        }
        .font(.caption.weight(.semibold))
        .padding(.vertical, 4)
        .padding(.horizontal, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color.primary.opacity(0.06))
        )
    }

    private func label(text: String, color: Color) -> some View {
        Text(text.uppercased())
            .foregroundStyle(color)
    }

    private func statusColor(for status: InternetSecurityCheckResult.Status) -> Color {
        switch status {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        case .info:
            return .blue
        case .error:
            return .pink
        }
    }

    private func statusLabel(for status: InternetSecurityCheckResult.Status) -> String {
        switch status {
        case .pass: return "Pass"
        case .warning: return "Warning"
        case .fail: return "Fail"
        case .info: return "Info"
        case .error: return "Error"
        }
    }

    private var background: some View {
        RoundedRectangle(cornerRadius: 16, style: .continuous)
            .strokeBorder(isSelected ? Color.accentColor.opacity(0.7) : Color.primary.opacity(0.08), lineWidth: isSelected ? 2 : 1)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(isSelected ? Color.accentColor.opacity(0.08) : Color.primary.opacity(0.02))
            )
    }

    private static let timestampFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter
    }()
}

struct InternetSecurityDetailView: View {
    let result: InternetSecurityCheckResult?
    let isRunning: Bool

    var body: some View {
        if isRunning && result == nil {
            VStack(spacing: 16) {
                ProgressView("Running check…")
                    .progressViewStyle(.circular)
                Text("Internet security checks may take a few seconds when resolving external metadata.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let result {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(for: result)

                    if !result.details.isEmpty {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Key Findings")
                                .font(.headline)
                            ForEach(result.details) { detail in
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(detail.label)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    Text(detail.value)
                                        .font(.body.weight(.medium))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, 6)
                                .padding(.horizontal, 10)
                                .background(
                                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                                        .fill(Color.primary.opacity(0.04))
                                )
                            }
                        }
                    }

                    // Show map for IP & GeoIP Exposure
                    if result.kind == .ipExposure {
                        if let coords = extractCoordinates(from: result) {
                            IPMapView(
                                latitude: coords.latitude,
                                longitude: coords.longitude,
                                location: result.details.first(where: { $0.label == "Geo" })?.value ?? "Location"
                            )
                            .frame(height: 300)
                            .cornerRadius(12)
                            .padding(.vertical, 8)
                        }
                    }

                    if !result.notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(.headline)
                            ForEach(Array(result.notes.enumerated()), id: \.offset) { entry in
                                Text("• \(entry.element)")
                                    .font(.body)
                                    .foregroundStyle(.primary)
                            }
                        }
                    }

                    meta(for: result)
                }
                .padding(24)
            }
        } else {
            VStack(spacing: 12) {
                Text("Select a check")
                    .font(.title3.bold())
                Text("Choose one of the Internet security cards to view detailed findings, remediation tips, and telemetry.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 340)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func extractCoordinates(from result: InternetSecurityCheckResult) -> (latitude: Double, longitude: Double)? {
        guard let coordDetail = result.details.first(where: { $0.label == "Coordinates" }) else {
            return nil
        }
        
        let parts = coordDetail.value.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count == 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else {
            return nil
        }
        return (latitude: lat, longitude: lon)
    }

    private func header(for result: InternetSecurityCheckResult) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(result.kind.title)
                .font(.title2.bold())

            statusBadge(for: result.status)

            Text(result.headline)
                .font(.headline)
        }
    }

    private func statusBadge(for status: InternetSecurityCheckResult.Status) -> some View {
        Text(statusText(for: status))
            .font(.caption.weight(.semibold))
            .padding(.vertical, 4)
            .padding(.horizontal, 10)
            .background(
                Capsule(style: .continuous)
                    .fill(statusColor(for: status).opacity(0.15))
            )
            .foregroundStyle(statusColor(for: status))
    }

    private func statusText(for status: InternetSecurityCheckResult.Status) -> String {
        switch status {
        case .pass: return "PASS"
        case .warning: return "WARNING"
        case .fail: return "FAIL"
        case .info: return "INFO"
        case .error: return "ERROR"
        }
    }

    private func statusColor(for status: InternetSecurityCheckResult.Status) -> Color {
        switch status {
        case .pass:
            return .green
        case .warning:
            return .orange
        case .fail:
            return .red
        case .info:
            return .blue
        case .error:
            return .pink
        }
    }

    private func meta(for result: InternetSecurityCheckResult) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Captured \(Self.dateFormatter.string(from: result.finishedAt))")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text(String(format: "Runtime: %.2fs", result.duration))
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
    }

    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        return formatter
    }()
}

// MARK: - Map View for IP Location

struct IPMapView: NSViewRepresentable {
    let latitude: Double
    let longitude: Double
    let location: String

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.showsZoomControls = true
        mapView.showsScale = true
        mapView.showsUserLocation = false
        mapView.showsBuildings = true
        mapView.showsCompass = true
        mapView.mapType = .standard
        
        // Add annotation for the IP location
        let annotation = MKPointAnnotation()
        annotation.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        annotation.title = location
        mapView.addAnnotation(annotation)
        
        // Center the map on the location with appropriate zoom
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
        mapView.setRegion(region, animated: false)
        
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // The map is configured once in makeNSView, no updates needed
    }
}
