import AppKit

final class PreferencesWindowController: NSWindowController {
    private let shortcutStore: SwitcherShortcutStore
    private let onShortcutChanged: (SwitcherShortcut) -> Bool
    private let shortcutPopup = NSPopUpButton(frame: .zero, pullsDown: false)
    private let resetButton = NSButton(
        title: "Reset to Option-Tab",
        target: nil,
        action: nil
    )
    private let statusLabel = NSTextField(labelWithString: "")

    init(shortcutStore: SwitcherShortcutStore, onShortcutChanged: @escaping (SwitcherShortcut) -> Bool) {
        self.shortcutStore = shortcutStore
        self.onShortcutChanged = onShortcutChanged

        let window = NSWindow(
            contentRect: CGRect(x: 0, y: 0, width: 440, height: 190),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )

        window.title = "Mac Workspace Switcher Settings"
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

        let appIcon = NSImageView(image: NSApplication.shared.applicationIconImage)
        appIcon.imageScaling = .scaleProportionallyUpOrDown
        appIcon.translatesAutoresizingMaskIntoConstraints = false

        let titleLabel = NSTextField(labelWithString: "Mac Workspace Switcher Shortcut")
        titleLabel.font = .systemFont(ofSize: 13, weight: .semibold)

        let headerStack = NSStackView(views: [appIcon, titleLabel])
        headerStack.orientation = .horizontal
        headerStack.alignment = .centerY
        headerStack.spacing = 10

        let helpLabel = NSTextField(
            labelWithString: "Choose the shortcut that opens and advances Mac Workspace Switcher. Command-Tab requires Accessibility permission."
        )
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.lineBreakMode = .byWordWrapping
        helpLabel.maximumNumberOfLines = 2

        for shortcut in SwitcherShortcut.allCases {
            shortcutPopup.addItem(withTitle: shortcut.displayName)
            shortcutPopup.lastItem?.representedObject = shortcut.rawValue
        }

        shortcutPopup.target = self
        shortcutPopup.action = #selector(shortcutSelectionChanged)

        resetButton.target = self
        resetButton.action = #selector(resetShortcut)

        let shortcutControls = NSStackView(views: [shortcutPopup, resetButton])
        shortcutControls.orientation = .horizontal
        shortcutControls.alignment = .centerY
        shortcutControls.spacing = 10

        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2

        let stackView = NSStackView(views: [headerStack, shortcutControls, helpLabel, statusLabel])
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 10
        stackView.translatesAutoresizingMaskIntoConstraints = false

        contentView.addSubview(stackView)

        NSLayoutConstraint.activate([
            stackView.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),
            stackView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            stackView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            appIcon.widthAnchor.constraint(equalToConstant: 32),
            appIcon.heightAnchor.constraint(equalToConstant: 32),
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

        apply(shortcut)
    }

    @objc private func resetShortcut() {
        apply(.defaultShortcut)
    }

    private func apply(_ shortcut: SwitcherShortcut) {
        guard onShortcutChanged(shortcut) else {
            refreshSelection()
            if shortcut == .commandTab {
                statusLabel.stringValue = "Could not intercept Command-Tab. Confirm Accessibility permission or reset to Option-Tab."
            } else {
                statusLabel.stringValue = "Could not register that shortcut. Mac Workspace Switcher kept \(shortcutStore.selectedShortcut.displayName)."
            }
            return
        }

        refreshSelection()
    }
}
