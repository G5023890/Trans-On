# Handoff: TransOn / Trans-On

## Current state
- Project type: macOS Swift app (`AppKit`) built as an Xcode project with an embedded WidgetKit / Control Center extension.
- Workspace path: `/Users/grigorymordokhovich/Documents/Develop/Selected text`.
- Git: configured.
- Branch: `main`.
- Remote: `origin https://github.com/G5023890/Trans-On.git`.

## Implemented functionality
- Global hotkey capture of selected text from the active app.
- Clipboard-safe copy flow:
  - sends synthetic `Cmd+C`,
  - reads selection from pasteboard,
  - restores previous clipboard contents.
- Floating overlay with semi-transparent dark background.
- Overlay closes with `Esc`.
- Menu bar app with settings window.
- Settings:
  - hotkey letter (`A-Z`),
  - modifiers (`Command`, `Shift`, `Option`, `Control`),
  - font size,
  - launch at login.
- Translation provider selection:
  - `Google Web (gtx)`,
  - `Google Cloud API`.
- Google Cloud API key input in menu (`Google Cloud API key…`), stored in macOS Keychain.

## Translation reliability behavior
- Text is split into semantic paragraphs.
- Paragraphs are grouped into chunks with limits:
  - up to `~1800` chars per chunk,
  - up to `6` paragraphs per batch.
- Batches are translated sequentially with delay (`~300-500ms`) between chunks.
- Retries with backoff + jitter (`maxRetries = 3`).
- On persistent batch failure, falls back to paragraph-by-paragraph translation.
- Provider fallback chain:
  - `Google Web (gtx)` -> `Google Cloud API` (if key exists) -> Google mobile web fallback.
  - `Google Cloud API` -> `Google Web (gtx)` -> Google mobile web fallback.

## Build and install
- Script: `scripts/build_and_install_app.sh`.
- App name: `Trans-On.app`.
- Output app: `dist/Trans-On.app`.
- Installed to: `/Applications/Trans-On.app`.
- Main bundle identifier: `com.grigorym.TransOn`.
- Control extension bundle identifier: `com.grigorym.TransOn.Controls`.
- App Group: `group.com.grigorym.TransOn.shared`.
- Script regenerates `TransOn.xcodeproj`, builds via `xcodebuild`, embeds the control extension, and preserves stable signing strategy to avoid repeated Accessibility trust resets after rebuilds (when valid signing identity is available).
- Uses `AppIcon.icns` from the project.

## Important files
- `Sources/TransOn`: main app logic, translation service, menu/actions, settings.
- `scripts/build_and_install_app.sh`: build, package, sign, and install flow.
- `README.md`: user-facing usage/build/permission documentation.
- `QUESTIONS_AND_ANSWERS.md`: notes about Google Translate API usage/cost model.

## Known risks / limitations
- `Google Web (gtx)` is unofficial and can be unstable or rate-limited.
- No automated test suite yet (manual verification only).

## Suggested next steps
1. Add lightweight smoke tests for translation pipeline and provider fallbacks.
2. Externalize user-facing strings for easier localization (menu is currently mixed language).
3. Add structured diagnostics/log export for translation failures.
