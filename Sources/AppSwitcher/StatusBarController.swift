import AppKit

final class StatusBarController: NSObject {
    private let statusItem: NSStatusItem
    private let permissionService: AccessibilityPermissionService
    private weak var sessionController: SwitcherSessionController?
    private weak var preferencesWindowController: PreferencesWindowController?
    private let permissionStatusItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    init(
        permissionService: AccessibilityPermissionService,
        sessionController: SwitcherSessionController,
        preferencesWindowController: PreferencesWindowController
    ) {
        self.permissionService = permissionService
        self.sessionController = sessionController
        self.preferencesWindowController = preferencesWindowController
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        super.init()
        configure()
    }

    /// Builds the menu-bar item and wires each menu action back to this controller.
    private func configure() {
        statusItem.button?.image = NSImage(systemSymbolName: "rectangle.2.swap", accessibilityDescription: "Mac Workspace Switcher")

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "Show Mac Workspace Switcher", action: #selector(showSwitcher), keyEquivalent: ""))
        menu.addItem(permissionStatusItem)
        menu.addItem(NSMenuItem(title: "Request Accessibility Permission", action: #selector(requestAccessibilityPermission), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Open Accessibility Settings", action: #selector(openAccessibilitySettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Settings...", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q"))

        for item in menu.items {
            item.target = self
        }

        menu.delegate = self
        statusItem.menu = menu
        refreshPermissionStatus()
    }

    @objc private func showSwitcher() {
        sessionController?.handleSwitcherShortcut(trigger: .menu)
    }

    @objc private func requestAccessibilityPermission() {
        permissionService.requestTrustPrompt()
        refreshPermissionStatus()
    }

    @objc private func openAccessibilitySettings() {
        permissionService.openAccessibilitySettings()
    }

    @objc private func openSettings() {
        preferencesWindowController?.show()
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }

    private func refreshPermissionStatus() {
        permissionStatusItem.title = permissionService.isTrusted
            ? "Accessibility: Granted"
            : "Accessibility: Not Granted"
        permissionStatusItem.isEnabled = false
    }
}

extension StatusBarController: NSMenuDelegate {
    /// Refreshes permission state each time the menu opens because it can change in System Settings.
    func menuWillOpen(_ menu: NSMenu) {
        refreshPermissionStatus()
    }
}
