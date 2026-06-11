#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LocalForge"
BUNDLE_ID="com.localforge.LocalForge"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${APP_BUNDLE:-$ROOT_DIR/dist/$APP_NAME.app}"
ARCHIVE_PATH="${ARCHIVE_PATH:-$ROOT_DIR/dist/$APP_NAME-notarization.zip}"
MODE="${1:---check}"

usage() {
  cat <<USAGE
usage: script/notarize.sh [--check|--submit]

Default mode is --check. It validates local prerequisites and prints the
required environment variables without signing, uploading, or modifying files.

Required for --submit:
  DEVELOPER_ID_APPLICATION  Developer ID Application identity name
  NOTARYTOOL_PROFILE        notarytool keychain profile name

Optional:
  APP_BUNDLE                path to .app bundle (default: dist/$APP_NAME.app)
  ARCHIVE_PATH              zip output path (default: dist/$APP_NAME-notarization.zip)

Before --submit, create a notarytool profile manually, for example:
  xcrun notarytool store-credentials "LocalForgeNotary"

USAGE
}

require_bundle() {
  if [[ ! -d "$APP_BUNDLE" ]]; then
    echo "Missing app bundle: $APP_BUNDLE" >&2
    echo "Run ./script/build_and_run.sh --verify first." >&2
    exit 1
  fi
}

check_mode() {
  require_bundle
  echo "LocalForge notarisation prerequisite check"
  echo "Bundle: $APP_BUNDLE"
  echo "Bundle ID: $BUNDLE_ID"
  echo
  codesign --verify --deep --strict "$APP_BUNDLE"
  echo "Adhoc/local codesign verification: PASS"
  echo
  echo "Not submitted. Set credentials and run:"
  echo "  DEVELOPER_ID_APPLICATION=\"Developer ID Application: ...\" \\"
  echo "  NOTARYTOOL_PROFILE=\"LocalForgeNotary\" \\"
  echo "  script/notarize.sh --submit"
}

submit_mode() {
  require_bundle
  : "${DEVELOPER_ID_APPLICATION:?Set DEVELOPER_ID_APPLICATION to your Developer ID Application identity.}"
  : "${NOTARYTOOL_PROFILE:?Set NOTARYTOOL_PROFILE to your notarytool keychain profile.}"

  codesign --force --deep --options runtime --timestamp \
    --sign "$DEVELOPER_ID_APPLICATION" "$APP_BUNDLE"
  codesign --verify --deep --strict "$APP_BUNDLE"

  /usr/bin/ditto -c -k --keepParent "$APP_BUNDLE" "$ARCHIVE_PATH"
  xcrun notarytool submit "$ARCHIVE_PATH" \
    --keychain-profile "$NOTARYTOOL_PROFILE" \
    --wait
  xcrun stapler staple "$APP_BUNDLE"
  spctl -a -vv "$APP_BUNDLE"
}

case "$MODE" in
  --check|check)
    check_mode
    ;;
  --submit|submit)
    submit_mode
    ;;
  -h|--help|help)
    usage
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac
