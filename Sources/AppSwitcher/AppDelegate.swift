import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // AppKit does not retain these collaborators for us. Keep the long-lived app
    // controllers here so the status item, hotkey callback, and switcher session
    // stay alive for the whole menu-bar app lifecycle.
    private var statusBarController: StatusBarController?
    private var hotKeyMonitor: GlobalHotKeyMonitor?
    private var shortcutStore: SwitcherShortcutStore?
    private var preferencesWindowController: PreferencesWindowController?
    private var sessionController: SwitcherSessionController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.log("Mac Workspace Switcher is running as a menu-bar app. Use the configured Switcher Shortcut to open it, or Ctrl-C in this terminal to stop it.")

        let permissionService = AccessibilityPermissionService()
        let inventoryService = WindowInventoryService()
        let workspaceFilter = PublicWorkspaceFilter()
        let activationService = WindowActivationService()
        let overlayController = SwitcherOverlayController()
        let sessionController = SwitcherSessionController(
            permissionService: permissionService,
            inventoryService: inventoryService,
            workspaceFilter: workspaceFilter,
            activationService: activationService,
            overlayController: overlayController
        )

        self.sessionController = sessionController

        let shortcutStore = SwitcherShortcutStore()
        self.shortcutStore = shortcutStore

        let hotKeyMonitor = GlobalHotKeyMonitor { [weak self, weak sessionController] in
            let shortcut = self?.hotKeyMonitor?.shortcut ?? .defaultShortcut
            sessionController?.handleSwitcherShortcut(activationModifierFlags: shortcut.eventModifierFlags)
        }

        self.hotKeyMonitor = hotKeyMonitor

        let preferencesWindowController = PreferencesWindowController(
            shortcutStore: shortcutStore,
            onShortcutChanged: { [weak self] shortcut in
                self?.registerShortcut(shortcut, persistOnSuccess: true) ?? false
            }
        )

        self.preferencesWindowController = preferencesWindowController

        self.statusBarController = StatusBarController(
            permissionService: permissionService,
            sessionController: sessionController,
            preferencesWindowController: preferencesWindowController
        )

        registerPreferredShortcutWithFallbacks()

        if !permissionService.isTrusted {
            Diagnostics.log("Accessibility permission is not granted. Use the menu-bar item or switcher shortcut to request it.")
        } else {
            Diagnostics.log("Accessibility permission is granted.")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Diagnostics.log("Mac Workspace Switcher is stopping.")
        hotKeyMonitor?.stop()
    }

    @discardableResult
    private func registerShortcut(_ shortcut: SwitcherShortcut, persistOnSuccess: Bool) -> Bool {
        guard let hotKeyMonitor else {
            return false
        }

        if hotKeyMonitor.shortcut == shortcut {
            if persistOnSuccess {
                shortcutStore?.selectedShortcut = shortcut
            }
            return true
        }

        let previousShortcut = hotKeyMonitor.shortcut

        do {
            try hotKeyMonitor.start(shortcut: shortcut)
            if persistOnSuccess {
                shortcutStore?.selectedShortcut = shortcut
            }

            Diagnostics.log("Registered \(shortcut.displayName) switcher shortcut")
            return true
        } catch {
            logHotKeyRegistrationFailure(error, shortcut: shortcut)
            if persistOnSuccess, let previousShortcut {
                do {
                    try hotKeyMonitor.start(shortcut: previousShortcut)
                    Diagnostics.log("Restored \(previousShortcut.displayName) switcher shortcut")
                } catch {
                    logHotKeyRestoreFailure(error, shortcut: previousShortcut)
                    Diagnostics.logFailure(.hotKeyNoneRegistered)
                }
            }
            return false
        }
    }

    private func registerPreferredShortcutWithFallbacks() {
        guard let shortcutStore else {
            return
        }

        let preferredShortcut = shortcutStore.selectedShortcut
        let fallbackShortcuts = SwitcherShortcut.automaticFallbacks.filter { $0 != preferredShortcut }

        for shortcut in [preferredShortcut] + fallbackShortcuts {
            if registerShortcut(shortcut, persistOnSuccess: shortcut != preferredShortcut) {
                if shortcut != preferredShortcut {
                    Diagnostics.log("Using fallback switcher shortcut \(shortcut.displayName)")
                }
                return
            }
        }

        Diagnostics.logFailure(.hotKeyNoneRegistered)
    }

    private func logHotKeyRegistrationFailure(_ error: Error, shortcut: SwitcherShortcut) {
        switch error {
        case GlobalHotKeyError.installHandlerFailed(let status):
            Diagnostics.logFailure(
                .hotKeyInstallHandlerFailed,
                errorCode: status,
                privateContext: shortcut.displayName
            )
        case GlobalHotKeyError.registerHotKeyFailed(let status):
            Diagnostics.logFailure(
                .hotKeyRegisterFailed,
                errorCode: status,
                privateContext: shortcut.displayName
            )
        default:
            Diagnostics.logFailure(
                .hotKeyRegisterUnknownError,
                privateContext: "\(shortcut.displayName); \(error)"
            )
        }
    }

    private func logHotKeyRestoreFailure(_ error: Error, shortcut: SwitcherShortcut) {
        let errorCode: OSStatus?

        switch error {
        case GlobalHotKeyError.installHandlerFailed(let status),
             GlobalHotKeyError.registerHotKeyFailed(let status):
            errorCode = status
        default:
            errorCode = nil
        }

        Diagnostics.logFailure(
            .hotKeyRestoreFailed,
            errorCode: errorCode,
            privateContext: "\(shortcut.displayName); \(error)"
        )
    }
}
