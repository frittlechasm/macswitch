import AppKit
import ApplicationServices

final class WindowActivationService {
    /// Activates the owning app, then raises and focuses the selected Accessibility window.
    func activate(_ candidate: WindowCandidate) {
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

    /// Sets an Accessibility boolean attribute and logs failures without interrupting activation.
    private func setBooleanAttribute(_ attribute: String, value: Bool, on element: AXUIElement) {
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef)

        if result != .success {
            Diagnostics.log("Failed to set AX attribute \(attribute): \(result.rawValue)")
        }
    }
}
