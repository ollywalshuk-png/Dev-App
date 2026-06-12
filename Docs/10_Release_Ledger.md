# Release Ledger

V1 is not distribution-ready.

## Release blockers

- Human UI smoke validation remains open: background settings, Test Registry, Environment Registry, Utility Centre, Backup/export/import, light/dark, and Reduce Motion.
- Developer ID Application identity and notarytool credentials are not configured in this workspace.
- Source control is restored, but every release candidate still needs a clean branch, reviewable commits, and an explicit release PR.

## Required before sale

- App sandbox and signing configuration.
- Hardened runtime decisions.
- App privacy review.
- SQLite migration plan.
- UI smoke verification.
- Developer ID signing, notarisation, stapling, and clean-machine launch test.

## Current release tooling

- `./script/build_and_run.sh --verify` builds, bundles, adhoc re-signs, launches, and verifies the local development app.
- `script/notarize.sh --check` validates the local bundle and prints the required distribution credentials without signing or uploading.
- `script/notarize.sh --submit` is explicit distribution mode. It requires:
  - `DEVELOPER_ID_APPLICATION`
  - `NOTARYTOOL_PROFILE`
  - a pre-created notarytool keychain profile

`spctl -a -vv` is intentionally not part of the local development gate. It belongs after Developer ID signing and notarisation.

Latest local baseline observed 2026-06-12:

- Xcode-toolchain `swift build --cache-path .build/swiftpm-cache` passed.
- Xcode-toolchain `swift test --cache-path .build/swiftpm-cache` passed with 82 Swift Testing tests across 5 suites.
- `./script/build_and_run.sh --verify` passed.
- `codesign --verify --deep --strict --verbose=2 dist/LocalForge.app` passed.
- `dist/LocalForge.app` is ad-hoc signed, not Developer ID signed.

Phase 11 release engineering details are tracked in `Docs/34_Release_Engineering_Checklist.md`.

## Deferred release capabilities

- Automatic update channel.
- Installer/package generation.
- App Store sandbox/package review.
- Clean-machine QA matrix.
