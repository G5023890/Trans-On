#!/usr/bin/env bash
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$PROJECT_DIR"

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode-beta.app/Contents/Developer}"

APP_DISPLAY_NAME="${APP_DISPLAY_NAME:-Trans-On}"
BUNDLE_ID="${BUNDLE_ID:-com.grigorym.TransOn}"
APP_VERSION="${APP_VERSION:-1.01}"
APP_BUILD="${APP_BUILD:-1}"
APP_DIR="${APP_DIR:-dist/${APP_DISPLAY_NAME}.app}"
INSTALL_DIR="${INSTALL_DIR:-/Applications/${APP_DISPLAY_NAME}.app}"
LEGACY_INSTALL_DIR="${LEGACY_INSTALL_DIR:-/Applications/SelectedTextOverlay.app}"
XCODEPROJ_PATH="${XCODEPROJ_PATH:-TransOn.xcodeproj}"
SCHEME="${SCHEME:-TransOn}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-$PROJECT_DIR/.xcodebuild/DerivedDataReleaseUnsigned}"
ICON_SOURCE="${ICON_SOURCE:-}"
MENUBAR_ICON_SOURCE="${MENUBAR_ICON_SOURCE:-}"
MENUBAR_CONTROL_ICON_SOURCE="${MENUBAR_CONTROL_ICON_SOURCE:-}"
SKIP_SIGN="${SKIP_SIGN:-0}"
SIGN_IDENTITY="${SIGN_IDENTITY:-}"
RESOLVED_SIGN_IDENTITY=""
STAGING_ROOT=""
APP_STAGE=""

log() {
  echo "[build] $*"
}

