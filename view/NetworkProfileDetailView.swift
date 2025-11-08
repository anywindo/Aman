//
//  NetworkProfileDetailView.swift
//  Aman
//
//  Detail pane that shows a full map of the public IP location.
//

import SwiftUI
import MapKit

struct NetworkProfileDetailView: View {
    @ObservedObject var viewModel: NetworkProfileViewModel
    @State private var isMinimized: Bool = false
    @State private var snapshotImage: NSImage?
    // Trigger to request a fresh snapshot right before minimizing
    @State private var snapshotTrigger: Int = 0

    var body: some View {
        VStack(spacing: 12) {
            header

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color.clear)
                // Window visibility observer lives here to drive isMinimized
                .background(
                    NetworkProfileVisibilityObserver { event in
                        switch event {
                        case .attachedToWindow, .deminiaturized:
                            isMinimized = false
                            snapshotImage = nil
                        case .miniaturized:
                            // Ask the live map to produce a snapshot, then flip to minimized mode.
                            snapshotTrigger &+= 1
                            isMinimized = true
                        case .detachedFromWindow:
                            // Treat as minimized/offscreen
                            isMinimized = true
                        }
                    }
                )
        }
        .padding(20)
    }

    @ViewBuilder
    private var content: some View {
        if let lat = viewModel.snapshot.latitude,
           let lon = viewModel.snapshot.longitude {
            ZStack(alignment: .bottomLeading) {
                if isMinimized, let snapshotImage {
                    // Show static snapshot when minimized
                    Image(nsImage: snapshotImage)
                        .resizable()
                        .scaledToFill()
                        .clipped()
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                        )
                } else {
                    // Live map when not minimized (or when snapshot not yet ready)
                    NetworkProfileMapView(
                        latitude: lat,
                        longitude: lon,
                        location: viewModel.snapshot.geo ?? "Location",
                        isMinimized: isMinimized,
                        snapshotTrigger: snapshotTrigger,
                        onRequestSnapshot: { image in
                            // Store the latest snapshot for minimize swap
                            snapshotImage = image
                        }
                    )
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.08), lineWidth: 1)
                    )
                }

                // Footer overlay inside the map/snapshot
                footerOverlay
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .padding(12)
            }
        } else if viewModel.isLoading {
            VStack(spacing: 12) {
                ProgressView("Fetching IP location…")
                    .progressViewStyle(.circular)
                Text("We’re resolving your public IP and geolocation.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let error = viewModel.error {
            VStack(spacing: 10) {
                Label("Unable to load IP geolocation", systemImage: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ContentUnavailableView(
                "No location available",
                systemImage: "mappin.slash",
                description: Text("Run Refresh to resolve your public IP and coordinates.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("IP Location")
                    .font(.title3.weight(.semibold))
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            // Refresh button removed as requested
        }
    }

    private var subtitle: String {
        var parts: [String] = []
        if let ip = viewModel.snapshot.publicIP { parts.append(ip) }
        if let geo = viewModel.snapshot.geo { parts.append(geo) }
        if let isp = viewModel.snapshot.isp {
            if let asn = viewModel.snapshot.asn {
                parts.append("\(isp) (\(asn))")
            } else {
                parts.append(isp)
            }
        }
        return parts.isEmpty ? "Public IP geolocation" : parts.joined(separator: " • ")
    }

    // Footer content shown inside the map as an overlay
    private var footerOverlay: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let lat = viewModel.snapshot.latitude,
               let lon = viewModel.snapshot.longitude {
                Label(String(format: "Lat %.4f, Lon %.4f", lat, lon), systemImage: "location")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 10) {
                Label(viewModel.snapshot.vpnActive ? "VPN active" : "No VPN", systemImage: viewModel.snapshot.vpnActive ? "lock.shield" : "exclamationmark.shield")
                    .font(.footnote)
                    .foregroundColor(viewModel.snapshot.vpnActive ? .secondary : .orange)
                Label(viewModel.snapshot.ipv6Enabled ? "IPv6" : "IPv4", systemImage: "network")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Label(viewModel.snapshot.httpsReachable ? "HTTPS OK" : "No HTTPS", systemImage: "lock")
                    .font(.footnote)
                    .foregroundColor(viewModel.snapshot.httpsReachable ? .secondary : .orange)
            }
        }
    }
}

// A tiny observer view to detect window minimize/deminiaturize for SwiftUI container
private struct NetworkProfileVisibilityObserver: NSViewRepresentable {
    enum Event {
        case attachedToWindow
        case detachedFromWindow
        case miniaturized
        case deminiaturized
    }

    let callback: (Event) -> Void

    func makeNSView(context: Context) -> ObserverView {
        let v = ObserverView()
        v.callback = callback
        return v
    }

    func updateNSView(_ nsView: ObserverView, context: Context) {
        // no-op
    }

    final class ObserverView: NSView {
        var callback: ((Event) -> Void)?
        private var observers: [NSObjectProtocol] = []

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            for obs in observers { NotificationCenter.default.removeObserver(obs) }
            observers.removeAll()

            if let window {
                callback?(.attachedToWindow)
                let willMini = NotificationCenter.default.addObserver(
                    forName: NSWindow.willMiniaturizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in self?.callback?(.miniaturized) }
                let didDemini = NotificationCenter.default.addObserver(
                    forName: NSWindow.didDeminiaturizeNotification,
                    object: window,
                    queue: .main
                ) { [weak self] _ in self?.callback?(.deminiaturized) }
                observers.append(contentsOf: [willMini, didDemini])
            } else {
                callback?(.detachedFromWindow)
            }
        }

        deinit {
            for obs in observers { NotificationCenter.default.removeObserver(obs) }
            observers.removeAll()
        }
    }
}

// Dedicated map wrapper for Network Profile
struct NetworkProfileMapView: NSViewRepresentable {
    let latitude: Double
    let longitude: Double
    let location: String
    let isMinimized: Bool
    let snapshotTrigger: Int
    let onRequestSnapshot: (NSImage) -> Void

    func makeNSView(context: Context) -> MKMapView {
        let mapView = MKMapView(frame: .zero)
        mapView.showsZoomControls = true
        mapView.showsScale = true
        mapView.showsUserLocation = false
        mapView.showsBuildings = true
        mapView.showsCompass = true
        mapView.mapType = .standard

        context.coordinator.mapView = mapView
        context.coordinator.onSnapshot = onRequestSnapshot
        context.coordinator.lastSnapshotTrigger = snapshotTrigger
        context.coordinator.isMinimized = isMinimized

        // Cache last coordinate to avoid redundant work
        context.coordinator.lastCoordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)

        // Initial configure without animation
        configure(mapView, to: context.coordinator.lastCoordinate!, locationTitle: location, animated: false)
        return mapView
    }

    func updateNSView(_ mapView: MKMapView, context: Context) {
        // Update minimized state
        let wasMin = context.coordinator.isMinimized
        context.coordinator.isMinimized = isMinimized

        // If we just received a new snapshot trigger or transitioned to minimized, try to snapshot
        if snapshotTrigger != context.coordinator.lastSnapshotTrigger || (isMinimized && !wasMin) {
            context.coordinator.lastSnapshotTrigger = snapshotTrigger
            context.coordinator.snapshotIfPossible()
        }

        // While minimized, avoid heavy updates
        if isMinimized { return }

        // Skip updates if offscreen (no window) or hidden
        guard mapView.window != nil, !mapView.isHidden else { return }

        let newCoord = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        if let last = context.coordinator.lastCoordinate, coordinatesEqual(last, newCoord) {
            return
        }
        context.coordinator.lastCoordinate = newCoord
        configure(mapView, to: newCoord, locationTitle: location, animated: false)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    static func dismantleNSView(_ mapView: MKMapView, coordinator: Coordinator) {
        // Ensure no pending transactions reference the layer
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mapView.removeAnnotations(mapView.annotations)
        mapView.delegate = nil
        CATransaction.commit()

        coordinator.lastCoordinate = nil
        coordinator.mapView = nil
        coordinator.onSnapshot = nil
    }

    final class Coordinator {
        weak var mapView: MKMapView?
        var lastCoordinate: CLLocationCoordinate2D?
        var onSnapshot: ((NSImage) -> Void)?
        var lastSnapshotTrigger: Int = 0
        var isMinimized: Bool = false

        // Called by container before minimize
        func snapshotIfPossible() {
            guard let mapView else { return }
            let size = mapView.bounds.size
            guard size.width > 0, size.height > 0 else { return }

            let options = MKMapSnapshotter.Options()
            options.region = mapView.region
            options.size = size
            let snapshotter = MKMapSnapshotter(options: options)

            snapshotter.start(with: .main) { [weak self] result, error in
                guard let result, error == nil else { return }
                let image = result.image
                self?.onSnapshot?(image)
            }
        }
    }

    // Configure the map safely on main thread
    private func configure(_ mapView: MKMapView, to coordinate: CLLocationCoordinate2D, locationTitle: String, animated: Bool) {
        if !Thread.isMainThread {
            DispatchQueue.main.async {
                configure(mapView, to: coordinate, locationTitle: locationTitle, animated: animated)
            }
            return
        }

        // Replace any existing pin with one
        mapView.removeAnnotations(mapView.annotations)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinate
        annotation.title = locationTitle
        mapView.addAnnotation(annotation)

        // Update region without animation to keep interactions snappy
        let region = MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
        )
        mapView.setRegion(region, animated: animated)
    }

    private func coordinatesEqual(_ lhs: CLLocationCoordinate2D, _ rhs: CLLocationCoordinate2D, epsilon: Double = 1e-6) -> Bool {
        abs(lhs.latitude - rhs.latitude) < epsilon && abs(lhs.longitude - rhs.longitude) < epsilon
    }
}
