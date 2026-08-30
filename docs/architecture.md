# Mac Workspace Switcher Architecture

Agent-readable architecture reference for the native Swift/AppKit macOS workspace switcher prototype. Keep `docs/architecture.html` in sync as the human-readable companion.

## Summary

Mac Workspace Switcher is a SwiftPM macOS executable that runs as a menu-bar accessory app, registers a persisted Switcher Shortcut, builds a current-workspace window candidate list from public macOS APIs, renders a SwiftUI-hosted overlay in an AppKit panel, and activates the selected window through Accessibility with an app-level fallback.

## Evidence Summary

- `Package.swift` defines the macOS 13 `AppSwitcher` executable target and an `AppSwitcherTests` test target.
- `scripts/build-app-bundle.sh` wraps the SwiftPM executable in a development `.app` bundle named Mac Workspace Switcher, signs the completed bundle with a stable local identity, and verifies the signature for Accessibility identity testing.
- `scripts/run-app-bundle.sh` builds and opens that bundle from the terminal without running the raw executable identity.
- `Sources/AppSwitcher/main.swift` starts an AppKit accessory application.
- `Sources/AppSwitcher/AppDelegate.swift` composes the core services.
- `Sources/AppSwitcher/SwitcherSessionController.swift` builds and displays a switcher session.
- `Sources/AppSwitcher/WindowInventoryService.swift` enumerates running apps and Accessibility windows, retrying transient AX messaging failures once.
- `Sources/AppSwitcher/PublicWorkspaceFilter.swift` uses Core Graphics visible-window state to approximate the active workspace.
- `Tests/AppSwitcherTests/PublicWorkspaceFilterTests.swift` covers elevated-window exclusion, auxiliary-window candidate theft, and front-to-back ordering.

## Major Modules

- App shell: starts the AppKit accessory app and wires services through `AppDelegate`.
- Development app bundle: builds the SwiftPM executable, creates `.build/debug/Mac Workspace Switcher.app` with bundle metadata, signs it with the configured local identity, and verifies the completed bundle so macOS Accessibility trust survives rebuilds.
- Bundle launcher: opens the generated `.app` bundle from terminal workflows so Accessibility trust is associated with Mac Workspace Switcher rather than the terminal or shell wrapper.
- Status bar: exposes menu actions for showing the switcher, checking Accessibility permission, opening settings, and quitting.
- Hotkey input: registers the selected Switcher Shortcut through Carbon event hotkey APIs.
- Shortcut preferences: persists the selected shortcut in `UserDefaults` and exposes preset selection from the Settings window.
- Session orchestration: checks permission when a session begins and again immediately before activation, snapshots candidates, filters to current-workspace candidates, renders the overlay, records stage latency, advances selection, and activates or cancels.
- Window inventory: uses `NSWorkspace` and Accessibility to build `WindowCandidate` records. A `cannotComplete` AX window-list read is retried once before that app is omitted and a privacy-safe failure is logged.
- Workspace filter: uses `CGWindowListCopyWindowInfo` and the strongest same-process frame overlap as a public-API visibility approximation. Only ordinary layer-zero windows can produce candidates, so elevated windows cannot consume or become candidates.
- Overlay: displays SwiftUI content in a floating borderless AppKit window with a Command-Tab-style system glass material, 130-point app icons, a selected tile inset 2 points inside the icon frame, a shared continuous 31-point corner radius for the selected tile and panel background, consistent 16-point panel padding, a selected-only label, inline duplicate-app window details, and selection state. Label length must not change the fixed app-to-app gap.
- Activation: performs a bounded validation of the selected Accessibility window, then raises/focuses it and activates the owning app. A definitively stale selection performs no activation; indeterminate AX failures preserve the previous activation attempt.
- Diagnostics: writes privacy-safe counts, allowlisted failure stages, numeric error codes, and per-opening overlay latency to the system log without storing history or window content. Stage identifiers, counts, codes, and timing are public and queryable in persisted logs; app names, shortcut names, roles, process identifiers, and unexpected error descriptions remain private.

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
4. A new session checks Accessibility permission, snapshots raw candidates, filters current-workspace candidates, resets selection, shows the overlay, and logs total, inventory, filtering, and presentation latency.
5. Releasing the configured shortcut modifier triggers the flags-changed monitor and selects the current candidate for activation after closing the overlay.
6. The session rechecks Accessibility trust. If permission is no longer granted, it requests the standard macOS prompt and performs no activation.
7. `WindowActivationService` performs a bounded check of the selected Accessibility window role. A definitively stale selection performs no activation. A valid selection, or one whose validation fails for an indeterminate reason such as a transient AX error, continues through the existing activation flow with diagnostics.

