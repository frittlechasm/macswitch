# Carbon Hot Keys and Core Graphics Event Taps

[Open the visual HTML companion](https://notes.pslop.dev/83a2396a-5002-4769-8839-aa86bf22e18b).

Mac Workspace Switcher uses two public macOS input APIs for different jobs. Ordinary shortcuts use Carbon's `RegisterEventHotKey`. Command-Tab uses an active Core Graphics event tap because macOS already owns that chord.

## Recommendation

Keep the ordinary shortcuts on Carbon. Use the Core Graphics event tap only for Command-Tab and other future shortcuts that cannot work through normal registration.

Moving every shortcut to the event tap would make the code path uniform, but it would also make every shortcut depend on a low-level input filter. That adds event filtering, run-loop lifecycle, timeout recovery, key-state tracking, and event suppression without improving ordinary shortcuts.

Command-Tab is marked experimental in Settings while physical-key validation is incomplete. The picker labels the option `Command-Tab (Experimental)`, and the active status explains why. The UI uses plain text instead of a warning dialog or decorative badge.

Settings copy:

> Active shortcut: Command-Tab (Experimental)<br>
> Uses a low-level event tap and may vary by macOS version.

## What Carbon means here

Carbon is an older family of C APIs created during the transition from classic Mac OS to Mac OS X. Much of Carbon is legacy, but its HIToolbox global hot-key API remains present in the current macOS SDK without a deprecation annotation.

`RegisterEventHotKey` asks macOS to watch one virtual key code and modifier combination. When the combination matches, macOS sends the app a hot-key event. The app does not inspect every keyboard event and does not decide which events continue through the input system.

For Mac Workspace Switcher, Option-Tab, Control-Tab, Control-Option-Tab, and Option-Backtick fit this model well.

## What Core Graphics event taps are

Quartz Event Services is part of Core Graphics. It exposes low-level keyboard and pointing-device events as they move through macOS. An event tap can be passive, which only observes events, or active, which can pass, modify, or delete an event.

The Command-Tab implementation creates an active tap at the HID event location, inserts it at the head of the tap list, and requests key-down and key-up events. The callback:

1. Passes unrelated events through unchanged.
2. Detects Command-Tab and Command-Shift-Tab.
3. Starts or advances Mac Workspace Switcher.
4. Returns no event for the matching chord, which asks macOS to delete it from the remaining event stream.
5. Re-enables the tap if macOS disables it after a timeout or user-input condition.

This path requires Accessibility permission to receive keyboard events. Apple's current documentation and SDK headers also describe stricter placement rules for HID-level taps, while the signed development app successfully creates the tap as an Accessibility-trusted standard user. That documentation/runtime mismatch is another reason to keep the feature experimental until the physical behavior is validated across supported macOS versions.

## How the two paths differ

| Concern | Carbon hot-key registration | Core Graphics event tap |
| --- | --- | --- |
| Abstraction | Register one chord | Filter low-level input events |
| Matching | macOS matches the chord | Our callback matches key codes and flags |
| Event suppression | Not controlled by our app | Active callback can delete a matching event |
| Reserved shortcuts | May lose to macOS handling | Can attempt interception before later consumers |
| Permissions | Registration itself does not require Accessibility | Keyboard event access requires Accessibility trust |
| Runtime work | Callback only for registered hot-key events | Callback sees every requested key-down and key-up |
| Failure handling | Registration status and fallback | Creation failure, timeout recovery, state cleanup, and fallback |
| Best use here | Ordinary configurable shortcuts | Command-Tab replacement |

## Why not move everything

The event tap provides control that ordinary shortcuts do not need. Keeping the split design has a smaller input-capture surface, fewer failure modes, and clearer intent. It also leaves Option-Tab and the other fallback shortcuts available if macOS changes event-tap behavior.

A full migration becomes worthwhile only if the product requires features that Carbon cannot express, such as consistent press/release handling for every shortcut, arbitrary chord recording with low-level filtering, or suppression of several system-reserved shortcuts.

## Experimental exit criteria

Remove the experimental label after verifying all of the following on the supported macOS range:

- Command-Tab opens only Mac Workspace Switcher, with no native-switcher flash.
- Repeated Tab advances and Command-Shift-Tab reverses.
- Releasing Command activates the selected window.
- Sleep/wake, fast user switching, and tap-disable recovery preserve the shortcut.
- Revoking and restoring Accessibility permission produces a clear fallback and recovery path.
- Other Command-based shortcuts and secure-input scenarios remain unaffected.

## Sources

- Project implementation: [`GlobalHotKeyMonitor.swift`](../Sources/AppSwitcher/GlobalHotKeyMonitor.swift)
- Current macOS SDK: `Carbon.framework/.../HIToolbox.framework/.../CarbonEvents.h`
- [Apple: Quartz Event Services](https://developer.apple.com/documentation/coregraphics/quartz-event-services)
- [Apple: CGEventTapCreate](https://developer.apple.com/documentation/coregraphics/cgevent/tapcreate%28tap%3Aplace%3Aoptions%3Aeventsofinterest%3Acallback%3Auserinfo%3A%29)
- [Apple: CGEventTapCallBack](https://developer.apple.com/documentation/coregraphics/cgeventtapcallback)
