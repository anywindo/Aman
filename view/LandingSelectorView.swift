//
//  LandingSelectorView.swift
//  Aman - view
//
//  Created by Aman Team on 08/11/25
//

import SwiftUI

struct LandingSelectorView: View {
    @Environment(\.openWindow) private var openWindow
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var heroUnderlinePhase: CGFloat = 0

    var body: some View {
        ZStack {
            backdrop

            // Main content column (without footer)
            VStack(spacing: 32) {
                // Hero
                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        AppIconBadge(size: 64)
                            .shadow(color: .black.opacity(0.08), radius: 8, x: 0, y: 4)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Welcome to Aman")
                                .font(.system(size: 36, weight: .bold, design: .rounded))
                                .overlay(alignment: .bottomLeading) {
//                                    accentUnderline
                                }
                            Text("Choose a security workspace to continue.")
                                .foregroundStyle(.secondary)
                                .font(.headline)
                        }
                    }
                }
                .frame(maxWidth: 880)
                .padding(.top, 4)

                // Tiles
                AdaptiveTileRow(spacing: 24) {
                    LandingTile(
                        title: "OS Security",
                        subtitle: "Audit macOS hardening, get a compliance snapshot, and follow remediation hints. Export results for review.",
                        icon: "macwindow.on.rectangle",
                        tint: .blue
                    ) {
                        openWorkspace(.osSecurity)
                    }

                    LandingTile(
                        title: "Network Security",
                        subtitle: "Run Internet Security checks (DNS, IP/GeoIP, IPv6 leak, firewall, proxy/VPN), look up certificates, hash files/snippets, and view your network profile.",
                        icon: "network",
                        tint: .green
                    ) {
                        openWorkspace(.networkSecurity)
                    }
                }
                .frame(maxWidth: 980)

                Spacer(minLength: 0)
            }
            .padding(40)
            .frame(minWidth: 760, minHeight: 520)

            // Bottom-aligned footer overlay
            VStack {
                Spacer()
                footerTips
                    .padding(.horizontal, 40)
                    .padding(.bottom, 24)
            }
            .ignoresSafeArea(.container, edges: .bottom)
        }
        .background(
            WindowAccessor { window in
                window?.identifier = NSUserInterfaceItemIdentifier(AmanApp.WindowID.landing.rawValue)
            }
        )
        .onAppear {
            if !reduceMotion {
                withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) {
                    heroUnderlinePhase = 1
                }
            }
        }
    }

    private var backdrop: some View {
        ZStack {
            // Soft gradient background that adapts to appearance
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.accentColor.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle noise texture to avoid flatness
            Color.black.opacity(0.02)
                .blendMode(.overlay)
                .allowsHitTesting(false)

            // Gentle vignette for focus
            RadialGradient(
                gradient: Gradient(colors: [Color.black.opacity(0.12), .clear]),
                center: .center,
                startRadius: 380,
                endRadius: 820
            )
            .blendMode(.multiply)
            .allowsHitTesting(false)
        }
        .ignoresSafeArea()
    }

    private var accentUnderline: some View {
        GeometryReader { proxy in
            let width = max(80, min(proxy.size.width * 0.35, 180))
            Capsule()
                .fill(
                    LinearGradient(
                        colors: [
                            Color.accentColor.opacity(0.55),
                            Color.accentColor.opacity(0.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: width, height: 3)
                .offset(y: 6)
                .opacity(0.9)
                .shadow(color: Color.accentColor.opacity(0.25), radius: 4, x: 0, y: 1)
                .modifier(AnimatedShift(phase: $heroUnderlinePhase, reduceMotion: reduceMotion))
        }
        .frame(height: 10)
    }

    private var footerTips: some View {
        HStack(spacing: 14) {
            // Left: Tip
            HStack(spacing: 14) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.secondary)
                Text("Tip: You can switch workspaces anytime from the sidebar.")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
            }

            Spacer()

            // Right: About circular icon button
            Button {
                openWindow(id: AmanApp.WindowID.about.rawValue)
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.secondary.opacity(0.12))
                    Circle()
                        .stroke(Color.secondary.opacity(0.25), lineWidth: 0.5)
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                }
                .frame(width: 24, height: 24)
                .contentShape(Circle())
                .accessibilityLabel("About Aman")
            }
            .buttonStyle(.plain) // keep it lightweight
            .help("About Aman")
        }
        .frame(maxWidth: 980, alignment: .leading)
        .opacity(0.9)
    }

    private func openWorkspace(_ id: AmanApp.WindowID) {
        print("[Landing] Opening workspace: \(id.rawValue)")
        openWindow(id: id.rawValue)
        DispatchQueue.main.async {
            WindowManager.closeWindows(with: AmanApp.WindowID.landing.rawValue)
            dismiss()
        }
    }
}

