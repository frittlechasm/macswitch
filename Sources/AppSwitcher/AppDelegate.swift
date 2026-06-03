import AppKit

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?
    private var hotKeyMonitor: GlobalHotKeyMonitor?
    private var sessionController: SwitcherSessionController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        Diagnostics.log("App Switcher is running as a menu-bar app. Press Option-Tab to open it, or Ctrl-C in this terminal to stop it.")

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
        self.statusBarController = StatusBarController(
            permissionService: permissionService,
            sessionController: sessionController
        )

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
            Diagnostics.log("Accessibility permission is not granted. Opening the macOS permission prompt.")
            permissionService.requestTrustPrompt()
        } else {
            Diagnostics.log("Accessibility permission is granted.")
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        Diagnostics.log("App Switcher is stopping.")
        hotKeyMonitor?.stop()
    }
}
