# Mac Workspace Switcher

Native Swift/AppKit macOS workspace switcher prototype.

## Current Scope

- Uses public macOS APIs only.
- Uses Accessibility APIs for window discovery and activation.
- Shows a Command-Tab-style glass overlay with large app icons and a selected-only label with inline window details when one app has multiple candidates.
- Filters to visible, non-minimized, ordinary windows in the current macOS workspace context as far as public APIs allow. Elevated floating windows such as browser Picture-in-Picture are excluded.
- Starts with `Option-Tab` by default. Check Settings to set your own shortcut.

## Run

```sh
scripts/run-app-bundle.sh
```

The app requires Accessibility permission to inspect and focus windows. Use the menu-bar item or the macOS prompt to grant permission, then press the configured Switcher Shortcut. The default is `Option-Tab`. If permission is removed while the switcher is visible, the session closes without activating a window and requests permission again.

## License

MIT
