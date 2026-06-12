# Release Ledger

V1 is not distribution-ready as an upstream release line. A notarised
v0.0.3 macOS artifact exists on the `boggspa/Dev-App` fork release, but it has
not been published as an upstream `ollywalshuk-png/Dev-App` release artifact.

## Release blockers

- Human UI smoke validation remains open: background settings, Test Registry, Environment Registry, Utility Centre, Backup/export/import, light/dark, and Reduce Motion.
- Developer ID Application identity and notarytool credentials remain
  operator-local release inputs, not repository defaults.
- Publishing official upstream release assets still requires write permission
  on Olly's `ollywalshuk-png/Dev-App` repository, or an upstream maintainer to
  publish a handoff artifact.
- Source control is restored, but every release candidate still needs a clean branch, reviewable commits, and an explicit release PR.

## Required before sale

- App sandbox and signing configuration.
- Hardened runtime decisions.
- App privacy review.
- SQLite migration plan.
- UI smoke verification.
- Developer ID signing, notarisation, stapling, and clean-machine launch test.
- Upstream release publication permission or a documented maintainer handoff.

## Current release tooling

- `./script/build_and_run.sh --verify` builds, bundles, adhoc re-signs, launches, and verifies the local development app.
- `script/notarize.sh --check` validates the local bundle and prints the required distribution credentials without signing or uploading.
- `script/notarize.sh --submit` is explicit distribution mode. It requires:
  - `DEVELOPER_ID_APPLICATION`
  - `NOTARYTOOL_PROFILE`
  - a pre-created notarytool keychain profile
- `script/release_manifest.sh --check` records local release artifact facts for
  operator evidence: app path, Git commit, optional zip SHA-256, codesign
  verification summary, and stapler validation result when the app exists. It
  does not sign, notarise, staple, upload, or require credentials.

`spctl -a -vv` is intentionally not part of the local development gate. It belongs after Developer ID signing and notarisation.

Latest validation baseline observed for the fork release on 2026-06-12:

- Source baseline: upstream `main` at
  `beaec7cfdcf7d5066d55d29d80b58b95c71fe16a`.
- Fork release: `boggspa/Dev-App` tag `v0.0.3`, targeting the same upstream
  commit.
- Xcode-toolchain `swift build --cache-path .build/swiftpm-cache` passed.
- Xcode-toolchain `swift test --cache-path .build/swiftpm-cache` passed with
  116 tests across 12 suites.
- `./script/build_and_run.sh --verify` passed.
- `codesign --verify --deep --strict --verbose=2 dist/LocalForge.app` passed.
- `script/release_manifest.sh --check --zip dist/LocalForge-v0.0.3-macOS-notarized.zip` passed.
- Fork artifact:
  `LocalForge-v0.0.3-macOS-notarized.zip` on `boggspa/Dev-App` only, SHA-256
  `a5c10717ff75d7b5c2c6d9c076c2d13c7eba3d0578e9208439252ec5f45f905a`.
- Release build signed with Developer ID Application:
  `Christopher Izatt (8CZML8FK2D)`.
- Apple notarization accepted:
  `9834fb39-05f1-4725-8961-9cfe5bc853ad`.
- Stapler validation passed.
- Gatekeeper assessment accepted.
- No notarised artifact is published under the upstream
  `ollywalshuk-png/Dev-App` releases. Direct upstream release publication still
  needs write permission on Olly's repo or an upstream maintainer handoff.

Phase 11 release engineering details are tracked in `Docs/34_Release_Engineering_Checklist.md`.

## Deferred release capabilities

- Automatic update channel.
- Installer/package generation.
- App Store sandbox/package review.
- Clean-machine QA matrix.
