import AppKit

final class PreferencesWindowController: NSWindowController {
    private let shortcutStore: SwitcherShortcutStore
    private let onShortcutChanged: (SwitcherShortcut) -> Bool
    private let shortcutPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let statusLabel = NSTextField(labelWithString: "")

    init(shortcutStore: SwitcherShortcutStore, onShortcutChanged: @escaping (SwitcherShortcut) -> Bool) {
        self.shortcutStore = shortcutStore
        self.onShortcutChanged = onShortcutChanged

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 380, height: 170),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "App Switcher Settings"
        window.isReleasedWhenClosed = false
        window.center()

        super.init(window: window)
        configureContent()
        refreshSelection()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        refreshSelection()
        window?.center()
        window?.makeKeyAndOrderFront(nil)
        NSApplication.shared.activate(ignoringOtherApps: true)
    }

    private func configureContent() {
        guard let contentView = window?.contentView else {
            return
        }

        let titleLabel = NSTextField(labelWithString: "Switcher Shortcut")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let helpLabel = NSTextField(labelWithString: "Choose the shortcut that opens and advances App Switcher.")
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.lineBreakMode = .byWordWrapping
        helpLabel.maximumNumberOfLines = 2

        for shortcut in SwitcherShortcut.allCases {
            shortcutPopup.addItem(withTitle: shortcut.displayName)
            shortcutPopup.lastItem?.representedObject = shortcut.rawValue
        }

        shortcutPopup.target = self
        shortcutPopup.action = #selector(shortcutSelectionChanged)

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let stackView = NSStackView(views: [titleLabel, shortcutPopup, helpLabel, statusLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            shortcutPopup.widthAnchor.constraint(equalToConstant: 180)
        ])
    }

    private func refreshSelection() {
        let selectedShortcut = shortcutStore.selectedShortcut
        shortcutPopup.selectItem(withTitle: selectedShortcut.displayName)
        statusLabel.stringValue = "Active shortcut: \(selectedShortcut.displayName)"
    }

    @objc private func shortcutSelectionChanged() {
        guard
            let rawValue = shortcutPopup.selectedItem?.representedObject as? String,
            let shortcut = SwitcherShortcut(rawValue: rawValue)
        else {
            refreshSelection()
            return
        }

        if onShortcutChanged(shortcut) {
            statusLabel.stringValue = "Active shortcut: \(shortcut.displayName)"
        } else {
            refreshSelection()
            statusLabel.stringValue = "Could not register that shortcut. App Switcher kept \(shortcutStore.selectedShortcut.displayName)."
        }
    }
}
