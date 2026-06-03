import AppKit
import ApplicationServices
import CoreGraphics

final class WindowInventoryService {
    func snapshot() -> [WindowCandidate] {
        NSWorkspace.shared.runningApplications.flatMap(candidates(for:))
    }

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
    func copyAttribute<T>(_ attribute: String) -> T? {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &value)

        guard error == .success else {
            return nil
        }

        return value as? T
    }

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
