// 
//  [RemediationCatalog].swift 
//  Aman - [Engine] 
// 
//  Created by Aman Team on [08/11/25]. 
// 

import Foundation

struct RemediationShortcut: Hashable {
    enum Kind: Hashable {
        case systemSettings(URL)
        case command(String)
        case appleScript(String)
    }

    let title: String
    let subtitle: String?
    let kind: Kind

    init(title: String, subtitle: String? = nil, kind: Kind) {
        self.title = title
        self.subtitle = subtitle
        self.kind = kind
    }
}

enum RemediationCatalog {
    static func shortcuts(for finding: AuditFinding) -> [RemediationShortcut] {
        switch finding.docReference {
        case 2:
            return guestLoginShortcuts()
        case 102:
            return rapidSecurityResponseShortcuts()
        case 211:
            return appTrackingTransparencyShortcuts()
        default:
            return inferredShortcuts(from: finding)
        }
    }

    private static func guestLoginShortcuts() -> [RemediationShortcut] {
        var shortcuts: [RemediationShortcut] = []

        if let url = URL(string: "x-apple.systempreferences:com.apple.Users-Group-Settings.extension") {
            shortcuts.append(
                RemediationShortcut(
                    title: "Open Users & Groups",
                    subtitle: "System Settings ▸ Users & Groups ▸ Guest User",
                    kind: .systemSettings(url)
                )
            )
        }

        let script = """
tell application "System Events"
    do shell script "defaults write /Library/Preferences/com.apple.loginwindow DisableGuestAccount -bool true" with administrator privileges
end tell
"""
        shortcuts.append(
            RemediationShortcut(
                title: "Disable Guest Login via AppleScript",
                subtitle: "Runs the same policy change with admin authentication",
                kind: .appleScript(script)
            )
        )

        shortcuts.append(
            RemediationShortcut(
                title: "Disable Guest Login via CLI",
                subtitle: "Sets DisableGuestAccount to true",
                kind: .command("sudo defaults write /Library/Preferences/com.apple.loginwindow DisableGuestAccount -bool true")
            )
        )

        return shortcuts
    }

    private static func rapidSecurityResponseShortcuts() -> [RemediationShortcut] {
        var shortcuts: [RemediationShortcut] = []

        if let url = URL(string: "x-apple.systempreferences:com.apple.Software-Update-Settings.extension") ??
                      URL(string: "x-apple.systempreferences:com.apple.preferences.softwareupdate") {
            shortcuts.append(
                RemediationShortcut(
                    title: "Open Software Update",
                    subtitle: "Enable ‘Install Security Responses and system files’",
                    kind: .systemSettings(url)
                )
            )
        }

        shortcuts.append(
            RemediationShortcut(
                title: "Enable via CLI",
                subtitle: "Sets AutomaticallyInstallSecurityUpdates to true",
                kind: .command("sudo defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticallyInstallSecurityUpdates -bool true")
            )
        )

        return shortcuts
    }

    private static func appTrackingTransparencyShortcuts() -> [RemediationShortcut] {
        var shortcuts: [RemediationShortcut] = []

        if let url = URL(string: "x-apple.systempreferences:com.apple.settings.PrivacySecurity?Privacy_Tracking") {
            shortcuts.append(
                RemediationShortcut(
                    title: "Open Privacy & Security ▸ Tracking",
                    subtitle: "Disallow apps from requesting to track",
                    kind: .systemSettings(url)
                )
            )
        }

        return shortcuts
    }

    private static func inferredShortcuts(from finding: AuditFinding) -> [RemediationShortcut] {
        var shortcuts: [RemediationShortcut] = []

        if finding.remediation.localizedCaseInsensitiveContains("System Settings"),
           let url = URL(string: "x-apple.systempreferences:") {
            shortcuts.append(
                RemediationShortcut(
                    title: "Open System Settings",
                    kind: .systemSettings(url)
                )
            )
        }

        let trimmed = finding.remediation.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.hasPrefix("sudo ") ||
            trimmed.hasPrefix("defaults ") ||
            trimmed.contains(" /usr/") ||
            trimmed.contains(" /bin/") {
            shortcuts.append(
                RemediationShortcut(
                    title: "Run recommended command",
                    subtitle: "From the remediation text",
                    kind: .command(trimmed)
                )
            )
        }

        return shortcuts
    }
}
