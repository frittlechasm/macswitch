# App Switcher Architecture

Agent-readable architecture reference for the native Swift/AppKit macOS app switcher prototype. Keep `docs/architecture.html` in sync as the human-readable companion.

## Summary

App Switcher is a SwiftPM macOS executable that runs as a menu-bar accessory app, registers an `Option-Tab` shortcut, builds a current-workspace window candidate list from public macOS APIs, renders an AppKit overlay, and activates the selected window through Accessibility with an app-level fallback.

## Evidence Summary

- `Package.swift` defines one executable target, `AppSwitcher`, targeting macOS 13.
- `Sources/AppSwitcher/main.swift` starts an AppKit accessory application.
- `Sources/AppSwitcher/AppDelegate.swift` composes the core services.
- `Sources/AppSwitcher/SwitcherSessionController.swift` builds and displays a switcher session.
- `Sources/AppSwitcher/WindowInventoryService.swift` enumerates running apps and Accessibility windows.
- `Sources/AppSwitcher/PublicWorkspaceFilter.swift` uses Core Graphics visible-window state to approximate the active workspace.

## Major Modules

- App shell: starts the AppKit accessory app and wires services through `AppDelegate`.
- Status bar: exposes menu actions for showing the switcher, checking Accessibility permission, opening settings, and quitting.
- Hotkey input: registers `Option-Tab` through Carbon event hotkey APIs.
- Session orchestration: checks permission, snapshots candidates, filters to current-workspace candidates, renders the overlay, advances selection, and activates or cancels.
- Window inventory: uses `NSWorkspace` and Accessibility to build `WindowCandidate` records.
- Workspace filter: uses `CGWindowListCopyWindowInfo` and screen intersection as a public-API visibility approximation.
- Overlay: displays a floating borderless AppKit window with app icons, titles, and selection state.
- Activation: raises/focuses the Accessibility window and activates the owning app.

## Data Model

`WindowCandidate` is the current domain record. It stores process id, app name, bundle id, title, frame, app icon, and the Accessibility window reference.

There is no persistent storage, database, cache, or migration layer in the current codebase.

## External Integrations

- AppKit for app lifecycle, menu-bar UI, overlay windows, drawing, screens, and application activation.
- Carbon for global hotkey registration.
- ApplicationServices Accessibility for permission checks, window discovery, and window focus.
- Core Graphics for visible window-server snapshots used by the workspace filter.

## Key Flow: Switch Window

1. Carbon emits the registered hotkey callback and invokes the hotkey monitor closure.
2. `AppDelegate` forwards the event to `SwitcherSessionController.handleSwitcherShortcut()`.
3. The session controller advances selection if the overlay is visible; otherwise it starts a new session.
4. A new session checks Accessibility permission, snapshots raw candidates, filters current-workspace candidates, resets selection, and shows the overlay.
5. Releasing Option triggers the flags-changed monitor and activates the selected candidate.
6. `WindowActivationService` raises/focuses the Accessibility window and activates the owning process.

## Decisions

- Native Swift/AppKit executable: keeps the prototype close to macOS APIs, but app-bundle packaging is not yet defined.
- Public-API workspace approximation: avoids private Space APIs, but exact Space membership may be imperfect.
- Service-per-responsibility composition: keeps the prototype simple, but dependency injection is manual and not yet test-oriented.

## Gaps and Risks

- Space membership is approximate across Spaces, fullscreen apps, Stage Manager, and multiple displays.
- There is no automated test target yet.
- The hotkey is hard-coded to `Option-Tab`.
- The overlay currently caps visible candidates at seven and has no overflow affordance.
- There is no signed/notarized app bundle, entitlement review, hardened runtime configuration, or release packaging path yet.

## Recommendations

- Add a SwiftPM test target for candidate filtering, session transitions, and activation boundaries.
- Introduce a configurable hotkey model before exploring Command-Tab replacement.
- Build an app-bundle packaging path with signing and notarization before public distribution.
- Record manual test results for Spaces, fullscreen apps, Stage Manager, multi-display setups, Chrome, Terminal, and Finder.
- Add overlay overflow handling for more than seven candidates.