## Decisions

- Native Swift/AppKit executable: keeps the prototype close to macOS APIs. The development app-bundle wrapper uses a stable local certificate for realistic Accessibility identity testing across rebuilds, while distribution signing and release packaging are still not defined.
- Current switcher interaction model: manual validation on 2026-06-28 found opening, cycling, cancellation, and activation working as expected for the prototype.
- Public-API workspace approximation: avoids private Space APIs. Manual validation on 2026-06-28 found filtering working as expected, but exact Space membership may still be imperfect across future macOS behavior changes.
- Layer-zero candidate eligibility: only ordinary Core Graphics layer-zero windows are matched and returned. Elevated windows are ignored before AX candidate matching. This removes browser Picture-in-Picture and other floating windows without letting auxiliary windows steal an app's ordinary candidate.
- Transient inventory retry: an AX window-list read that returns `cannotComplete` is retried once with the existing 0.25-second messaging timeout. A second failure, or any non-transient failure, omits that app from the snapshot and records the numeric AX error with private app context.
- Activation-time stale-window handling: the v0.1.0 session keeps its initial candidate snapshot while visible. After the overlay closes, the activation service checks the AX window role with a temporary 0.25-second messaging timeout, then restores the default timeout before activation. A definitively stale element produces a privacy-safe diagnostic with its AX error and no activation attempt. Indeterminate AX failures are logged and preserve the previous activation behavior. Because the window can close after validation, the no-activation outcome is best-effort; live candidate removal is deferred.
- Session-boundary permission handling: Accessibility trust is checked when a session begins and again after the overlay closes but before activation. If permission was removed during the session, the app requests the standard macOS prompt, logs a privacy-safe diagnostic, and performs no activation. Continuous monitoring, custom alerts, and automatic System Settings navigation are deferred. A narrow permission-change race remains after the final check.
- Production overlay latency measurement: every successful overlay opening uses monotonic system uptime to log total request-to-`show()` return latency plus inventory, filtering, and the synchronous overlay `show()` call. The total also includes main-queue dispatch and session orchestration, so the stage values do not necessarily add up to it. The metric does not measure compositor latency. A dedicated default-level unified logger makes only these four numeric measurements public and queryable. The instrumentation is unconditional, retains no history or window content, and must remain enabled through the first production rollout. A performance target will be chosen only after rollout measurements exist.
- Structured reliability diagnostics: a closed stage allowlist records actionable inventory, permission, activation, and hotkey failures at the persistent error level. Stage identifiers and optional numeric AX/OSStatus codes are public; descriptive context is explicitly private. Candidate counts are public at the default persistent level. Non-actionable AX timeout-configuration warnings and ordinary lifecycle/status messages retain the existing private diagnostic path to avoid noisy production failure logs. No logs are uploaded or stored separately by the app.
- Preset-based Switcher Shortcut configuration: keeps hotkey changes simple and avoids Command-Tab interception while the core product behavior is still being validated.
- Service-per-responsibility composition: keeps the prototype simple. Dependency injection remains manual, while the workspace filter exposes a snapshot-based internal seam for deterministic tests.

## Verification

- Run `swift build` for the production target.
- Run `scripts/test.sh` for SwiftPM tests. It uses the toolchain's native test runner under full Xcode and supplies the selected Command Line Tools framework paths when `xctest` is unavailable.

## Gaps and Risks

- Space membership is approximate by API design; manually validated behavior is working as expected, but future macOS, fullscreen, Stage Manager, and multi-display changes remain regression risks.
- Automated coverage currently protects workspace filtering only; inventory retry, session transitions, and activation boundaries remain untested.
- Full Command-Tab-style event suppression is not implemented; the current model uses the configured Switcher Shortcut.
- Switcher Shortcut choices are preset-based rather than free-form key capture.
- The overlay currently caps visible candidates at seven and keeps the selection centered as the visible slice changes, but it has no overflow count or scrollbar affordance.
- There is no signed/notarized release app bundle, entitlement review, hardened runtime configuration, or distribution packaging path yet.
- Local self-signed development certificates are machine-specific. Other development machines must create their own identity or set `CODESIGN_IDENTITY` to an available Apple Development identity.

## Recommendations

- Expand SwiftPM coverage to inventory retry, session transitions, and activation boundaries.
- Add free-form shortcut capture only if preset shortcuts are too limiting in manual use.
- Replace local development signing with a Developer ID or other distribution signing and notarization path before public distribution.
- Keep Spaces, fullscreen apps, Stage Manager, multi-display setups, Chrome and Helium Picture-in-Picture, Terminal, and Finder in the manual regression matrix.
- Add overlay overflow handling for more than seven candidates.
