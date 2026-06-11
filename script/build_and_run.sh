#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="LocalForge"
BUNDLE_ID="com.localforge.LocalForge"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

cd "$ROOT_DIR"
mkdir -p .build/ModuleCache .build/swiftpm-cache

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift build --cache-path .build/swiftpm-cache --product "$APP_NAME"
BUILD_BINARY="$(env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift build --cache-path .build/swiftpm-cache --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

# Re-seal the bundle. swift build emits an adhoc-signed Mach-O whose embedded
# signature claims sealed resources should exist, but the bundle as assembled
# has no _CodeSignature/CodeResources file — codesign --verify and Finder
# launch both reject that mismatch. Re-signing the full bundle (still adhoc)
# writes CodeResources, so verify passes. Developer ID + notarisation is a
# separate distribution-phase concern.
codesign --force --deep --sign - "$APP_BUNDLE"
codesign --verify --deep --strict "$APP_BUNDLE"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
