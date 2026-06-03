import AppKit

final class SwitcherSessionController {
    private let permissionService: AccessibilityPermissionService
    private let inventoryService: WindowInventoryService
    private let workspaceFilter: PublicWorkspaceFilter
    private let activationService: WindowActivationService
    private let overlayController: SwitcherOverlayController

    private var candidates: [WindowCandidate] = []
    private var selectedIndex = 0
    private var localKeyMonitor: Any?
    private var globalModifierMonitor: Any?

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

    func handleSwitcherShortcut() {
        DispatchQueue.main.async {
            if self.overlayController.isVisible {
                self.moveSelection(by: 1)
            } else {
                self.beginSession()
            }
        }
    }

    private func beginSession() {
        guard permissionService.isTrusted else {
            permissionService.requestTrustPrompt()
            Diagnostics.log("Accessibility permission is required before windows can be listed")
            return
        }

        let rawCandidates = inventoryService.snapshot()
        candidates = workspaceFilter.filter(rawCandidates)
        Diagnostics.log("Window candidates: raw=\(rawCandidates.count), currentWorkspace=\(candidates.count)")
        selectedIndex = 0

        guard !candidates.isEmpty else {
            Diagnostics.log("No current-workspace window candidates found")
            return
        }

        installSessionEventMonitors()
        overlayController.show(candidates: candidates, selectedIndex: selectedIndex)
    }

    private func moveSelection(by offset: Int) {
        guard !candidates.isEmpty else {
            return
        }

        selectedIndex = (selectedIndex + offset + candidates.count) % candidates.count
        overlayController.updateSelection(selectedIndex)
    }

    private func activateSelection() {
        guard candidates.indices.contains(selectedIndex) else {
            cancelSession()
            return
        }

        let candidate = candidates[selectedIndex]
        cancelSession()
        activationService.activate(candidate)
    }

    private func cancelSession() {
        overlayController.hide()
        candidates = []
        selectedIndex = 0
        removeSessionEventMonitors()
    }

    private func installSessionEventMonitors() {
        removeSessionEventMonitors()

        localKeyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else {
                return event
            }

            switch event.keyCode {
            case 36:
                self.activateSelection()
                return nil
            case 48:
                self.moveSelection(by: event.modifierFlags.contains(.shift) ? -1 : 1)
                return nil
            case 53:
                self.cancelSession()
                return nil
            case 123:
                self.moveSelection(by: -1)
                return nil
            case 124:
                self.moveSelection(by: 1)
                return nil
            default:
                return event
            }
        }

        globalModifierMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            guard let self else {
                return
            }

            DispatchQueue.main.async {
                guard self.overlayController.isVisible else {
                    return
                }

                if !event.modifierFlags.contains(.option) {
                    Diagnostics.log("Option released; activating selected window")
                    self.activateSelection()
                }
            }
        }
    }

    private func removeSessionEventMonitors() {
        if let localKeyMonitor {
            NSEvent.removeMonitor(localKeyMonitor)
            self.localKeyMonitor = nil
        }

        if let globalModifierMonitor {
            NSEvent.removeMonitor(globalModifierMonitor)
            self.globalModifierMonitor = nil
        }
    }
}
