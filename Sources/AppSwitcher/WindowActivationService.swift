import AppKit
import ApplicationServices

final class WindowActivationService {
    func activate(_ candidate: WindowCandidate) {
        AXUIElementPerformAction(candidate.axWindow, kAXRaiseAction as CFString)

        setBooleanAttribute(kAXMainAttribute, value: true, on: candidate.axWindow)
        setBooleanAttribute(kAXFocusedAttribute, value: true, on: candidate.axWindow)

        guard let app = NSRunningApplication(processIdentifier: candidate.processIdentifier) else {
            Diagnostics.log("Could not find owning app for \(candidate.displayTitle)")
            return
        }

        let activated = app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])
        if !activated {
            Diagnostics.log("Fell back to app activation, but activation failed for \(candidate.appName)")
        }
    }

    private func setBooleanAttribute(_ attribute: String, value: Bool, on element: AXUIElement) {
        let result = AXUIElementSetAttributeValue(element, attribute as CFString, value as CFTypeRef)

        if result != .success {
            Diagnostics.log("Failed to set AX attribute \(attribute): \(result.rawValue)")
        }
    }
}
