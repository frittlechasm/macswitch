import AppKit
import ApplicationServices
import CoreGraphics

final class WindowInventoryService {
    /// Builds a fresh list of switchable windows from currently running regular apps.
    func snapshot() -> [WindowCandidate] {
        NSWorkspace.shared.runningApplications.flatMap(candidates(for:))
    }

    /// Returns Accessibility-backed window candidates for one foreground-capable app.
    private func candidates(for app: NSRunningApplication) -> [WindowCandidate] {
        guard app.activationPolicy == .regular else {
            return []
        }

        guard !app.isHidden else {
            return []
        }

        let appElement = AXUIElementCreateApplication(app.processIdentifier)
        guard let windows: [AXUIElement] = appElement.copyAttribute(kAXWindowsAttribute) else {
            return []
        }

        return windows.enumerated().compactMap { index, window in
            candidate(for: window, app: app, index: index)
        }
    }

    /// Converts one AX window into a domain candidate after filtering non-switchable windows.
    private func candidate(for window: AXUIElement, app: NSRunningApplication, index: Int) -> WindowCandidate? {
        if (window.copyAttribute(kAXMinimizedAttribute) as Bool?) == true {
            return nil
        }

        guard isMainUserFacingWindow(window) else {
            return nil
        }

        let title = (window.copyAttribute(kAXTitleAttribute) as String?)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        guard !title.isEmpty else {
            return nil
        }

        guard let frame = window.windowFrame, !frame.isEmpty else {
            return nil
        }

        let appName = app.localizedName ?? app.bundleIdentifier ?? "Unknown App"
        let id = [
            String(app.processIdentifier),
            app.bundleIdentifier ?? "unknown",
            title,
            String(index)
        ].joined(separator: "::")

        return WindowCandidate(
            id: id,
            processIdentifier: app.processIdentifier,
            appName: appName,
            bundleIdentifier: app.bundleIdentifier,
            title: title,
            frame: frame,
            appIcon: app.icon,
            axWindow: window
        )
    }

    /// Keeps standard document-style windows while excluding sheets, dialogs, and custom UI.
    private func isMainUserFacingWindow(_ window: AXUIElement) -> Bool {
        let role = window.copyAttribute(kAXRoleAttribute) as String?
        let subrole = window.copyAttribute(kAXSubroleAttribute) as String?

        guard role == kAXWindowRole as String else {
            return false
        }

        if subrole == nil {
            return true
        }

        return subrole == kAXStandardWindowSubrole as String
    }
}

private extension AXUIElement {
    /// Reads and casts one Accessibility attribute, returning nil when the app does not expose it.
    func copyAttribute<T>(_ attribute: String) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &value)

        guard error == .success else {
            return nil
        }

        return value as? T
    }

    /// Reconstructs a window frame from separate AX position and size attributes.
    var windowFrame: CGRect? {
        guard
            let positionValue: AXValue = copyAttribute(kAXPositionAttribute),
            let sizeValue: AXValue = copyAttribute(kAXSizeAttribute)
        else {
            return nil
        }

        var position = CGPoint.zero
        var size = CGSize.zero

        guard
            AXValueGetValue(positionValue, .cgPoint, &position),
            AXValueGetValue(sizeValue, .cgSize, &size)
        else {
            return nil
        }

        return CGRect(origin: position, size: size)
    }
}
