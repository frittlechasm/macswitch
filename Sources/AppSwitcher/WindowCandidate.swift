import AppKit
import ApplicationServices

/// A selectable top-level window that App Switcher can display and activate.
struct WindowCandidate: Identifiable {
    let id: String
    let processIdentifier: pid_t
    let appName: String
    let bundleIdentifier: String?
    let title: String
    let frame: CGRect
    let appIcon: NSImage?
    let axWindow: AXUIElement

    var displayTitle: String {
        title.isEmpty ? appName : title
    }
}
