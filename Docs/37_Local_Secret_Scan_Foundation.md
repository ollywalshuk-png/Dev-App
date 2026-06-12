# Local Secret Scan Foundation

LocalForge now has a local-only secret pattern scanner foundation in
`SecretScannerEngine`.

The scanner is deliberately read-only:

- It scans only an explicitly selected repository root.
- It skips generated/cache/dependency folders such as `.git`, `.build`,
  `.swiftpm`, `DerivedData`, `node_modules`, `dist`, and `build`.
- It caps scanned file size to avoid slow or surprising binary reads.
- It records path, line number, finding kind, severity, reason, and a redacted
  preview only.
- It does not store matched credential values.
- It does not delete files, rewrite history, rotate credentials, commit, push,
  or upload anything.

Detected patterns currently include:

- credential-like assignments such as token/password/key variables;
- provider-token-shaped strings;
- URLs with embedded credentials;
- private-key headers.

Findings can be converted into Safety recommendations. Those recommendations
tell the user to remove and rotate real credentials manually and to move
repeatable build secrets into Keychain, environment injection, or untracked
local configuration.

This is a Phase 16 foundation slice, not the full Security Intelligence UI.
Future UI work should keep the same constraints: local-only, explicit scan,
redacted previews, no cloud upload, and no automatic deletion.

UI note: the Recommendations screen now exposes a manual **Scan Secrets** action
for the selected project. It runs `SecretScannerEngine` against that selected
repository root only, records Safety recommendations with redacted evidence, and
does not delete files, rotate credentials, upload content, commit, push, or run
in the background.
