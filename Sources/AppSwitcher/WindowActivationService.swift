import AppKit
import ApplicationServices

final class WindowActivationService {
    private enum WindowAvailability {
        case available
        case unavailable(reason: String, error: AXError?)
        case indeterminate(AXError)
    }

    /// Skips activation when the selected Accessibility window is definitively unavailable.
    func activate(_ candidate: WindowCandidate) {
        let timeoutResult = AXUIElementSetMessagingTimeout(candidate.axWindow, 0.25)
        if timeoutResult != .success, timeoutResult != .invalidUIElement {
            Diagnostics.log("Failed to set AX validation timeout for \(candidate.appName): \(timeoutResult.rawValue)")
        }

        let windowAvailability = availability(of: candidate.axWindow)
        let timeoutResetResult = AXUIElementSetMessagingTimeout(candidate.axWindow, 0)
        if timeoutResetResult != .success, timeoutResetResult != .invalidUIElement {
            Diagnostics.log("Failed to reset AX messaging timeout for \(candidate.appName): \(timeoutResetResult.rawValue)")
        }

        switch windowAvailability {
        case .available:
            break
        case .unavailable(let reason, let error):
            let errorDetail = error.map { "; AX error=\($0.rawValue)" } ?? ""
            Diagnostics.log("Selected window for \(candidate.appName) is no longer available; \(reason)\(errorDetail); skipping activation")
            return
        case .indeterminate(let error):
            Diagnostics.log("Could not validate selected window for \(candidate.appName); continuing activation: \(error.rawValue)")
        }

        if let app = NSRunningApplication(processIdentifier: candidate.processIdentifier) {
            let activated = app.activate()
            if !activated {
                Diagnostics.log("Failed to activate owning app for \(candidate.appName)")
            }
        } else {
            Diagnostics.log("Could not find owning app for pid \(candidate.processIdentifier)")
        }

        let raiseResult = AXUIElementPerformAction(candidate.axWindow, kAXRaiseAction as CFString)
        if raiseResult != .success {
            Diagnostics.log("Failed to raise AX window for \(candidate.appName): \(raiseResult.rawValue)")
        }

        setBooleanAttribute(kAXMainAttribute, value: true, on: candidate.axWindow)
        setBooleanAttribute(kAXFocusedAttribute, value: true, on: candidate.axWindow)
    }

    /// Distinguishes a stale AX element from transient messaging and permission failures.
    private func availability(of element: AXUIElement) -> WindowAvailability {
        var roleValue: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            element,
            kAXRoleAttribute as CFString,
            &roleValue
        )

        guard result == .success else {
            return result == .invalidUIElement
                ? .unavailable(reason: "invalid AX element", error: result)
                : .indeterminate(result)
        }

        guard let role = roleValue as? String else {
            return .unavailable(reason: "AX window role missing", error: nil)
        }

        guard role == kAXWindowRole as String else {
            return .unavailable(reason: "AX role=\(role)", error: nil)
        }

        return .available
    }

    /// Sets an Accessibility boolean attribute and logs failures without interrupting activation.
    private func setBooleanAttribute(_ attribute: String, value: Bool, on element: AXUIElement) {
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef)

        if result != .success {
            Diagnostics.log("Failed to set AX attribute \(attribute): \(result.rawValue)")
        }
    }
}
