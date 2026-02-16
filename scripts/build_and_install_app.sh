#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

APP_DISPLAY_NAME="Trans-On"
EXECUTABLE_NAME="SelectedTextOverlay"
BUNDLE_ID="com.grigorym.SelectedTextOverlay"
APP_DIR="dist/${APP_DISPLAY_NAME}.app"
INSTALL_DIR="/Applications/${APP_DISPLAY_NAME}.app"
LEGACY_INSTALL_DIR="/Applications/SelectedTextOverlay.app"
BIN_PATH=".build/arm64-apple-macosx/release/${EXECUTABLE_NAME}"
ICON_SOURCE="/Users/grigorymordokhovich/Library/Mobile Documents/com~apple~CloudDocs/Downloads/Assets/AppIcon.icns"
SIGN_IDENTITY='Apple Development: Grigorii Mordokhovich (53YUZ2U35Z)'

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Icon file not found: $ICON_SOURCE" >&2
  exit 1
fi

swift build -c release

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/${EXECUTABLE_NAME}"
chmod +x "$APP_DIR/Contents/MacOS/${EXECUTABLE_NAME}"
/usr/bin/ditto --norsrc "$ICON_SOURCE" "$APP_DIR/Contents/Resources/AppIcon.icns"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>${APP_DISPLAY_NAME}</string>
  <key>CFBundleExecutable</key>
  <string>${EXECUTABLE_NAME}</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>${BUNDLE_ID}</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>${APP_DISPLAY_NAME}</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

xattr -cr "$APP_DIR" || true
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$APP_DIR"
codesign --verify --deep --strict "$APP_DIR"

rm -rf "$INSTALL_DIR"
/usr/bin/ditto --norsrc "$APP_DIR" "$INSTALL_DIR"
rm -rf "$LEGACY_INSTALL_DIR"

xattr -cr "$INSTALL_DIR" || true
codesign --force --deep --options runtime --sign "$SIGN_IDENTITY" "$INSTALL_DIR"
codesign --verify --deep --strict "$INSTALL_DIR"

echo "Built: $APP_DIR"
echo "Installed: $INSTALL_DIR"
