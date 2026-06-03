# App Switcher

Native Swift/AppKit macOS app switcher prototype.

## Current Scope

- Uses public macOS APIs only.
- Uses Accessibility APIs for window discovery and activation.
- Shows app icons plus window titles.
- Filters to visible, non-minimized windows in the current macOS workspace context as far as public APIs allow.
- Starts with `Option-Tab`; Command-Tab replacement is a future input-controller option.

## Run

```sh
swift run AppSwitcher
```

This starts a menu-bar app and keeps the terminal process running inside the AppKit event loop. That is expected. Stop it with `Ctrl-C` from the same terminal, or quit from the menu-bar icon.

To run it without occupying the terminal after it is built:

```sh
swift build
.build/debug/AppSwitcher >/tmp/app-switcher.log 2>&1 &
```

The app requires Accessibility permission to inspect and focus windows. Use the menu-bar item or the macOS prompt to grant permission, then press `Option-Tab`.