pick_icon_source() {
  if [[ -n "$ICON_SOURCE" && -f "$ICON_SOURCE" ]]; then
    echo "$ICON_SOURCE"
    return 0
  fi

  local candidates=(
    "$PROJECT_DIR/AppIcon.icns"
    "$PROJECT_DIR/assets/AppIcon.icns"
    "$PROJECT_DIR/Assets/AppIcon.icns"
    "$PROJECT_DIR/Resources/AppIcon.icns"
    "/Applications/${APP_DISPLAY_NAME}.app/Contents/Resources/AppIcon.icns"
    "$LEGACY_INSTALL_DIR/Contents/Resources/AppIcon.icns"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

pick_menubar_icon_source() {
  if [[ -n "$MENUBAR_ICON_SOURCE" && -f "$MENUBAR_ICON_SOURCE" ]]; then
    echo "$MENUBAR_ICON_SOURCE"
    return 0
  fi

  local candidates=(
    "$PROJECT_DIR/MenuBarIcon.png"
    "$PROJECT_DIR/assets/MenuBarIcon.png"
    "$PROJECT_DIR/Assets/MenuBarIcon.png"
    "$PROJECT_DIR/Resources/MenuBarIcon.png"
    "/Applications/${APP_DISPLAY_NAME}.app/Contents/Resources/MenuBarIcon.png"
    "$LEGACY_INSTALL_DIR/Contents/Resources/MenuBarIcon.png"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

pick_menubar_control_icon_source() {
  if [[ -n "$MENUBAR_CONTROL_ICON_SOURCE" && -f "$MENUBAR_CONTROL_ICON_SOURCE" ]]; then
    echo "$MENUBAR_CONTROL_ICON_SOURCE"
    return 0
  fi

  local candidates=(
    "$PROJECT_DIR/MenuBarControl.png"
    "$PROJECT_DIR/assets/MenuBarControl.png"
    "$PROJECT_DIR/Assets/MenuBarControl.png"
    "$PROJECT_DIR/Resources/MenuBarControl.png"
    "/Applications/${APP_DISPLAY_NAME}.app/Contents/Resources/MenuBarControl.png"
    "$LEGACY_INSTALL_DIR/Contents/Resources/MenuBarControl.png"
  )

  local candidate
  for candidate in "${candidates[@]}"; do
    if [[ -f "$candidate" ]]; then
      echo "$candidate"
      return 0
    fi
  done

  return 1
}

resolve_sign_identity() {
  if [[ "$SKIP_SIGN" == "1" ]]; then
    return 0
  fi

  if [[ -n "$SIGN_IDENTITY" ]]; then
    RESOLVED_SIGN_IDENTITY="$SIGN_IDENTITY"
    return 0
  fi

  if [[ -d "$INSTALL_DIR" ]]; then
    local existing existing_info
    existing_info="$(codesign -dv --verbose=4 "$INSTALL_DIR" 2>&1 || true)"
    existing="$(printf '%s\n' "$existing_info" | awk -F= '/^Authority=Apple Development: /{print $2}' | sed -n '1p')"
    if [[ -n "$existing" ]]; then
      RESOLVED_SIGN_IDENTITY="$existing"
      return 0
    fi
  fi

  local identities_output first_available
  identities_output="$(security find-identity -v -p codesigning 2>/dev/null || true)"
  first_available="$(printf '%s\n' "$identities_output" | awk -F '"' '/Apple Development: /{print $2; exit}')"
  if [[ -n "$first_available" ]]; then
    RESOLVED_SIGN_IDENTITY="$first_available"
  fi
}

stage_override_resource() {
  local source_path="$1"
  local destination_name="$2"

  if [[ -z "$source_path" || ! -f "$source_path" ]]; then
    return 0
  fi

  /usr/bin/ditto --norsrc "$source_path" "$APP_STAGE/Contents/Resources/$destination_name"
  xattr -c "$APP_STAGE/Contents/Resources/$destination_name" 2>/dev/null || true
}

sign_extension_if_needed() {
  local appex="$1"
  local entitlements_path="$PROJECT_DIR/Config/TransOnControlsExtension.entitlements"

  if [[ "$SKIP_SIGN" == "1" ]]; then
    log "Skipping extension codesign (SKIP_SIGN=1)"
    return 0
  fi

  if [[ -n "$RESOLVED_SIGN_IDENTITY" ]]; then
    log "Signing extension with identity: $RESOLVED_SIGN_IDENTITY"
    codesign --force --sign "$RESOLVED_SIGN_IDENTITY" --entitlements "$entitlements_path" --timestamp=none --generate-entitlement-der "$appex"
  else
    log "No Apple Development identity found; using ad-hoc signature for extension"
    codesign --force --sign - --entitlements "$entitlements_path" --timestamp=none --generate-entitlement-der "$appex"
  fi
}

sign_app_if_needed() {
  local bundle="$1"
  local entitlements_path="$PROJECT_DIR/Config/TransOn.entitlements"

  if [[ "$SKIP_SIGN" == "1" ]]; then
    log "Skipping app codesign (SKIP_SIGN=1)"
    return 0
  fi

  if [[ -n "$RESOLVED_SIGN_IDENTITY" ]]; then
    log "Signing app with identity: $RESOLVED_SIGN_IDENTITY"
    codesign --force --options runtime --entitlements "$entitlements_path" --sign "$RESOLVED_SIGN_IDENTITY" --timestamp=none "$bundle"
  else
    log "No Apple Development identity found; using ad-hoc signature for app"
    codesign --force --entitlements "$entitlements_path" --sign - --timestamp=none "$bundle"
  fi

  codesign --verify --deep --strict "$bundle"
}

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen is required but not installed." >&2
  exit 1
fi

if [[ ! -d "$DEVELOPER_DIR" ]]; then
  echo "DEVELOPER_DIR does not exist: $DEVELOPER_DIR" >&2
  exit 1
fi

resolve_sign_identity
if [[ -n "$RESOLVED_SIGN_IDENTITY" ]]; then
  log "Resolved signing identity: $RESOLVED_SIGN_IDENTITY"
fi

log "Generating Xcode project"
xcodegen --use-cache

rm -rf "$DERIVED_DATA_PATH"

log "Building unsigned Release app via xcodebuild"
xcodebuild \
  -project "$XCODEPROJ_PATH" \
  -scheme "$SCHEME" \
  -configuration Release \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGNING_ALLOWED=NO \
  MARKETING_VERSION="$APP_VERSION" \
  CURRENT_PROJECT_VERSION="$APP_BUILD" \
  build

SOURCE_APP="$DERIVED_DATA_PATH/Build/Products/Release/${APP_DISPLAY_NAME}.app"
if [[ ! -d "$SOURCE_APP" ]]; then
  echo "Built app not found: $SOURCE_APP" >&2
  exit 1
fi

ICON_PATH=""
if ICON_PATH="$(pick_icon_source)"; then
  log "Using icon: $ICON_PATH"
else
  log "Icon not found; keeping Xcode-built app icon"
fi

MENUBAR_ICON_PATH=""
if MENUBAR_ICON_PATH="$(pick_menubar_icon_source)"; then
  log "Using menu bar icon: $MENUBAR_ICON_PATH"
else
  log "Menu bar icon not found; keeping Xcode-built menu bar icon"
fi

MENUBAR_CONTROL_ICON_PATH=""
if MENUBAR_CONTROL_ICON_PATH="$(pick_menubar_control_icon_source)"; then
  log "Using menu bar control icon: $MENUBAR_CONTROL_ICON_PATH"
else
  log "Menu bar control icon not found; keeping Xcode-built control icon"
fi

STAGING_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/transon-build.XXXXXX")"
APP_STAGE="$STAGING_ROOT/${APP_DISPLAY_NAME}.app"
cleanup() {
  if [[ -n "$STAGING_ROOT" && -d "$STAGING_ROOT" ]]; then
    rm -rf "$STAGING_ROOT"
  fi
}
trap cleanup EXIT

log "Creating staged app bundle"
/usr/bin/ditto --norsrc "$SOURCE_APP" "$APP_STAGE"
xattr -cr "$APP_STAGE" 2>/dev/null || true

stage_override_resource "$ICON_PATH" "AppIcon.icns"
stage_override_resource "$MENUBAR_ICON_PATH" "MenuBarIcon.png"
stage_override_resource "$MENUBAR_CONTROL_ICON_PATH" "MenuBarControl.png"

xattr -cr "$APP_STAGE" 2>/dev/null || true

if [[ -d "$APP_STAGE/Contents/PlugIns/TransOnControlsExtension.appex" ]]; then
  sign_extension_if_needed "$APP_STAGE/Contents/PlugIns/TransOnControlsExtension.appex"
else
  echo "Embedded control extension not found in staged app." >&2
  exit 1
fi

sign_app_if_needed "$APP_STAGE"

mkdir -p "$(dirname "$APP_DIR")"
rm -rf "$APP_DIR"
/usr/bin/ditto --norsrc "$APP_STAGE" "$APP_DIR"
xattr -cr "$APP_DIR" 2>/dev/null || true

rm -rf "$INSTALL_DIR"
/usr/bin/ditto --norsrc "$APP_STAGE" "$INSTALL_DIR"
if [[ "$LEGACY_INSTALL_DIR" != "$INSTALL_DIR" ]]; then
  rm -rf "$LEGACY_INSTALL_DIR"
fi
xattr -cr "$INSTALL_DIR" 2>/dev/null || true

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Versions/Current/Frameworks/LaunchServices.framework/Versions/Current/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f -R -trusted "$INSTALL_DIR" >/dev/null 2>&1 || true
fi

INSTALLED_APPEX="$INSTALL_DIR/Contents/PlugIns/TransOnControlsExtension.appex"
if [[ -d "$INSTALLED_APPEX" ]]; then
  pluginkit -a "$INSTALLED_APPEX" >/dev/null 2>&1 || true
fi

codesign --verify --deep --strict "$INSTALL_DIR"

log "Built: $APP_DIR"
log "Installed: $INSTALL_DIR"
