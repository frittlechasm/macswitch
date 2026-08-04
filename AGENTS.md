- Keep this file small and concise.
- Update this file only when a new repo-level agent workflow rule is introduced.
- Product name is `Mac Workspace Switcher`; use that branding in UI, metadata, and docs.
- Keep agent-facing documents in `docs/`; do not add new root-level planning or explainer files.

## Source Of Truth

- `CONTEXT.md` for product/domain vocabulary.
- `README.md` for current scope, run instructions, and Accessibility permission notes.
- `docs/architecture.md` for the agent-readable architecture overview.
- `docs/` for future agent-facing Markdown and human-readable HTML docs.

## Rules

- This is a native Swift/AppKit macOS app built with Swift Package Manager.
- Prefer public macOS APIs. Accessibility APIs are expected for window discovery and activation.
- Run checks with `swift build`; use `swift run AppSwitcher` only when runtime behavior needs verification.
- The app requires macOS Accessibility permission for realistic manual testing.
- Never write a commit message or raise a PR without asking first.
- Before implementing a new feature or material product/architecture change, align the plan with `CONTEXT.md` and existing docs.
- When changing product vocabulary, update `CONTEXT.md`.
- Agent-readable docs must be Markdown files. Human-readable docs must be HTML files.
- When changing architecture or durable implementation guidance, update the relevant Markdown source under `docs/` and its matching HTML companion for humans.
- When adding tests in the future, keep them in the SwiftPM test structure and document any new test workflow in `README.md` or `docs/`.
