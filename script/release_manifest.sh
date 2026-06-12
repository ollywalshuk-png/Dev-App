#!/usr/bin/env bash
set -euo pipefail

APP_NAME="LocalForge"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${APP_BUNDLE:-$ROOT_DIR/dist/$APP_NAME.app}"
ZIP_PATH="${ZIP_PATH:-}"
MANIFEST_PATH="${MANIFEST_PATH:-}"
MODE="--check"

usage() {
  cat <<USAGE
usage: script/release_manifest.sh [--check] [--app PATH] [--zip PATH] [--output PATH]

Collect local release artifact integrity facts without signing, uploading,
stapling, or requiring credentials. By default the manifest is printed to
stdout. Use --output to write it to a local release evidence file.

Options:
  --check          Inspect local artifacts only (default)
  --app PATH       App bundle to inspect (default: dist/$APP_NAME.app)
  --zip PATH       Release zip to hash with SHA-256 when available
  --output PATH    Write the manifest to PATH instead of stdout
  -h, --help       Show this help

Environment overrides:
  APP_BUNDLE       App bundle path
  ZIP_PATH         Release zip path
  MANIFEST_PATH    Manifest output path

USAGE
}

require_value() {
  local option="$1"
  local value="${2:-}"
  if [[ -z "$value" ]]; then
    echo "Missing value for $option" >&2
    exit 2
  fi
}

normalize_path() {
  local path="$1"
  if [[ "$path" == /* ]]; then
    printf "%s\n" "$path"
  else
    printf "%s/%s\n" "$ROOT_DIR" "$path"
  fi
}

git_field() {
  local value
  if value="$(git -C "$ROOT_DIR" "$@" 2>/dev/null)"; then
    printf "%s\n" "$value"
  else
    printf "unavailable\n"
  fi
}

git_dirty_state() {
  local status
  status="$(git -C "$ROOT_DIR" status --porcelain 2>/dev/null || true)"
  if [[ -z "$status" ]]; then
    printf "no\n"
  else
    printf "yes\n"
  fi
}

sha256_for_file() {
  local path="$1"
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$path" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -r "$path" | awk '{print $1}'
  else
    printf "unavailable: no shasum or openssl found\n"
  fi
}

indent_output() {
  local text="$1"
  if [[ -z "$text" ]]; then
    printf "    (no output)\n"
    return
  fi

  while IFS= read -r line; do
    printf "    %s\n" "$line"
  done <<< "$text"
}

command_result_block() {
  local label="$1"
  local command_text="$2"
  shift 2

  local output
  local exit_code=0
  local status="PASS"

  if output="$("$@" 2>&1)"; then
    exit_code=0
  else
    exit_code=$?
    status="FAIL"
  fi

  printf "%s:\n" "$label"
  printf "  status: %s\n" "$status"
  printf "  exit_code: %s\n" "$exit_code"
  printf "  command: %s\n" "$command_text"
  printf "  output:\n"
  indent_output "$output"
}

print_manifest() {
  local app_path="$1"
  local zip_path="$2"

  printf "LocalForge Release Integrity Manifest\n"
  printf "generated_at_utc: %s\n" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"
  printf "repository_root: %s\n" "$ROOT_DIR"
  printf "git_commit: %s\n" "$(git_field rev-parse --verify HEAD)"
  printf "git_branch: %s\n" "$(git_field branch --show-current)"
  printf "git_dirty: %s\n" "$(git_dirty_state)"
  printf "origin_remote: %s\n" "$(git_field remote get-url origin)"
  printf "upstream_remote: %s\n" "$(git_field remote get-url upstream)"
  printf "app_path: %s\n" "$app_path"

  if [[ -d "$app_path" ]]; then
    printf "app_exists: yes\n"
  else
    printf "app_exists: no\n"
  fi

  if [[ -n "$zip_path" ]]; then
    printf "zip_path: %s\n" "$zip_path"
    if [[ -f "$zip_path" ]]; then
      printf "zip_exists: yes\n"
      printf "zip_sha256: %s\n" "$(sha256_for_file "$zip_path")"
    else
      printf "zip_exists: no\n"
      printf "zip_sha256: not recorded: zip file not found\n"
    fi
  else
    printf "zip_path: not provided\n"
    printf "zip_sha256: not recorded: no zip provided\n"
  fi

  if [[ -d "$app_path" ]]; then
    if command -v codesign >/dev/null 2>&1; then
      command_result_block \
        "codesign_verify" \
        "codesign --verify --deep --strict --verbose=2 $app_path" \
        codesign --verify --deep --strict --verbose=2 "$app_path"
    else
      printf "codesign_verify:\n"
      printf "  status: SKIPPED\n"
      printf "  reason: codesign not found\n"
    fi

    if command -v xcrun >/dev/null 2>&1; then
      command_result_block \
        "stapler_validate" \
        "xcrun stapler validate $app_path" \
        xcrun stapler validate "$app_path"
    else
      printf "stapler_validate:\n"
      printf "  status: SKIPPED\n"
      printf "  reason: xcrun not found\n"
    fi
  else
    printf "codesign_verify:\n"
    printf "  status: SKIPPED\n"
    printf "  reason: app bundle not found\n"
    printf "stapler_validate:\n"
    printf "  status: SKIPPED\n"
    printf "  reason: app bundle not found\n"
  fi

  printf "operator_note: local evidence only; this script does not sign, notarize, staple, upload, or require credentials.\n"
}

while (($#)); do
  case "$1" in
    --check|check)
      MODE="--check"
      shift
      ;;
    --app)
      require_value "$1" "${2:-}"
      APP_BUNDLE="$2"
      shift 2
      ;;
    --zip)
      require_value "$1" "${2:-}"
      ZIP_PATH="$2"
      shift 2
      ;;
    --output)
      require_value "$1" "${2:-}"
      MANIFEST_PATH="$2"
      shift 2
      ;;
    -h|--help|help)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

case "$MODE" in
  --check)
    ;;
  *)
    usage >&2
    exit 2
    ;;
esac

APP_BUNDLE="$(normalize_path "$APP_BUNDLE")"
if [[ -n "$ZIP_PATH" ]]; then
  ZIP_PATH="$(normalize_path "$ZIP_PATH")"
fi

if [[ -n "$MANIFEST_PATH" ]]; then
  MANIFEST_PATH="$(normalize_path "$MANIFEST_PATH")"
  mkdir -p "$(dirname "$MANIFEST_PATH")"
  print_manifest "$APP_BUNDLE" "$ZIP_PATH" >"$MANIFEST_PATH"
  echo "Wrote release integrity manifest: $MANIFEST_PATH"
else
  print_manifest "$APP_BUNDLE" "$ZIP_PATH"
fi
