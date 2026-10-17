import AppKit
import Carbon
import Foundation

enum SwitcherSessionTrigger {
    case hotkey
    case menu
}

final class SwitcherSessionController {
    /// Gives shortcut presses queued during inventory an opportunity to advance the selection before the
    /// deferred modifier check commits it. A heuristic: it does not guarantee every queued event is drained.
    private static let deferredModifierCheckDelay: TimeInterval = 0.05

    private let permissionService: AccessibilityPermissionService
    private let inventoryService: WindowInventoryService
    private let workspaceFilter: PublicWorkspaceFilter
    private let activationService: WindowActivationService
    private let overlayController: SwitcherOverlayController

    private var candidates: [WindowCandidate] = []
    private var selectedIndex = 0
    /// Advances when a session ends so its pending deferred modifier check cannot act on a later session.
    private var sessionGeneration = 0
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
        activationModifierFlags: NSEvent.ModifierFlags = [],
        selectionOffset: Int = 1
    ) {
        // Shortcut callbacks run on the main thread. Advancing an open session synchronously keeps a
        // modifier release queued behind this press from committing the previous selection first.
        if overlayController.isVisible {
            moveSelection(by: selectionOffset)
            return
        }

        let requestedAt = ProcessInfo.processInfo.systemUptime

        DispatchQueue.main.async {
            if self.overlayController.isVisible {
                self.moveSelection(by: selectionOffset)
            } else {
                self.beginSession(
                    trigger: trigger,
                    activationModifierFlags: activationModifierFlags,
                    initialSelectionOffset: selectionOffset,
                    requestedAt: requestedAt
                )
            }
        }
    }

    /// Starts a switcher session by collecting current-workspace windows and showing the overlay.
    private func beginSession(
        trigger: SwitcherSessionTrigger,
        activationModifierFlags: NSEvent.ModifierFlags,
        initialSelectionOffset: Int,
        requestedAt: TimeInterval
    ) {
        guard permissionService.isTrusted else {
            permissionService.requestTrustPrompt()
            Diagnostics.logFailure(.sessionPermissionDenied)
            return
        }

        let inventoryStartedAt = ProcessInfo.processInfo.systemUptime
        let rawCandidates = inventoryService.snapshot()
        let inventoryCompletedAt = ProcessInfo.processInfo.systemUptime

        let filteringStartedAt = ProcessInfo.processInfo.systemUptime
        candidates = workspaceFilter.filter(rawCandidates)
        let filteringCompletedAt = ProcessInfo.processInfo.systemUptime

        Diagnostics.logCandidateCounts(raw: rawCandidates.count, currentWorkspace: candidates.count)
        selectedIndex = candidates.count > 1
            ? (initialSelectionOffset + candidates.count) % candidates.count
            : 0

        guard !candidates.isEmpty else {
            Diagnostics.log("No current-workspace window candidates found")
            return
        }

        installSessionEventMonitors(activationModifierFlags: trigger == .hotkey ? activationModifierFlags : [])

        let presentationStartedAt = ProcessInfo.processInfo.systemUptime
        overlayController.show(candidates: candidates, selectedIndex: selectedIndex)
        let presentationCompletedAt = ProcessInfo.processInfo.systemUptime

        let millisecondsPerSecond = 1_000.0

        Diagnostics.logOverlayLatency(
            totalMilliseconds: (presentationCompletedAt - requestedAt) * millisecondsPerSecond,
            inventoryMilliseconds: (inventoryCompletedAt - inventoryStartedAt) * millisecondsPerSecond,
            filteringMilliseconds: (filteringCompletedAt - filteringStartedAt) * millisecondsPerSecond,
            presentationMilliseconds: (presentationCompletedAt - presentationStartedAt) * millisecondsPerSecond
        )

        scheduleDeferredModifierCheck()
    }

    /// Commits a hotkey session whose activation modifier is already up. The modifier monitors only observe
    /// releases after installation, so a release during inventory would otherwise leave the overlay open.
    private func scheduleDeferredModifierCheck() {
        guard !activationModifierFlags.isEmpty else {
            return
        }

        let generation = sessionGeneration

        DispatchQueue.main.asyncAfter(deadline: .now() + Self.deferredModifierCheckDelay) { [weak self] in
            guard let self, self.sessionGeneration == generation, self.isActivationModifierReleased() else {
                return
            }

            Diagnostics.logDeferredModifierCommit()
            self.activateSelection()
        }
    }

    /// Reads the live session modifier state, independent of which modifier events the monitors received.
    private func isActivationModifierReleased() -> Bool {
        let liveFlags = NSEvent.ModifierFlags(
            rawValue: UInt(CGEventSource.flagsState(.combinedSessionState).rawValue)
        )
        return !liveFlags.contains(activationModifierFlags)
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

        guard permissionService.isTrusted else {
            permissionService.requestTrustPrompt()
            Diagnostics.logFailure(.activationPermissionDenied)
            return
        }

        activationService.activate(candidate)
    }

    /// Ends the active switcher session and removes event monitors installed for it.
    private func cancelSession() {
        sessionGeneration += 1
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
