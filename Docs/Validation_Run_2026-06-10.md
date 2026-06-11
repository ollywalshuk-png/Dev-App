# LocalForge Runtime Validation

Date: 2026-06-10
Build: `dist/LocalForge.app` (re-sealed adhoc, codesign --verify PASS)
Checklist: [26_Runtime_Validation_Checklist.md](26_Runtime_Validation_Checklist.md)
Operator: <fill in>

Launch with logs visible before starting:

```sh
./script/build_and_run.sh --logs
```

The goal of this run is **observation only**. Do not fix anything mid-pass —
record everything, prioritise after, then fix in a separate session. This
matches the Feature Freeze Rule: no new feature work while validation defects
exist.

---

## Passes

Tick items that worked as expected. Bare list is fine; no need to elaborate.

- [ ] App launches and stays running
- [ ] No crash report in `~/Library/Logs/DiagnosticReports/`
- [ ] No errors in `--logs` stream during a 5-minute exercise
- [ ] Command Palette opens with ⌘K
- [ ] Command Palette closes on Escape
- [ ] Command Palette closes on outside-tap
- [ ] Sidebar — Command Centre group renders
- [ ] Sidebar — Operations group renders
- [ ] Sidebar — System group renders
- [ ] Workspace module loads
- [ ] Search module loads and returns results
- [ ] Projects module loads
- [ ] Mission module loads
- [ ] Verification module loads
- [ ] Release Readiness module loads
- [ ] Timeline module loads
- [ ] Project Journal module loads
- [ ] Truth Centre module loads
- [ ] Registers module loads
- [ ] Knowledge Vault module loads
- [ ] Reports module loads
- [ ] Handoff module loads
- [ ] Workspace Health module loads
- [ ] Workspace Doctor module loads
- [ ] Saved Views module loads
- [ ] Project Review module loads
- [ ] Build History module loads
- [ ] Backup Centre module loads
- [ ] Utility Centre module loads
- [ ] CLI module loads
- [ ] Settings module loads
- [ ] Favourite star toggles
- [ ] Favourites persist across relaunch
- [ ] Saved view pin/unpin persists across relaunch
- [ ] Backup created in `~/Library/Application Support/LocalForge/Backups/`
- [ ] Export → Import round-trips workspace
- [ ] Utility Centre — Quarantine Inspector returns output
- [ ] Utility Centre — Capture Environment creates a snapshot
- [ ] Project Review answers become journal entries

---

## Defects

One entry per defect. Use the LF-NNN ID series. Severity: Critical / High / Medium / Low.

### LF-001
Area: <module name>
Issue: <what's wrong, one sentence>
Reproduction:
1. <step>
2. <step>
Expected: <what should happen>
Actual: <what happens>
Severity: <Critical/High/Medium/Low>
Category: <A: UI Layout / B: Navigation / C: Persistence / D: Runtime>

---

## Console / log notes

Paste any non-obvious lines from the `--logs` stream here. Strip noise; keep
warnings, errors, faults, and anything that names a LocalForge symbol.

```
(none yet)
```

---

## Summary

Total items checked: __ / __
Passes: __
Defects: __
Critical: __  High: __  Medium: __  Low: __

Category breakdown:
- A (UI Layout): __
- B (Navigation): __
- C (Persistence): __
- D (Runtime): __

Next action: <fix in priority order, do not start new features>

---

## Agent Machine Validation — 2026-06-11

Operator: Codex

Scope: machine-verifiable checks only. Human UI walkthrough remains open and is still the blocking P1 gate.

Passes:

- [x] Xcode-toolchain `swift build --cache-path .build/swiftpm-cache` succeeded.
- [x] Xcode-toolchain `swift test --cache-path .build/swiftpm-cache` succeeded: 69 tests, 3 suites.
- [x] `./script/build_and_run.sh --verify` succeeded.
- [x] `dist/LocalForge.app/Contents/MacOS/LocalForge` exists and is executable.
- [x] `dist/LocalForge.app/Contents/_CodeSignature/CodeResources` exists.
- [x] `codesign --verify --deep --strict dist/LocalForge.app` passed.
- [x] LocalForge process was running after launch verification: PID 70730.
- [x] No LocalForge crash reports appeared in `~/Library/Logs/DiagnosticReports/`.
- [x] Recent unified log sample contained only AppKit state-restoration messages; no LocalForge `error`, `fault`, or `fatal` lines observed.
- [x] `~/Library/Application Support/LocalForge/workspace.sqlite` exists.
- [x] SQLite header check returned `SQLite format 3`.

Defects found by agent:

- None in machine-verifiable checks.

Open gate:

- Human runtime validation checklist remains incomplete. Do not start Phase 9B P3 feature gaps until the operator walks the UI checklist and triages any findings.

Notes:

- This workspace currently does not present as a Git repository to `git status`; the handoff calls it a repo, but `.git` was not available from this workspace during this validation.

---

## Agent Focused UI Validation Attempt — 2026-06-11

Operator: Codex

Scope requested: Utility Centre stability, Test Registry, Environment Registry, diagnostic background settings, persistence after relaunch, backup/export/import.

What could be machine-observed:

- [x] `./script/build_and_run.sh --logs` built, re-signed, launched, and streamed LocalForge logs.
- [x] First log pass found a real SwiftUI runtime fault:
  `ForEach<Array<String>...>: the ID 10 Jun 2026 · Build swift build: Success occurs multiple times within the collection`.
- [x] Root cause fixed in `GuardianPanel`: latest activity now uses stable index identity instead of `id: \.self`.
- [x] Xcode-toolchain `swift build --cache-path .build/swiftpm-cache` passed after the fix.
- [x] Xcode-toolchain `swift test --cache-path .build/swiftpm-cache` passed after the fix: 72 tests, 3 suites.
- [x] Second `./script/build_and_run.sh --logs` sample no longer showed the duplicate-ID SwiftUI fault.

What could not be completed by Codex:

- [ ] Test Registry add/edit/save click-through.
- [ ] Environment Registry capture/compare click-through.
- [ ] Diagnostic rain readability judgment.
- [ ] Light/dark mode visual judgment.
- [ ] Reduce Motion behavior.
- [ ] Settings persistence through manual UI changes.
- [ ] Utility Centre no-hang retest by clicking every listed tool.
- [ ] Backup/export/import workflow through save/open panels.

Reason:

- macOS System Events reported `osascript is not allowed assistive access`, so Codex could not drive or inspect the native UI controls directly. These remain human-operator validation items.

Defects:

### LF-002
Area: Guardian Panel / Latest Activity
Issue: Duplicate latest-activity strings caused SwiftUI duplicate `ForEach` IDs.
Reproduction:
1. Launch with `./script/build_and_run.sh --logs`.
2. Open a workspace with duplicate journal activity strings.
Expected: Latest activity renders without SwiftUI identity faults.
Actual: Log emitted duplicate-ID fault for repeated `10 Jun 2026 · Build swift build: Success`.
Severity: Low
Category: D: Runtime
Status: Fixed 2026-06-11 by switching the `ForEach` identity to enumerated offsets.

### LF-003
Area: Release process / source control
Issue: Workspace folder is not a Git repository.
Reproduction:
1. Run `git status --short` from `/Users/studiomacmini/Desktop/App assets/Dev App`.
Expected: Branch and working tree state are available for release-quality work.
Actual: `fatal: not a git repository (or any of the parent directories): .git`; `ls -la .git` also reports missing.
Severity: High
Category: D: Runtime / Release Process
Status: Open. Restore/init version control or clearly manage this as a non-Git source bundle before release-quality work continues.
