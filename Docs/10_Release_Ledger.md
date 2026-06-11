# Release Ledger

V1 is not distribution-ready.

## Release blockers

- Git source control state is unresolved. `/Users/studiomacmini/Desktop/App assets/Dev App` is currently a non-Git source bundle; restore the original `.git`, initialize a new repo with operator approval, or explicitly accept non-repo handling before a release candidate.
- Human UI smoke validation remains open: background settings, Test Registry, Environment Registry, Utility Centre, Backup/export/import, light/dark, and Reduce Motion.
- Developer ID Application identity and notarytool credentials are not configured in this workspace.

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

## Deferred release capabilities

- Automatic update channel.
- Installer/package generation.
- App Store sandbox/package review.
- Clean-machine QA matrix.
