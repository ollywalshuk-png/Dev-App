# Release Artifact Trust Runbook

Date: 2026-06-12

Status: operational proof steps for showing that the notarised release artifact
served by GitHub is byte-for-byte the final artifact produced by the release
operator.

## Trust Claim

This runbook proves one narrow claim:

> The artifact downloaded from a GitHub Release has the same SHA-256 digest as
> the final notarised artifact recorded before upload.

Notarisation proves Apple's assessment of the signed app bundle. It does not
prove which bytes GitHub serves. The GitHub proof is the post-upload download
hash comparison.

## Inputs

- GitHub repository, release tag, and exact asset filename.
- Reviewed source commit or tag used for the release.
- Final local artifact path after signing, notarisation, stapling, packaging,
  and release manifest checks.
- Sanitized notarisation, stapler, Gatekeeper, and clean-machine evidence.

## Pre-Upload Freeze

Run this after the zip, dmg, or other distributable is closed:

```sh
ASSET="LocalForge-vX.Y.Z-macOS-notarized.zip"
LOCAL_ARTIFACT="dist/$ASSET"
shasum -a 256 "$LOCAL_ARTIFACT" | tee "dist/$ASSET.sha256"
chmod a-w "$LOCAL_ARTIFACT"
```

Record the digest line exactly. Any later rename is acceptable only if the file
bytes are unchanged and the digest is rechecked. Any rezip, rebuild, stapling
change, metadata edit, or asset replacement invalidates the digest.

## Upload

Upload only the frozen artifact to the intended GitHub Release. Include the
SHA-256 digest in the release body or a checksums attachment. Do not include
notarytool profiles, Apple credentials, GitHub tokens, keychain exports,
environment dumps, or raw logs.

## Post-Upload Download Proof

Use a clean directory and download the asset from GitHub, not from the local
`dist/` directory:

```sh
REPO="ollywalshuk-png/Dev-App"
TAG="vX.Y.Z"
ASSET="LocalForge-vX.Y.Z-macOS-notarized.zip"
VERIFY_DIR="$(mktemp -d)"

gh release download "$TAG" \
  --repo "$REPO" \
  --pattern "$ASSET" \
  --dir "$VERIFY_DIR" \
  --clobber

EXPECTED="$(cut -d ' ' -f 1 "dist/$ASSET.sha256")"
ACTUAL="$(shasum -a 256 "$VERIFY_DIR/$ASSET" | cut -d ' ' -f 1)"
test "$EXPECTED" = "$ACTUAL"
printf 'expected %s\nactual   %s\n' "$EXPECTED" "$ACTUAL"
```

If `gh` is unavailable, download the release asset through the GitHub web UI or
with `curl -L` from the release asset URL, then run the same `shasum` comparison
against the downloaded file.

## Downloaded App Verification

After the hash comparison passes, verify the downloaded artifact contents:

```sh
UNPACKED="$VERIFY_DIR/unpacked"
mkdir -p "$UNPACKED"
ditto -x -k "$VERIFY_DIR/$ASSET" "$UNPACKED"

codesign --verify --deep --strict --verbose=2 "$UNPACKED/LocalForge.app"
xcrun stapler validate "$UNPACKED/LocalForge.app"
spctl -a -vv "$UNPACKED/LocalForge.app"
```

Then launch the downloaded app from Finder on a clean macOS machine and run the
current UI smoke checks.

## Evidence Packet

Keep only these release-proof facts in docs, release notes, or handoff material:

- Repository, release URL, tag, asset filename, and reviewed source commit.
- Local pre-upload SHA-256 line.
- Post-upload downloaded SHA-256 line.
- Result of the exact digest comparison command.
- Sanitized notarisation request/result status and date.
- Stapler, Gatekeeper, and clean-machine verification summaries.

## Secret Boundary

- Keep Apple credentials, GitHub credentials, keychain profiles, app-specific
  passwords, API keys, CI secrets, and personal access tokens out of the repo.
- Do not paste raw notarisation, CI, shell, or `gh` logs into release docs
  without reviewing and redacting them.
- Do not run `env`, print keychain items, or capture full shell histories for
  the evidence packet.
- If a credential appears in captured evidence, discard that capture and
  regenerate a sanitized summary.

## Failure Handling

- If the downloaded SHA-256 differs, the GitHub asset is not proven. Stop,
  delete or replace the release asset, and restart the download proof.
- If signing, stapler, Gatekeeper, or clean-machine checks fail on the
  downloaded artifact, mark the release blocked until a new final artifact is
  produced and reverified.
- Never reuse notarisation evidence or a SHA-256 digest for a rebuilt or
  repackaged artifact.
