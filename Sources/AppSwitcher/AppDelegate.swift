import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    // AppKit does not retain these collaborators for us. Keep the long-lived app
    // controllers here so the status item, hotkey callback, and switcher session
    // stay alive for the whole menu-bar app lifecycle.
    private var statusBarController: StatusBarController?
    private var hotKeyMonitor: GlobalHotKeyMonitor?
    private var sessionController: SwitcherSessionController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.log("App Switcher is running as a menu-bar app. Press Option-Tab to open it, or Ctrl-C in this terminal to stop it.")

        // Composition root: construct the concrete services once at launch and
        // inject the same instances into the controllers that coordinate user
        // actions. This keeps each service focused on one macOS integration.

        // Checks and requests macOS Accessibility trust before App Switcher asks
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

        // The status menu shares the permission service and session controller
        // so menu actions use the same permission state and switcher flow as the
        // global shortcut.
        self.statusBarController = StatusBarController(
            permissionService: permissionService,
            sessionController: sessionController
        )

        // The global hotkey is intentionally thin: it only translates Option-Tab
        // into the session controller command, leaving switching behavior there.
        let hotKeyMonitor = GlobalHotKeyMonitor {
            sessionController.handleSwitcherShortcut()
        }

        do {
            try hotKeyMonitor.start()
            self.hotKeyMonitor = hotKeyMonitor
            Diagnostics.log("Registered Option-Tab switcher shortcut")
        } catch {
            Diagnostics.log("Failed to register switcher shortcut: \(error)")
        }

        if !permissionService.isTrusted {
            Diagnostics.log("Accessibility permission is not granted. Use the menu-bar item or switcher shortcut to request it.")
        } else {
            Diagnostics.log("Accessibility permission is granted.")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Diagnostics.log("App Switcher is stopping.")
        hotKeyMonitor?.stop()
    }
}
