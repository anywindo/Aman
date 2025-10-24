//
//  AmanApp.swift
//  Aman
//
//  Created by Samet Sazak.
//  Updated by Arwindo Pratama.
//

import SwiftUI

@main
struct AmanApp: App {
    // Define an identifier for the About window
    fileprivate static let aboutWindowID = "about-aman-window"

    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 1115, maxWidth: .infinity, minHeight: 615, maxHeight: .infinity)
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            SidebarCommands()

            // Replace the standard About panel with our custom window
            CommandGroup(replacing: .appInfo) {
                OpenAboutCommand()
            }
        }

        // Dedicated About window scene
        Window("About Aman", id: AmanApp.aboutWindowID) {
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
            openWindow(id: AmanApp.aboutWindowID)
        }
    }
}
