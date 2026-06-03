import ApplicationServices
import AppKit
import Foundation

final class AccessibilityPermissionService {
    var isTrusted: Bool {
        AXIsProcessTrusted()
    }

    func requestTrustPrompt() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ] as CFDictionary

        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")

        if let url, NSWorkspace.shared.open(url) {
            return
        }

        NSWorkspace.shared.open(URL(fileURLWithPath: "/System/Applications/System Settings.app"))
    }
}
