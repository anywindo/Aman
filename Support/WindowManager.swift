//
//  WindowManager.swift
//  Aman - Support
//
//  Created by Aman Team on 08/11/2025
//

import SwiftUI
import AppKit

struct WindowAccessor: NSViewRepresentable {
    let callback: (NSWindow?) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            callback(view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            callback(nsView.window)
        }
    }
}

enum WindowManager {
    static func closeWindows(with identifier: String) {
        DispatchQueue.main.async {
            NSApp.windows
                .filter { $0.identifier?.rawValue == identifier }
                .forEach { window in
                    print("[WindowManager] Closing window \(identifier)")
                    window.close()
                }
        }
    }
}
