# Mac Workspace Switcher Architecture

Agent-readable architecture reference for the native Swift/AppKit macOS workspace switcher prototype. Keep `docs/architecture.html` in sync as the human-readable companion.

## Summary

Mac Workspace Switcher is a SwiftPM macOS executable that runs as a menu-bar accessory app, registers a persisted Switcher Shortcut, builds a current-workspace window candidate list from public macOS APIs, renders a SwiftUI-hosted overlay in an AppKit panel, and activates the selected window through Accessibility with an app-level fallback.

## Evidence Summary

- `Package.swift` defines one executable target, `AppSwitcher`, targeting macOS 13.
- `scripts/build-app-bundle.sh` wraps the SwiftPM executable in a development `.app` bundle named Mac Workspace Switcher for Accessibility identity testing.
- `scripts/run-app-bundle.sh` builds and opens that bundle from the terminal without running the raw executable identity.
- `Sources/AppSwitcher/main.swift` starts an AppKit accessory application.
- `Sources/AppSwitcher/AppDelegate.swift` composes the core services.
- `Sources/AppSwitcher/SwitcherSessionController.swift` builds and displays a switcher session.
- `Sources/AppSwitcher/WindowInventoryService.swift` enumerates running apps and Accessibility windows.
- `Sources/AppSwitcher/PublicWorkspaceFilter.swift` uses Core Graphics visible-window state to approximate the active workspace.

## Major Modules

- App shell: starts the AppKit accessory app and wires services through `AppDelegate`.
- Development app bundle: builds the SwiftPM executable and creates `.build/debug/Mac Workspace Switcher.app` with bundle metadata for macOS Accessibility Settings.
- Bundle launcher: opens the generated `.app` bundle from terminal workflows so Accessibility trust is associated with Mac Workspace Switcher rather than the terminal or shell wrapper.
- Status bar: exposes menu actions for showing the switcher, checking Accessibility permission, opening settings, and quitting.
- Hotkey input: registers the selected Switcher Shortcut through Carbon event hotkey APIs.
- Shortcut preferences: persists the selected shortcut in `UserDefaults` and exposes preset selection from the Settings window.
- Session orchestration: checks permission, snapshots candidates, filters to current-workspace candidates, renders the overlay, advances selection, and activates or cancels.
- Window inventory: uses `NSWorkspace` and Accessibility to build `WindowCandidate` records.
- Workspace filter: uses `CGWindowListCopyWindowInfo` and screen intersection as a public-API visibility approximation.
- Overlay: displays SwiftUI content in a floating borderless AppKit window with a Command-Tab-style system glass material, 130-point app icons, a selected tile inset 2 points inside the icon frame, a shared continuous 31-point corner radius for the selected tile and panel background, consistent 16-point panel padding, a selected-only label, inline duplicate-app window details, and selection state. Label length must not change the fixed app-to-app gap.
- Activation: raises/focuses the Accessibility window and activates the owning app.

## Data Model

`WindowCandidate` is the current domain record. It stores process id, app name, bundle id, title, frame, app icon, and the Accessibility window reference.

The selected Switcher Shortcut is stored in `UserDefaults`. There is no database, cache, or migration layer in the current codebase.

## External Integrations

- AppKit for app lifecycle, menu-bar UI, overlay windows, system glass material, screens, and application activation.
- SwiftUI for the overlay content layout, app icons, selected label, and selection ring.
- Carbon for global hotkey registration.
- ApplicationServices Accessibility for permission checks, window discovery, and window focus.
- Core Graphics for visible window-server snapshots used by the workspace filter.

## Key Flow: Switch Window

1. Carbon emits the registered hotkey callback and invokes the hotkey monitor closure.
2. `AppDelegate` forwards the event to `SwitcherSessionController.handleSwitcherShortcut()`.
3. The session controller advances selection if the overlay is visible; otherwise it starts a new session.
4. A new session checks Accessibility permission, snapshots raw candidates, filters current-workspace candidates, resets selection, and shows the overlay.
5. Releasing the configured shortcut modifier triggers the flags-changed monitor and activates the selected candidate.
6. `WindowActivationService` raises/focuses the Accessibility window and activates the owning process.

## Decisions

- Native Swift/AppKit executable: keeps the prototype close to macOS APIs. A development app-bundle wrapper now exists for realistic Accessibility identity testing, while signed release packaging is still not defined.
- Current switcher interaction model: manual validation on 2026-06-28 found opening, cycling, cancellation, and activation working as expected for the prototype.
- Public-API workspace approximation: avoids private Space APIs. Manual validation on 2026-06-28 found filtering working as expected, but exact Space membership may still be imperfect across future macOS behavior changes.
- Preset-based Switcher Shortcut configuration: keeps hotkey changes simple and avoids Command-Tab interception while the core product behavior is still being validated.
- Service-per-responsibility composition: keeps the prototype simple, but dependency injection is manual and not yet test-oriented.

## Gaps and Risks

- Space membership is approximate by API design; manually validated behavior is working as expected, but future macOS, fullscreen, Stage Manager, and multi-display changes remain regression risks.
- There is no automated test target yet.
- Full Command-Tab-style event suppression is not implemented; the current model uses the configured Switcher Shortcut.
- Switcher Shortcut choices are preset-based rather than free-form key capture.
- The overlay currently caps visible candidates at seven and keeps the selection centered as the visible slice changes, but it has no overflow count or scrollbar affordance.
- There is no signed/notarized release app bundle, entitlement review, hardened runtime configuration, or distribution packaging path yet.

## Recommendations

- Add a SwiftPM test target for candidate filtering, session transitions, and activation boundaries.
- Add free-form shortcut capture only if preset shortcuts are too limiting in manual use.
- Build an app-bundle packaging path with signing and notarization before public distribution.
- Keep Spaces, fullscreen apps, Stage Manager, multi-display setups, Chrome, Terminal, and Finder in the manual regression matrix.
- Add overlay overflow handling for more than seven candidates.
