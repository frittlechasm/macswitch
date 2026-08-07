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
            Diagnostics.logFailure(
                .activationWindowUnavailable,
                errorCode: error?.rawValue,
                privateContext: "\(candidate.appName); \(reason)"
            )
            return
        case .indeterminate(let error):
            Diagnostics.logFailure(
                .activationValidationIndeterminate,
                errorCode: error.rawValue,
                privateContext: candidate.appName
            )
        }

        if let app = NSRunningApplication(processIdentifier: candidate.processIdentifier) {
            let activated = app.activate()
            if !activated {
                Diagnostics.logFailure(
                    .activationAppActivateFailed,
                    privateContext: candidate.appName
                )
            }
        } else {
            Diagnostics.logFailure(
                .activationAppNotFound,
                privateContext: "\(candidate.appName); pid=\(candidate.processIdentifier)"
            )
        }

        let raiseResult = AXUIElementPerformAction(candidate.axWindow, kAXRaiseAction as CFString)
        if raiseResult != .success {
            Diagnostics.logFailure(
                .activationRaiseFailed,
                errorCode: raiseResult.rawValue,
                privateContext: candidate.appName
            )
        }

        setBooleanAttribute(
            kAXMainAttribute,
            value: true,
            on: candidate.axWindow,
            failureStage: .activationSetMainFailed
        )
        setBooleanAttribute(
            kAXFocusedAttribute,
            value: true,
            on: candidate.axWindow,
            failureStage: .activationSetFocusedFailed
        )
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
    private func setBooleanAttribute(
        _ attribute: String,
        value: Bool,
        on element: AXUIElement,
        failureStage: Diagnostics.FailureStage
    ) {
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef)

        if result != .success {
            Diagnostics.logFailure(
                failureStage,
                errorCode: result.rawValue
            )
        }
    }
}
