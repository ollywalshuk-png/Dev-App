# Runtime Validation Checklist

Stabilisation-phase gate for LocalForge. A feature is **not** considered complete
because it compiles — it is complete only after it builds, launches, and the
expected behaviour is observed.

This document is split into two classes per the agreed governance:

- **Machine-verifiable** — can be confirmed without a screen. Each item has a
  command. Run them from the repo root.
- **Human-verifiable** — requires the user's eyes. The agent cannot validate
  these alone; they must be walked through interactively.

Use this checklist before declaring any Phase 8.5 / Phase 9 work "done", and
re-run it after any signing, persistence, or navigation change.

---

## Class A — Machine-verifiable

### Build pipeline

- [ ] `swift build` succeeds with the toolchain workaround
  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    CLANG_MODULE_CACHE_PATH=.build/ModuleCache \
    swift build --cache-path .build/swiftpm-cache
  ```
- [ ] `script/build_and_run.sh --verify` exits zero
- [ ] `dist/LocalForge.app/Contents/MacOS/LocalForge` exists and is executable
  ```sh
  test -x dist/LocalForge.app/Contents/MacOS/LocalForge && echo OK
  ```
- [ ] `dist/LocalForge.app/Contents/_CodeSignature/CodeResources` exists
  ```sh
  test -f dist/LocalForge.app/Contents/_CodeSignature/CodeResources && echo OK
  ```
- [ ] `codesign --verify --deep --strict dist/LocalForge.app` passes
  > `spctl -a -vv` is **not** part of this gate. It requires Developer ID +
  > notarisation and belongs to the distribution phase, not stabilisation.

### Launch

- [ ] Process launches and stays alive ≥ 5 s after `open -n`
  ```sh
  open -n dist/LocalForge.app && sleep 5 && pgrep -lx LocalForge
  ```
- [ ] No crash report generated during the launch window
  ```sh
  ls -lt ~/Library/Logs/DiagnosticReports/ | grep -i localforge | head -5
  ```
- [ ] No errors logged to `os_log` during 10 s after launch
  ```sh
  /usr/bin/log show --last 10s --predicate 'process == "LocalForge"' --info \
    | grep -iE 'error|fault|fatal' | head
  ```

### Persistence

- [ ] SQLite workspace file is created on first launch
  ```sh
  test -f ~/Library/Application\ Support/LocalForge/workspace.sqlite && echo OK
  ```
- [ ] SQLite file is valid (header check)
  ```sh
  head -c 16 ~/Library/Application\ Support/LocalForge/workspace.sqlite \
    | grep -q "SQLite format 3" && echo OK
  ```
- [ ] Backup directory is created on first backup
  ```sh
  ls -la ~/Library/Application\ Support/LocalForge/Backups/ 2>/dev/null
  ```
- [ ] Workspace export → import round-trips. Export via the Backup Centre to
  `/tmp/lf-export.json`, then re-import; the workspace state JSON should be
  structurally equivalent (project IDs, verification records, registers all
  preserved).

### Tests

- [ ] `swift test` test target **builds** (compile-clean)
  ```sh
  DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
    CLANG_MODULE_CACHE_PATH=.build/ModuleCache \
    swift build --cache-path .build/swiftpm-cache --build-tests
  ```
  > Known infra defect: `swiftpm-testing-helper` cannot `dlopen` test bundles
  > when the project path contains spaces. The test binary itself builds; the
  > runner fails to load. Tracked separately from product correctness.

---

## Class B — Human-verifiable

You walk through these. The agent cannot see your screen, so these items are
your responsibility to confirm. Tick each one as you verify it.

### App shell

- [ ] App icon appears in the Dock
- [ ] Main window opens at a usable size
- [ ] Sidebar shows three sections: Command Centre, Operations, System
- [ ] Toolbar shows the ⌘ palette button, scan-mode picker, Open Repository, Rescan

### Command Palette

- [ ] ⌘K opens the palette overlay
- [ ] Typing filters results in real time
- [ ] Escape closes the palette
- [ ] Clicking outside the palette closes it
- [ ] Selecting a project result navigates to that project
- [ ] Selecting an action (e.g. "Open Workspace Health") navigates to that module
- [ ] Empty-query state shows the action list
- [ ] No-match query shows the empty state

### Explanation Layer

- [ ] Dashboard explains the Project -> Mission -> Verification -> Evidence -> Reality -> Release workflow
- [ ] Every major screen says what it is and why it matters
- [ ] Every major screen gives a next action
- [ ] Safety/read-only behaviour is visible where relevant
- [ ] Developer terms are explained without hiding technical detail
- [ ] Empty states explain how data appears and what the user should do next

### Sidebar / Navigation

- [ ] Each Command Centre module loads when selected
- [ ] Each Operations module loads when selected (Health, Doctor, Saved Views,
      Project Review, Build History, Test Registry, Environment Registry,
      Backup Centre, Utility Centre)
- [ ] Each System module loads when selected (CLI, Settings)
- [ ] Favourites star toggles, and the project moves to the Favourites group
- [ ] Favourites persist across app relaunch

### Why Panel

- [ ] Reality "Why" shows positive + negative contributions
- [ ] Verification "Why" shows linked evidence + history
- [ ] Risk "Why" shows linked evidence + decisions + mitigation
- [ ] Release "Why" shows blockers + release-blocking risks
- [ ] Sections expand and collapse without layout jitter

### Workspace Health

- [ ] Renders without errors when projects exist
- [ ] Category chips filter correctly
- [ ] Critical / High / Other badges render with correct counts
- [ ] Each issue expands to show Detail + Recommendation
- [ ] "All Clear" empty state renders when no issues

### Workspace Doctor

- [ ] Diagnoses without errors
- [ ] Detects a manually-introduced broken cross-link
- [ ] Detects duplicate verification areas
- [ ] "No integrity issues found" empty state renders correctly

### Release Blocking Chain

- [ ] Renders for a project with failed verifications
- [ ] Tree indentation is readable at depth ≥ 2
- [ ] Clicking a node navigates to the correct module
- [ ] "No blockers" empty state renders when the project is clean

### Saved Views

- [ ] Default saved views appear in the sidebar (Blockers, Open Risks, etc.)
- [ ] Selecting a view shows matching records
- [ ] Pin / unpin toggles the pinned section
- [ ] Custom saved views persist across relaunch

### Backup Centre

- [ ] "Create Backup" creates a file in `~/Library/Application Support/LocalForge/Backups/`
- [ ] Backup list shows newest first with size and timestamp
- [ ] "Export Workspace…" produces a JSON file at the chosen path
- [ ] "Import Workspace…" round-trips back into the workspace
- [ ] Restore confirmation alert appears before destructive action
- [ ] Backup rotation keeps at most 5 backups (verify by creating 6)

### Build History

- [ ] "Log a build" form persists a new BuildRecord
- [ ] List shows builds newest first with result icon, duration, notes
- [ ] Result icon colour matches outcome (green/red/orange)

### Dev Tools

- [ ] Dev Tools module loads from Operations
- [ ] Swift Build preset runs only against the selected project root
- [ ] Swift Test preset records BuildRecord, TestRecord, and EvidenceRecord output
- [ ] Git Status preset shows read-only status output and does not modify the repository
- [ ] Codesign Verify and Gatekeeper Check require a selected `.app` bundle
- [ ] Environment Capture creates an EnvironmentSnapshot and evidence record
- [ ] No free-form command field is present
- [ ] Blocked/failed command output is visible and copyable

### Test Registry

- [ ] Empty state renders when the selected project has no test records
- [ ] "Add Test Record" saves a Manual/Automated/Regression/Integration/Host record
- [ ] Editing a record updates it in place rather than duplicating it
- [ ] Passed / Failed / Blocked / Skipped / Unknown outcomes show clear release impact
- [ ] Linked verification area picker shows the active project's verification areas
- [ ] Copy summary writes the selected test record summary to the clipboard

### Environment Registry

- [ ] Empty state renders when the selected project has no environment snapshots
- [ ] "Capture Environment" creates a snapshot only on explicit click
- [ ] Snapshot cards show macOS, Xcode, Swift, SDK, and auval fields
- [ ] Two or more snapshots show a latest-vs-previous comparison
- [ ] Copy summary writes the selected environment snapshot summary to the clipboard

### Diagnostic Background

- [ ] Settings toggle disables and re-enables the diagnostic rain background
- [ ] Intensity picker visibly changes the background strength without hurting readability
- [ ] Density picker changes the fixed-grid fill level without token overlap
- [ ] Motion picker switches between Still, Slow, and Medium continuous vertical motion
- [ ] Light mode remains readable with the background faint
- [ ] macOS Reduce Motion freezes the animation

### Utility Centre

- [ ] Section switcher works (Security / Build / Repository / Environment)
- [ ] Target Path field accepts a path and `Choose…` opens the picker
- [ ] Security actions run and emit output (try Quarantine Inspector on
      `dist/LocalForge.app`)
- [ ] Build → DerivedData Size runs without a path
- [ ] Repo → Git Health runs against the project root
- [ ] Environment → Capture creates an EnvironmentSnapshot for the active project
- [ ] Result panel scrolls and shows monospaced output

### Project Review Mode

- [ ] "Start Review" opens the question list
- [ ] Each answer can be edited
- [ ] "Complete Review" creates journal entries (verify via Project Journal)
- [ ] Cancel discards the session without journaling

### General polish

- [ ] No clipped text on narrow window widths
- [ ] No invisible controls in dark mode
- [ ] No invisible controls in light mode
- [ ] Keyboard focus moves predictably with Tab
- [ ] No console errors during normal navigation (run with `--logs`)

---

## Reporting

When the checklist is run, capture results in a dated entry under
[09_Verification_Ledger.md](09_Verification_Ledger.md) with one line per failure
and the run date. Pass-only runs need a single line:
`YYYY-MM-DD — Runtime Validation Checklist: all items green.`

## 2026-06-11 Phase 9D Status

- Machine-verifiable build/test/launch/codesign checks passed with the Xcode toolchain and project-local cache.
- Plain sandboxed `swift build` / `swift test` still fails during manifest planning with `sandbox-exec: sandbox_apply: Operation not permitted`; rerunning outside the Codex sandbox with the documented Xcode toolchain command succeeds.
- `./script/build_and_run.sh --verify` launched and re-signed the current `dist/LocalForge.app` bundle.
- `codesign --verify --deep --strict dist/LocalForge.app` passed.
- Logged launch showed the current bundle path and no LocalForge-specific SwiftUI duplicate-ID/runtime fault in the captured sample.
- Human-verifiable items remain open for the operator: Diagnostic Background readability/settings persistence, Test Registry add/edit/save, Environment Registry capture/compare, Utility Centre tool click-through, Backup export/import/restore, and light/dark/Reduce Motion visual checks.
