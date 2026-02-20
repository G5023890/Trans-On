# Handoff: SelectedTextOverlay / Trans-On

## Current state
- Project type: macOS Swift app (`AppKit`) built with Swift Package Manager.
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
  - `Google Cloud API`,
  - `Argos (offline)`.
- Google Cloud API key input in menu (`Google Cloud API key…`), stored in macOS Keychain.
- Argos package maintenance action in menu:
  - `Check/Update Argos packages…`,
  - refreshes Argos index,
  - updates installed Argos packages when newer versions are available,
  - checks direct `he->ru` availability and auto-installs it if available,
  - stores `he->ru` status in app settings.

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
  - `Argos (offline)` -> `Google Web (gtx)` chain.

## Build and install
- Script: `scripts/build_and_install_app.sh`.
- App name: `Trans-On.app`.
- Output app: `dist/Trans-On.app`.
- Installed to: `/Applications/Trans-On.app`.
- Script preserves stable bundle identifier/signing strategy to avoid repeated Accessibility trust resets after rebuilds (when valid signing identity is available).
- Uses `AppIcon.icns` from the project.

## Important files
- `Sources/SelectedTextOverlay/main.swift`: main app logic, translation service, menu/actions, settings.
- `scripts/build_and_install_app.sh`: build, package, sign, and install flow.
- `README.md`: user-facing usage/build/permission documentation.
- `QUESTIONS_AND_ANSWERS.md`: notes about Google Translate API usage/cost model.

## Known risks / limitations
- `Google Web (gtx)` is unofficial and can be unstable or rate-limited.
- Argos direct `he->ru` package may be absent in the public index; when absent, translation is done via available paths.
- No automated test suite yet (manual verification only).

## Suggested next steps
1. Add lightweight smoke tests for translation pipeline and provider fallbacks.
2. Externalize user-facing strings for easier localization (menu is currently mixed language).
3. Add structured diagnostics/log export for translation failures.
