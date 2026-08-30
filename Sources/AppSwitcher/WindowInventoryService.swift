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
        let timeoutResult = AXUIElementSetMessagingTimeout(appElement, 0.25)
        if timeoutResult != .success {
            Diagnostics.log("Failed to set AX messaging timeout for \(app.localizedName ?? "unknown app"): \(timeoutResult.rawValue)")
        }

        guard let windows = windows(for: appElement, appName: app.localizedName) else {
            return []
        }

        return windows.enumerated().compactMap { index, window in
            candidate(for: window, app: app, index: index)
        }
    }

    /// Retries the transient AX messaging failure once before omitting an app from the inventory.
    private func windows(for appElement: AXUIElement, appName: String?) -> [AXUIElement]? {
        let firstAttempt: AXAttributeResult<[AXUIElement]> = appElement.copyAttributeResult(kAXWindowsAttribute)
        if case let .success(windows) = firstAttempt {
            return windows
        }

        let finalAttempt: AXAttributeResult<[AXUIElement]>
        if case .failure(.cannotComplete) = firstAttempt {
            finalAttempt = appElement.copyAttributeResult(kAXWindowsAttribute)
        } else {
            finalAttempt = firstAttempt
        }

        switch finalAttempt {
        case let .success(windows):
            return windows
        case let .failure(error):
            Diagnostics.logFailure(
                .inventoryWindowsUnavailable,
                errorCode: error.rawValue,
                privateContext: appName
            )
            return nil
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

private enum AXAttributeResult<Value> {
    case success(Value)
    case failure(AXError)
}

private extension AXUIElement {
    func copyAttributeResult<T>(_ attribute: String) -> AXAttributeResult<T> {
        var value: CFTypeRef?
        let error = AXUIElementCopyAttributeValue(self, attribute as CFString, &value)

        guard error == .success else {
            return .failure(error)
        }

        guard let value = value as? T else {
            return .failure(.failure)
        }

        return .success(value)
    }

    /// Reads and casts one Accessibility attribute, returning nil when the app does not expose it.
    func copyAttribute<T>(_ attribute: String) -> T? {
        let result: AXAttributeResult<T> = copyAttributeResult(attribute)
        guard case let .success(value) = result else {
            return nil
        }

        return value
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
