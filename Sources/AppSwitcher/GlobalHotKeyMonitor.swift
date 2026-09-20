import Carbon
import CoreGraphics
import Foundation

enum GlobalHotKeyError: Error {
    case installHandlerFailed(OSStatus)
    case registerHotKeyFailed(OSStatus)
    case createEventTapFailed
}

final class GlobalHotKeyMonitor {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private var eventTap: CFMachPort?
    private var eventTapSource: CFRunLoopSource?
    private var commandTabIsPressed = false
    private let onPressed: (_ selectionOffset: Int) -> Void
    private(set) var shortcut: SwitcherShortcut?

    init(onPressed: @escaping (_ selectionOffset: Int) -> Void) {
        self.onPressed = onPressed
    }

    deinit {
        stop()
    }

    /// Registers ordinary shortcuts through Carbon and intercepts Command-Tab through a public CGEvent tap.
    func start(shortcut: SwitcherShortcut) throws {
        stop()

        if shortcut == .commandTab {
            try startCommandTabEventTap()
            self.shortcut = shortcut
            return
        }

        try startCarbonHotKey(shortcut)
        self.shortcut = shortcut
    }

    private func startCarbonHotKey(_ shortcut: SwitcherShortcut) throws {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let handlerStatus = InstallEventHandler(
            GetEventDispatcherTarget(),
            { _, _, userData in
                guard let userData else {
                    return noErr
                }

                // Carbon stores callback context as an opaque pointer, so bridge it back to this monitor.
                let monitor = Unmanaged<GlobalHotKeyMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                monitor.onPressed(1)
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &handlerRef
        )

        guard handlerStatus == noErr else {
            throw GlobalHotKeyError.installHandlerFailed(handlerStatus)
        }

        let hotKeyID = EventHotKeyID(signature: fourCharacterCode("ASWT"), id: 1)
        let registerStatus = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetEventDispatcherTarget(),
            0,
            &hotKeyRef
        )

        guard registerStatus == noErr else {
            if let handlerRef {
                RemoveEventHandler(handlerRef)
                self.handlerRef = nil
            }

            throw GlobalHotKeyError.registerHotKeyFailed(registerStatus)
        }
    }

    private func startCommandTabEventTap() throws {
        let eventMask = [CGEventType.keyDown, .keyUp]
            .reduce(CGEventMask(0)) { $0 | (CGEventMask(1) << $1.rawValue) }

        guard let eventTap = CGEvent.tapCreate(
            tap: .cghidEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: commandTabEventTapCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            throw GlobalHotKeyError.createEventTapFailed
        }

        let eventTapSource = CFMachPortCreateRunLoopSource(nil, eventTap, 0)
        self.eventTap = eventTap
        self.eventTapSource = eventTapSource

        CFRunLoopAddSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    fileprivate func handleCommandTabEvent(type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        if type == .keyUp, keyCode == CGKeyCode(kVK_Tab), commandTabIsPressed {
            commandTabIsPressed = false
            return nil
        }

        guard CommandTabEventFilter.shouldIntercept(
            type: type,
            keyCode: keyCode,
            flags: event.flags
        ) else {
            return Unmanaged.passUnretained(event)
        }

        if type == .keyDown {
            commandTabIsPressed = true
            onPressed(event.flags.contains(.maskShift) ? -1 : 1)
        }

        // Swallow both halves of the chord so the Dock's built-in app switcher never sees it.
        return nil
    }

    /// Removes the active Carbon registration or Core Graphics event tap.
    func stop() {
        if let eventTapSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), eventTapSource, .commonModes)
            self.eventTapSource = nil
        }

        if let eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            CFMachPortInvalidate(eventTap)
            self.eventTap = nil
        }

        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }

        shortcut = nil
        commandTabIsPressed = false
    }
}

enum CommandTabEventFilter {
    static func shouldIntercept(type: CGEventType, keyCode: CGKeyCode, flags: CGEventFlags) -> Bool {
        guard type == .keyDown || type == .keyUp, keyCode == CGKeyCode(kVK_Tab) else {
            return false
        }

        guard flags.contains(.maskCommand) else {
            return false
        }

        return !flags.contains(.maskAlternate) && !flags.contains(.maskControl)
    }
}

private let commandTabEventTapCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else {
        return Unmanaged.passUnretained(event)
    }

    let monitor = Unmanaged<GlobalHotKeyMonitor>
        .fromOpaque(userInfo)
        .takeUnretainedValue()

    return monitor.handleCommandTabEvent(type: type, event: event)
}

/// Converts a four-character string into the OSType signature Carbon expects.
private func fourCharacterCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
