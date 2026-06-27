import AppKit
import Carbon

enum SwitcherSessionTrigger {
    case hotkey
    case menu
}

final class SwitcherSessionController {
    private let permissionService: AccessibilityPermissionService
    private let inventoryService: WindowInventoryService
    private let workspaceFilter: PublicWorkspaceFilter
    private let activationService: WindowActivationService
    private let overlayController: SwitcherOverlayController

    private var candidates: [WindowCandidate] = []
    private var selectedIndex = 0
    private var localKeyMonitor: Any?
    private var globalKeyMonitor: Any?
    private var localModifierMonitor: Any?
    private var globalModifierMonitor: Any?
    private var activationModifierFlags: NSEvent.ModifierFlags = []

    init(
        permissionService: AccessibilityPermissionService,
        inventoryService: WindowInventoryService,
        workspaceFilter: PublicWorkspaceFilter,
        activationService: WindowActivationService,
        overlayController: SwitcherOverlayController
    ) {
        self.permissionService = permissionService
        self.inventoryService = inventoryService
        self.workspaceFilter = workspaceFilter
        self.activationService = activationService
        self.overlayController = overlayController
    }

    func handleSwitcherShortcut(
        trigger: SwitcherSessionTrigger = .hotkey,
        activationModifierFlags: NSEvent.ModifierFlags = []
    ) {
        DispatchQueue.main.async {
            if self.overlayController.isVisible {
                self.moveSelection(by: 1)
            } else {
                self.beginSession(trigger: trigger, activationModifierFlags: activationModifierFlags)
            }
        }
    }

    /// Starts a switcher session by collecting current-workspace windows and showing the overlay.
    private func beginSession(trigger: SwitcherSessionTrigger, activationModifierFlags: NSEvent.ModifierFlags) {
        guard permissionService.isTrusted else {
            permissionService.requestTrustPrompt()
            Diagnostics.log("Accessibility permission is required before windows can be listed")
            return
        }

        let rawCandidates = inventoryService.snapshot()
        candidates = workspaceFilter.filter(rawCandidates)
        Diagnostics.log("Window candidates: raw=\(rawCandidates.count), currentWorkspace=\(candidates.count)")
        selectedIndex = candidates.count > 1 ? 1 : 0

        guard !candidates.isEmpty else {
            Diagnostics.log("No current-workspace window candidates found")
            return
        }

        installSessionEventMonitors(activationModifierFlags: trigger == .hotkey ? activationModifierFlags : [])
        overlayController.show(candidates: candidates, selectedIndex: selectedIndex)
    }

    /// Advances the selected candidate, wrapping around either end of the list.
    private func moveSelection(by offset: Int) {
        guard !candidates.isEmpty else {
            return
        }

        selectedIndex = (selectedIndex + offset + candidates.count) % candidates.count
        overlayController.updateSelection(selectedIndex)
    }

    /// Activates the selected window after tearing down the transient switcher UI.
    private func activateSelection() {
        guard candidates.indices.contains(selectedIndex) else {
            cancelSession()
            return
        }

        let candidate = candidates[selectedIndex]
        cancelSession()
        activationService.activate(candidate)
    }

    /// Ends the active switcher session and removes event monitors installed for it.
    private func cancelSession() {
        overlayController.hide()
        candidates = []
        selectedIndex = 0
        activationModifierFlags = []
        removeSessionEventMonitors()
    }

    /// Captures keyboard navigation while the overlay is visible and optionally activates on shortcut modifier release.
    private func installSessionEventMonitors(activationModifierFlags: NSEvent.ModifierFlags) {
        removeSessionEventMonitors()
        self.activationModifierFlags = activationModifierFlags

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleSessionKeyDown(event, canConsumeEvent: true) ?? event
        }

        globalKeyMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleSessionKeyDown(event, canConsumeEvent: false)
        }

        guard !activationModifierFlags.isEmpty else {
            return
        }

        localModifierMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierChange(event)
            return event
        }

        globalModifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.handleModifierChange(event)
        }
    }

    private func handleSessionKeyDown(_ event: NSEvent, canConsumeEvent: Bool) -> NSEvent? {
        guard overlayController.isVisible else {
            return event
        }

        switch Int(event.keyCode) {
        case kVK_Return:
            activateSelection()
            return canConsumeEvent ? nil : event
        case kVK_Tab:
            moveSelection(by: event.modifierFlags.contains(.shift) ? -1 : 1)
            return canConsumeEvent ? nil : event
        case kVK_Escape:
            cancelSession()
            return canConsumeEvent ? nil : event
        case kVK_LeftArrow:
            moveSelection(by: -1)
            return canConsumeEvent ? nil : event
        case kVK_RightArrow:
            moveSelection(by: 1)
            return canConsumeEvent ? nil : event
        default:
            return event
        }
    }

    private func handleModifierChange(_ event: NSEvent) {
        guard overlayController.isVisible else {
            return
        }

        if !event.modifierFlags.contains(activationModifierFlags) {
            Diagnostics.log("Switcher shortcut modifier released; activating selected window")
            activateSelection()
        }
    }

    private func removeSessionEventMonitors() {
        let monitors = [
            localKeyMonitor,
            globalKeyMonitor,
            localModifierMonitor,
            globalModifierMonitor
        ]

        for monitor in monitors {
            if let monitor {
                NSEvent.removeMonitor(monitor)
            }
        }

        localKeyMonitor = nil
        globalKeyMonitor = nil
        localModifierMonitor = nil
        globalModifierMonitor = nil
    }
}
