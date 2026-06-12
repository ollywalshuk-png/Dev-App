# Upstream Release Handoff

Date: 2026-06-12

Status: practical handoff for moving a notarised fork release to the upstream
repository when the upstream maintainer has the required permissions. This
document does not grant permission, store credentials, or replace the release
engineering checklist in `Docs/34_Release_Engineering_Checklist.md`.

## Scope

- Target upstream repository: `ollywalshuk-png/Dev-App`.
- Source release: a fork release whose final artifact has already been signed,
  notarised, stapled, and verified.
- Publisher: Olly or another upstream maintainer using their own GitHub access.
- Handoff owner: the fork release operator, who provides artifact evidence,
  checksums, and release notes without sharing secrets.

## Required GitHub Permission

- The publisher needs GitHub access that can create and edit Releases in
  `ollywalshuk-png/Dev-App`; in practice this means Write, Maintain, or Admin
  access, subject to any repository rules.
- If tag protection, branch protection, SSO, or organization policy applies, the
  upstream maintainer follows those rules instead of bypassing them.
- A fork operator without upstream release permission stops at the handoff
  package. They should not borrow another user's token or account.

## Secret Boundary

Never include or transmit:

- Apple Developer ID certificate private keys.
- Keychain exports.
- `notarytool` profiles or app-specific passwords.
- Apple API keys, CI secrets, environment files, or GitHub personal access
  tokens.
- Raw logs that contain credentials, tokens, private paths, or signing material.

Safe handoff material is limited to public release notes, Git commit or tag
references, SHA-256 digests, sanitized notarisation summaries, stapler and
Gatekeeper results, and links to reviewable fork PRs or releases.

## Handoff Package

Provide the upstream maintainer with:

- Fork release URL and the exact fork commit or tag used to build it.
- Intended upstream version, tag, artifact filename, and release title.
- Final artifact SHA-256 generated after the zip, dmg, or other distributable is
  closed.
- Artifact trust proof from `Docs/42_Release_Artifact_Trust_Runbook.md`: the
  pre-upload SHA-256, post-upload downloaded SHA-256, and exact comparison
  result.
- Sanitized notarisation success summary, including date and request/result
  status.
- Stapler validation summary for the final `.app` bundle.
- Gatekeeper assessment summary from a clean macOS verification path.
- Release notes copied from the fork release, edited only for upstream naming,
  version, and known caveats.
- Any open release caveats that should remain visible to users.

## Verification Checklist

- Confirm the upstream release target commit is the reviewed commit intended for
  this release.
- Download or copy the final artifact into a clean verification location.
- Recompute the SHA-256 and compare it exactly with the handoff digest:
  ```sh
  shasum -a 256 <artifact>
  ```
- Verify code signing on the final app bundle:
  ```sh
  codesign --verify --deep --strict --verbose=2 <LocalForge.app>
  ```
- Validate the stapled ticket:
  ```sh
  xcrun stapler validate <LocalForge.app>
  ```
- Run Gatekeeper assessment after Developer ID signing and notarisation:
  ```sh
  spctl -a -vv <LocalForge.app>
  ```
- Launch from Finder on a clean macOS machine and complete the current UI smoke
  checks.
- Publish the upstream release with the fork release notes and include the
  SHA-256 digest in the release body.
- After publishing, use `Docs/42_Release_Artifact_Trust_Runbook.md` to download
  the upstream asset from GitHub, compare it with the pre-upload SHA-256, and
  repeat stapler, Gatekeeper, and launch checks against the downloaded asset.

## Anti-Patterns

- Sharing Apple, GitHub, or CI credentials to let someone else publish.
- Publishing with a borrowed account or personal access token.
- Rebuilding a different artifact upstream while reusing the fork artifact's
  SHA-256, notarisation evidence, or release notes.
- Editing, rezipping, or renaming an artifact after the SHA-256 was recorded
  without regenerating and revalidating the digest.
- Treating notarisation success as a substitute for stapler, Gatekeeper, and
  clean-machine launch checks.
- Treating a successful GitHub upload as proof of asset identity without
  downloading the release asset and comparing SHA-256 digests.
- Copying fork release notes while dropping known caveats or unresolved release
  blockers.
- Publishing from an unreviewed fork branch or ambiguous commit.
- Pasting raw notarisation, CI, or shell logs into the release body without
  checking for secrets.
