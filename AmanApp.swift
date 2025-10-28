//
//  AmanApp.swift
//  Aman
//
//  Created by Samet Sazak.
//  Updated by Arwindo Pratama.
//

import SwiftUI
import AppKit

@main
struct AmanApp: App {
    enum WindowID: String {
        case landing = "landing-selector"
        case osSecurity = "os-security"
        case networkSecurity = "network-security"
        case about = "about-aman-window"
    }

    var body: some Scene {
        WindowGroup("Aman", id: WindowID.landing.rawValue) {
            LandingSelectorView()
        }
        .windowStyle(.hiddenTitleBar)
        .defaultPosition(.center)
        .commands {
            SidebarCommands()

            CommandGroup(replacing: .appInfo) {
                OpenAboutCommand()
            }
        }

        WindowGroup("OS Security", id: WindowID.osSecurity.rawValue) {
            ContentView()
                .frame(minWidth: 1115, maxWidth: .infinity, minHeight: 615, maxHeight: .infinity)
        }
        .defaultPosition(.center)

        WindowGroup("Network Security", id: WindowID.networkSecurity.rawValue) {
            NetworkSecurityView()
        }
        .defaultPosition(.center)

        Window("About Aman", id: WindowID.about.rawValue) {
            AboutView()
                .frame(width: 484, height: 444)
        }
        .defaultPosition(.center)
        .windowResizability(.contentSize)
    }
}

// A small Command view that has access to the SwiftUI environment.
private struct OpenAboutCommand: View {
    @Environment(\.openWindow) private var openWindow

    var body: some View {
        Button("About Aman") {
            openWindow(id: AmanApp.WindowID.about.rawValue)
        }
    }
}
