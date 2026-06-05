import Carbon
import Foundation

enum GlobalHotKeyError: Error {
    case installHandlerFailed(OSStatus)
    case registerHotKeyFailed(OSStatus)
}

final class GlobalHotKeyMonitor {
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?
    private let onPressed: () -> Void

    init(onPressed: @escaping () -> Void) {
        self.onPressed = onPressed
    }

    deinit {
        stop()
    }

    func start() throws {
        stop()

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

                let monitor = Unmanaged<GlobalHotKeyMonitor>
                    .fromOpaque(userData)
                    .takeUnretainedValue()

                monitor.onPressed()
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
            UInt32(kVK_Tab),
            UInt32(optionKey),
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

    func stop() {
        if let hotKeyRef {
            UnregisterEventHotKey(hotKeyRef)
            self.hotKeyRef = nil
        }

        if let handlerRef {
            RemoveEventHandler(handlerRef)
            self.handlerRef = nil
        }
    }
}

private func fourCharacterCode(_ string: String) -> OSType {
    string.utf8.reduce(0) { result, character in
        (result << 8) + OSType(character)
    }
}
