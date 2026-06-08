import AppKit
import ApplicationServices

final class WindowActivationService {
    /// Raises and focuses the selected Accessibility window, then activates its owning app.
    func activate(_ candidate: WindowCandidate) {
        AXUIElementPerformAction(candidate.axWindow, kAXRaiseAction as CFString)

        setBooleanAttribute(kAXMainAttribute, value: true, on: candidate.axWindow)
        setBooleanAttribute(kAXFocusedAttribute, value: true, on: candidate.axWindow)

        // Keep app activation as a fallback for cases where AX focus alone is not enough.
        guard let app = NSRunningApplication(processIdentifier: candidate.processIdentifier) else {
            Diagnostics.log("Could not find owning app for pid \(candidate.processIdentifier)")
            return
        }

        let activated = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        if !activated {
            Diagnostics.log("Fell back to app activation, but activation failed for \(candidate.appName)")
        }
    }

    /// Sets an Accessibility boolean attribute and logs failures without interrupting activation.
    private func setBooleanAttribute(_ attribute: String, value: Bool, on element: AXUIElement) {
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef)

        if result != .success {
            Diagnostics.log("Failed to set AX attribute \(attribute): \(result.rawValue)")
        }
    }
}
