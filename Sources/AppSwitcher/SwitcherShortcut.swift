import AppKit
import Carbon
import Foundation

enum SwitcherShortcut: String, CaseIterable {
    case optionTab
    case controlTab
    case controlOptionTab
    case optionBacktick

    static let defaultShortcut: SwitcherShortcut = .optionTab

    var displayName: String {
        switch self {
        case .optionTab:
            return "Option-Tab"
        case .controlTab:
            return "Control-Tab"
        case .controlOptionTab:
            return "Control-Option-Tab"
        case .optionBacktick:
            return "Option-`"
        }
    }

    var keyCode: UInt32 {
        switch self {
        case .optionTab, .controlTab, .controlOptionTab:
            return UInt32(kVK_Tab)
        case .optionBacktick:
            return UInt32(kVK_ANSI_Grave)
        }
    }

    var carbonModifiers: UInt32 {
        switch self {
        case .optionTab, .optionBacktick:
            return UInt32(optionKey)
        case .controlTab:
            return UInt32(controlKey)
        case .controlOptionTab:
            return UInt32(controlKey | optionKey)
        }
    }

    var eventModifierFlags: NSEvent.ModifierFlags {
        switch self {
        case .optionTab, .optionBacktick:
            return [.option]
        case .controlTab:
            return [.control]
        case .controlOptionTab:
            return [.control, .option]
        }
    }
}

final class SwitcherShortcutStore {
    private let defaults: UserDefaults
    private let key = "SwitcherShortcut"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var selectedShortcut: SwitcherShortcut {
        get {
            guard
                let rawValue = defaults.string(forKey: key),
                let shortcut = SwitcherShortcut(rawValue: rawValue)
            else {
                return .defaultShortcut
            }

            return shortcut
        }
        set {
            defaults.set(newValue.rawValue, forKey: key)
        }
    }
}
