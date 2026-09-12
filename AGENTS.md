Keep this file concise and limited to durable repo-specific rules.

## Source Of Truth

- `CONTEXT.md` for product/domain vocabulary.
- `README.md` for current scope, run instructions, and Accessibility permission notes.
- `docs/architecture.md` for the agent-readable architecture overview.

## Development

- Prefer public macOS APIs, including Accessibility for window discovery and activation.
- For code changes, run `swift build`. Run relevant SwiftPM tests with `scripts/test.sh`.
- For runtime checks, use `scripts/run-app-bundle.sh` with Accessibility permission.
- Quit the old instance first and preserve the signing identity when testing permission persistence.
- Use `Mac Workspace Switcher` in UI, metadata, and docs.
- Preserve the bundle identifier and local checkout path during repository renames unless requested.

## Documentation

- Before new features or material product/architecture changes, align with `CONTEXT.md` and existing docs.
- Update `CONTEXT.md` when product vocabulary changes.
- Keep durable agent docs in `docs/` as Markdown and human companions as HTML.
- Keep existing Markdown/HTML pairs in sync when their content changes. `README.md` remains the concise user-facing entry point.
- Keep temporary plans and explainers in ignored `plans/`; never stage them or move them into `docs/` merely to satisfy the documentation rule.
