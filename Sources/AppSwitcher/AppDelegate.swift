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

        // Composition root: construct the concrete services once at launch and
        // inject the same instances into the controllers that coordinate user
        // actions. This keeps each service focused on one macOS integration.

        // Checks and requests macOS Accessibility trust before Mac Workspace Switcher asks
        // other apps for their windows or tries to focus a selected window.
        let permissionService = AccessibilityPermissionService()

        // Builds raw switcher candidates from running regular apps and their
        // Accessibility windows, excluding hidden, minimized, and non-window UI.
        let inventoryService = WindowInventoryService()

        // Narrows raw candidates to windows that appear visible in the current
        // workspace using public Core Graphics window-server snapshots.
        let workspaceFilter = PublicWorkspaceFilter()

        // Raises and focuses the selected Accessibility window, with owning-app
        // activation as the final step that brings it to the foreground.
        let activationService = WindowActivationService()

        // Owns the transient floating UI shown while the user cycles windows.
        let overlayController = SwitcherOverlayController()

        // The session controller receives service dependencies explicitly so it
        // can orchestrate one switcher interaction without constructing macOS
        // integration objects itself.
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

        // The status menu shares the permission service and session controller
        // so menu actions use the same permission state and switcher flow as the
        // global shortcut.
        self.statusBarController = StatusBarController(
            permissionService: permissionService,
            sessionController: sessionController,
            preferencesWindowController: preferencesWindowController
        )

        // The global hotkey is intentionally thin: it only translates the shortcut
        // into the session controller command, leaving switching behavior there.
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
            Diagnostics.log("Failed to register \(shortcut.displayName) switcher shortcut: \(error)")
            if persistOnSuccess, let previousShortcut {
                do {
                    try hotKeyMonitor.start(shortcut: previousShortcut)
                    Diagnostics.log("Restored \(previousShortcut.displayName) switcher shortcut")
                } catch {
                    Diagnostics.log("Failed to restore \(previousShortcut.displayName) switcher shortcut: \(error)")
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
        let fallbackShortcuts = SwitcherShortcut.allCases.filter { $0 != preferredShortcut }

        for shortcut in [preferredShortcut] + fallbackShortcuts {
            if registerShortcut(shortcut, persistOnSuccess: shortcut != preferredShortcut) {
                if shortcut != preferredShortcut {
                    Diagnostics.log("Using fallback switcher shortcut \(shortcut.displayName)")
                }
                return
            }
        }

        Diagnostics.log("No switcher shortcut could be registered")
    }
}
