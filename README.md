# Trans-On

Trans-On is a macOS menu bar app that captures selected text and translates it to Russian.

## What the app does

- Uses a global hotkey to copy selected text from the active app.
- If the text is not already Russian, tries to translate it to Russian.
- Shows the result in a floating semi-transparent overlay window.
- Closes the overlay with `Esc`.

## Hotkey

- Default: `Shift + Command + L`.
- Configurable in the menu bar: `⌘Я -> Настройки…`.
- Settings allow you to change:
  - key (`A-Z`)
  - modifiers (`Command`, `Shift`, `Option`, `Control`)
  - font size
  - launch at login

## Translation providers

Provider switch is available in:

- `⌘Я -> Способ перевода -> Google Web (gtx)` (unofficial endpoint)
- `⌘Я -> Способ перевода -> Google Cloud API` (official API)
- `⌘Я -> Способ перевода -> Argos (offline)` (local translation via installed Argos CLI)

### Google Cloud API key

- Menu path: `⌘Я -> Способ перевода -> Google Cloud API key…`
- Stored securely in macOS Keychain.
- You can also use environment variables:

```bash
export GOOGLE_CLOUD_TRANSLATE_API_KEY="YOUR_API_KEY"
# or
export GOOGLE_API_KEY="YOUR_API_KEY"
```

### Argos package update/check

- Menu path: `⌘Я -> Способ перевода -> Проверить/обновить пакеты Argos…`
- Updates Argos package index and checks updates for installed packages.
- Checks whether a direct `he->ru` package is available.
- If direct `he->ru` appears in the index, the app downloads and installs it automatically.
- The `he->ru` availability state is saved in app settings.

## Run in development mode

```bash
swift run
```

## Build and install

```bash
./scripts/build_and_install_app.sh
```

The script builds and installs `/Applications/Trans-On.app`.

Script behavior:

- Uses a stable `CFBundleIdentifier` and `Apple Development` signing identity to preserve Accessibility trust across rebuilds.
- Auto-detects `AppIcon.icns` in the project.
- Falls back to ad-hoc signing only when no `Apple Development` certificate is available.

## macOS permissions

For reliable `Cmd+C` emulation and selected-text capture from other apps:

- `System Settings -> Privacy & Security -> Accessibility`: add your terminal/app.
- If needed, also add your terminal/app to `Input Monitoring`.

If hotkey capture or text selection capture does not work, check these permissions first.

## Limitations

- `Google Web (gtx)` uses an unofficial endpoint and is not suitable for production.
- `Google Cloud API` requires a valid API key and enabled billing in Google Cloud.
- `Argos (offline)` requires installed CLI and language packages in `~/Library/Application Support/ArgosTranslate/packages`.
