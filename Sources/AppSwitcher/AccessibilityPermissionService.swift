import ApplicationServices
import AppKit
import Foundation

final class AccessibilityPermissionService {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    /// Asks macOS to show the Accessibility permission prompt when trust has not been granted.
    func requestTrustPrompt() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Opens the Accessibility privacy pane, falling back to the main System Settings app.
    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

        if let url, NSWorkspace.shared.open(url) {
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
