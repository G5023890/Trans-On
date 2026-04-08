# Trans-On

Trans-On is a macOS menu bar app that captures selected text and translates it to Russian.

Current version: `1.0.1`

## What the app does

- Uses a global hotkey to copy selected text from the active app.
- If the text is not already Russian, tries to translate it to Russian.
- Shows the result in a floating semi-transparent overlay window.
- Closes the overlay with `Esc`.

## Hotkey

- Default: `Shift + Command + L`.
- Configurable in the menu bar: `Menu bar icon -> Settings…`.
- Settings allow you to change:
  - key (`A-Z`)
  - modifiers (`Command`, `Shift`, `Option`, `Control`)
  - font size
  - launch at login

## Translation providers

Provider switch is available in:

- `Menu bar icon -> Translation Method -> Google Web (gtx)` (unofficial endpoint)
- `Menu bar icon -> Translation Method -> Google Cloud API` (official API)

## Recent changes

- Added a `Diagnostics` tab that stores the latest Google Cloud API failure reason and timestamp.
- Google Cloud API failures now surface in the Translation settings instead of looking like a successful `Google Web` translation.
- Removed the offline/Bergamot translation path; the app now keeps only the two online translation providers.

## Versioning

- Marketing version: `1.0.1`
- Build number: `2`
- Version values are kept in sync across the Xcode project, app plist files, and the build script defaults.

## Project status

- Translation is online-only.
- Current providers are `Google Web (gtx)` and `Google Cloud API`.
- `Google Web (gtx)` remains the fallback path when cloud translation fails or no API key is available.

### Google Cloud API key

- Menu path: `Menu bar icon -> Translation Method -> Google Cloud API key…`
- Stored securely in macOS Keychain.
- You can also use environment variables:

```bash
export GOOGLE_CLOUD_TRANSLATE_API_KEY="YOUR_API_KEY"
# or
export GOOGLE_API_KEY="YOUR_API_KEY"
```

## Run in development mode

```bash
open TransOn.xcodeproj
```

For local installable builds with the embedded Control Center extension, use the build script below. The Swift package manifest remains in the repo for source organization, but the app is built as an Xcode project.

## Build and install

```bash
./scripts/build_and_install_app.sh
```

The script generates the Xcode project, builds the app and embedded Control Center extension, signs them, and installs `/Applications/Trans-On.app`.

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

## License

This project is licensed under the Apache License 2.0 (`Apache-2.0`).
See `/Users/grigorymordokhovich/Documents/Develop/Selected text/LICENSE`.
