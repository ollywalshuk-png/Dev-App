# Release Engineering Checklist

Date: 2026-06-12

Status: Phase 11 planning baseline. Local development builds are validated, but
the app is not distribution-ready.

## Current Release Position

- `./script/build_and_run.sh --verify` builds and bundles the local app.
- The local bundle is ad-hoc signed for development verification.
- `codesign --verify --deep --strict dist/LocalForge.app` passes.
- Developer ID signing is not configured.
- Notarisation credentials are not configured.
- Stapling and Gatekeeper distribution acceptance are not yet validated.
- Clean-machine verification is not yet complete.

## Release Build Checklist

- Start from a clean Git branch.
- Confirm no generated build artefacts are staged.
- Confirm version, build number, and release notes.
- Run the Xcode-toolchain Swift build:
  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    CLANG_MODULE_CACHE_PATH=.build/ModuleCache \
    swift build --cache-path .build/swiftpm-cache
  ```
- Run the Xcode-toolchain Swift tests:
  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    CLANG_MODULE_CACHE_PATH=.build/ModuleCache \
    swift test --cache-path .build/swiftpm-cache
  ```
- Run the local bundle verifier:
  ```sh
  ./script/build_and_run.sh --verify
  ```
- Capture a local release integrity manifest after the bundle or archive is
  available:
  ```sh
  script/release_manifest.sh --check \
    --zip dist/LocalForge-notarization.zip \
    --output dist/release-integrity-manifest.txt
  ```
  Omit `--zip` before the archive exists. The helper records the app path, Git
  commit, optional zip SHA-256, codesign verification summary, and stapler
  validation result without signing, stapling, uploading, or requiring
  credentials.
- Confirm `dist/LocalForge.app` launches and the human UI smoke checklist is complete.

## Developer ID Signing Preparation

- Confirm Apple Developer Program membership.
- Confirm the Developer ID Application certificate is installed.
- Decide hardened runtime settings.
- Review entitlements.
- Confirm bundle identifier and display name.
- Confirm whether App Sandbox is required for the target channel.
- Document signing identity in operator-local notes, not in the repository.

## Notarisation Preparation

- Run the non-mutating check:
  ```sh
  script/notarize.sh --check
  ```
- Create or confirm a local `notarytool` keychain profile.
- Set required submission environment variables only in the operator shell:
  - `DEVELOPER_ID_APPLICATION`
  - `NOTARYTOOL_PROFILE`
- Submit only after the operator explicitly chooses distribution mode:
  ```sh
  script/notarize.sh --submit
  ```
- Preserve notarisation logs as release evidence.

## Stapling And Gatekeeper

- Staple only after notarisation succeeds:
  ```sh
  xcrun stapler staple dist/LocalForge.app
  ```
- Validate the stapled bundle:
  ```sh
  xcrun stapler validate dist/LocalForge.app
  ```
- Run Gatekeeper assessment only after Developer ID signing and notarisation:
  ```sh
  spctl -a -vv dist/LocalForge.app
  ```

## Clean-Machine Verification

- Copy the notarised and stapled bundle to a clean macOS machine.
- Launch from Finder.
- Confirm first-run folder access prompts are understandable.
- Open a known Swift package project.
- Confirm workspace persistence after relaunch.
- Run the Phase 10F UI smoke checks.
- Confirm no crash report is created.
- Confirm no unexpected outbound network activity is required.

## User Guide Required Before Release

- First launch and folder access.
- Adding a repository.
- Mission setup.
- Verification records.
- Evidence records.
- Release readiness.
- Dev Tools safety boundaries.
- Backup/export/import.
- Local privacy model.

## Troubleshooting Guide Required Before Release

- App will not open.
- Folder access is stale or missing.
- Git is unavailable.
- Build/test preset fails.
- Codesign or Gatekeeper checks fail.
- Workspace database is corrupt or restored from backup.
- Export/import fails.
- Diagnostic background readability issues.

## Approval Gates

Release engineering remains approval-gated. No script should silently:

- Change signing identities.
- Upload for notarisation.
- Staple a bundle.
- Delete release artefacts.
- Commit or push release changes.
- Modify user projects.
- Upload or transmit release integrity manifests.