private struct LandingTile: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color
    let action: () -> Void

    @State private var isHovering = false
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button(action: action) {
            ZStack {
                // Layered glass card
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(backgroundMaterial)
                    .overlay(gradientStroke)
                    .shadow(color: .black.opacity(isHovering ? 0.22 : 0.10), radius: isHovering ? 16 : 10, x: 0, y: isHovering ? 12 : 6)
                    .overlay(innerHighlight)
                    .overlay(tintGlow)

                // Content
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            tint.opacity(0.30),
                                            tint.opacity(0.12)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 48, height: 48)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(tint.opacity(0.35), lineWidth: 0.8)
                                )
                                .shadow(color: tint.opacity(isHovering ? 0.25 : 0.10), radius: isHovering ? 12 : 6, x: 0, y: isHovering ? 8 : 3)

                            Image(systemName: icon)
                                .font(.system(size: 21, weight: .semibold))
                                .foregroundStyle(tint)
                                .offset(x: isHovering && !reduceMotion ? 0.4 : 0, y: isHovering && !reduceMotion ? -0.4 : 0)
                                .animation(.spring(response: 0.35, dampingFraction: 0.75), value: isHovering)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(title)
                                .font(.title2.weight(.semibold))
                                .foregroundStyle(.primary)
                            Text(eyebrow)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer(minLength: 0)
                    }

                    Text(subtitle)
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 8)

                    HStack(spacing: 8) {
                        Text("Open")
                            .font(.subheadline.weight(.semibold))
                        Image(systemName: "arrow.right")
                            .font(.subheadline.weight(.semibold))
                            .offset(x: isHovering && !reduceMotion ? 2.0 : 0)
                            .animation(.easeInOut(duration: 0.18), value: isHovering)
                    }
                    .foregroundStyle(tint)
                    .padding(.top, 2)
                }
                .padding(26)
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 244)
            }
            .scaleEffect(isHovering && !reduceMotion ? 1.012 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isHovering)
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .accessibilityLabel(Text("\(title). \(subtitle)"))
            .accessibilityAddTraits(.isButton)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private var eyebrow: String {
        switch title {
        case "OS Security":
            return "Hardening & Compliance"
        case "Network Security":
            return "Internet Toolkit & Utilities"
        default:
            return ""
        }
    }

    private var backgroundMaterial: some ShapeStyle {
        // Subtle glassy card that adapts to theme
        if colorScheme == .dark {
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor).opacity(0.65))
        } else {
            return AnyShapeStyle(Color(nsColor: .controlBackgroundColor))
        }
    }

    private var gradientStroke: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.10 : 0.55),
                        Color.white.opacity(0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isHovering ? 1.6 : 1.0
            )
            .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    private var innerHighlight: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .strokeBorder(
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.06 : 0.10),
                        Color.clear
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
            .blendMode(.overlay)
            .allowsHitTesting(false)
    }

    private var tintGlow: some View {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(tint.opacity(isHovering ? 0.06 : 0.0))
            .blur(radius: isHovering ? 16 : 0)
            .animation(.easeOut(duration: 0.18), value: isHovering)
            .allowsHitTesting(false)
    }
}

// A simple adaptive row that stacks vertically on narrow widths.
private struct AdaptiveTileRow<Content: View>: View {
    let spacing: CGFloat
    @ViewBuilder let content: Content
    @Environment(\.horizontalSizeClass) private var sizeClass

    init(spacing: CGFloat = 16, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        GeometryReader { proxy in
            let isCompact = proxy.size.width < 760
            Group {
                if isCompact {
                    VStack(spacing: spacing) {
                        content
                    }
                    .transition(.opacity.combined(with: .move(edge: .top)))
                } else {
                    HStack(spacing: spacing) {
                        content
                    }
                    .transition(.opacity)
                }
            }
            .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
        }
        .frame(minHeight: 260)
    }
}

// MARK: - App Icon Badge

private struct AppIconBadge: View {
    let size: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    init(size: CGFloat = 40) {
        self.size = size
    }

    var body: some View {
        if let uiImage = NSImage(named: NSImage.applicationIconName) {
            // Use the app’s icon as provided by the app bundle
            Image(nsImage: uiImage)
                .resizable()
                .interpolation(.high)
                .cornerRadius(size * 0.22)
                .frame(width: size, height: size)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(Color.primary.opacity(0.08), lineWidth: 0.5)
                )
                .shadow(color: .black.opacity(0.10), radius: 6, x: 0, y: 3)
        } else if let appIcon = Image("AppIcon", bundle: .main).optional() {
            appIcon
                .resizable()
                .interpolation(.high)
                .cornerRadius(size * 0.22)
                .frame(width: size, height: size)
        } else {
            // Fallback symbol if no icon available
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.25 : 0.18))
                .frame(width: size, height: size)
                .overlay(
                    Image(systemName: "magnifyingglass")
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color.accentColor)
                        .font(.system(size: size * 0.52, weight: .semibold))
                )
        }
    }
}

private extension Image {
    // Lightweight opt-in to treat an Image initializer as optional
    init?(_ name: String, bundle: Bundle? = nil) {
        if let nsImage = NSImage(named: name) {
            self = Image(nsImage: nsImage)
        } else {
            return nil
        }
    }

    func optional() -> Image? { self }
}

// MARK: - Utilities

private struct AnimatedShift: ViewModifier {
    @Binding var phase: CGFloat
    let reduceMotion: Bool

    func body(content: Content) -> some View {
        if reduceMotion {
            content
        } else {
            content
                .offset(x: (phase * 2.0) - 1.0) // small oscillation
        }
    }
}
