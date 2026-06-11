# Codex Handoff — Phase 9A → 9B

Date: 2026-06-11
From: Claude (Phase 9A Utility Centre stabilisation)
To: Codex (remaining stabilisation + Phase 9B gaps)
Repo: `/Users/studiomacmini/Desktop/App assets/Dev App` (SwiftPM, macOS 14+)

---

## 0. Ground rules (still in force)

- **Feature freeze on new subsystems.** Finish/refine what exists. Do not invent
  new engines, models, or sidebar modules unless a gap below explicitly needs one.
- **Reuse > extend > create.** Inspect before adding. Avoid parallel truth sources.
- **Local-first, read-only by default.** No AI, telemetry, cloud, hosted backend,
  auto code/repo modification, or background polling.
- **"Compiles" ≠ "works".** A change is done only when it builds, launches, and the
  behaviour is observed. Engine-level behaviour is machine-verifiable; UI rendering
  is human-verifiable (operator must click).

## 1. Build / test / verify commands (this machine)

Plain `swift build`/`swift test` fail here (Command Line Tools SDK mismatch +
sandboxed module cache). Always use:

```bash
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=.build/ModuleCache \
  swift build --cache-path .build/swiftpm-cache

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
  CLANG_MODULE_CACHE_PATH=.build/ModuleCache \
  swift test --cache-path .build/swiftpm-cache
```

Bundle + launch + sign (script already does the codesign re-seal):

```bash
./script/build_and_run.sh --verify
codesign --verify --deep --strict "dist/LocalForge.app"
```

Notes:
- The `swiftpm-testing-helper` dlopen failure (path-with-spaces) is **intermittent**.
  Running `--build-tests` first, then `swift test`, has worked. If it recurs, report
  honestly; tests still compile and the binary is built.
- `spctl -a` will **always** fail for this adhoc bundle — that's expected, not a
  defect. It only passes with Developer ID + notarisation (distribution phase).

## 2. Current state (verified green as of 2026-06-11)

- Build: clean, no warnings.
- Tests: **69 pass, 3 suites** (incl. 10 new Utility Centre tests).
- Launch: `--verify` exit 0, process stays up.
- Codesign: `--verify --deep --strict` PASS.

Phase 8.5 / 9 implemented & wired: Command Palette (⌘K), Why Panel, Workspace
Health, Workspace Doctor, Saved Views, Backup Centre, Build History, Utility
Centre, Project Review, favourites/pinning. Utility Centre hang is fixed (see
`26_Runtime_Validation_Checklist.md` and the Phase 9A report).

Key files:
- Engines: `Sources/LocalForgeCore/Engines/{UtilityCentreEngine,WhyEngine,WorkspaceHealthEngine,WorkspaceDoctorEngine,BackupEngine,CommandPaletteEngine}.swift`
- Models: `Sources/LocalForgeCore/Models/Phase85Models.swift`
- Store: `Sources/LocalForgeApp/Stores/WorkspaceStore.swift`
- Views: `Sources/LocalForgeApp/Views/{Phase85Views,CommandPaletteView,WhyPanelView,WorkspaceHealthView,WorkspaceDoctorView,ReleaseBlockingChainView}.swift`
- Module routing: `Sources/LocalForgeApp/Support/WorkspaceModule.swift`, `Views/MainWorkspaceView.swift`, `Views/SidebarView.swift`

---

## 3. Work queue (priority order)

### P1 — Operator runtime validation (blocking gate, human)
Run `./script/build_and_run.sh --logs`, walk `Docs/26_Runtime_Validation_Checklist.md`,
record defects in `Docs/Validation_Run_2026-06-10.md`. This is the source of truth
for what to fix next. **Do not start P3+ feature gaps until this list is triaged.**
Manual Utility Centre retest specifically: Gatekeeper Check, Remove Quarantine
(read-only gating + approval), Bundle Inspector vs repo-root target error, Large
File Finder grouping, Empty Folder noise filtering, navigation after running tools.

### P2 — Fix defects surfaced by P1
Fixes only, in severity order (Critical → High → Medium → Low). Re-run §1 commands
after each batch. Categorise A=UI layout, B=navigation, C=persistence, D=runtime.

### P3 — Phase 9B functional gaps (the "other stuff")
These have models + store + persistence already; they lack dedicated UI/routes.
**Extend, don't recreate.**

1. **Test Registry UI.** Model `TestRecord` + store methods `testRecords(for:)` /
   `addTestRecord(_:for:)` exist (`Phase85Models.swift`, `WorkspaceStore.swift`).
   Missing: a routed screen. Add a `WorkspaceModule` case + route in
   `MainWorkspaceView`, a view in `Phase85Views.swift` style. Show kind (Manual/
   Automated/Integration/Regression/Host), outcome, linked verification area,
   linked evidence; allow add/edit; link to Verification + Release Readiness.
2. **Environment Registry UI (dedicated).** `EnvironmentSnapshot` model + store
   methods exist; capture is currently only inside Utility Centre → Environment.
   Add a dedicated screen: snapshot history, fields (macOS/Xcode/Swift/SDK/AUVal),
   and a comparison view between two snapshots. Reuse `captureEnvironment()`.
3. **Engine-side utilities named in spec but not implemented** (only add if P1
   demands them): Build Cleaner, Build Log Viewer, Duplicate Asset Finder. If
   added, they must follow the Utility Centre contract: async `run()`, timeout,
   semantic `UtilityResult`, read-only gating for any mutation. Do **not** stub
   buttons that do nothing.

### P4 — Test coverage expansion (target 50–100 meaningful tests)
Critical first: persistence round-trip edge cases, backup restore, import/export
mismatch, build-history→evidence promotion, workspace doctor detections. Then
nice-to-have: search ranking, saved views, favourites, Why engine. Pattern:
`Tests/LocalForgeCoreTests/*Tests.swift`, swift-testing `@Suite`/`@Test`.

### P5 — UX polish (human-led, then code)
From validation findings: window resizing, dark/light contrast, empty states,
keyboard focus/tab order, long-text wrapping, scroll behaviour. No redesign.

### P6 — Release engineering (separate project; needs operator credentials)
Not startable by an agent alone — requires Apple Developer account, Developer ID
identity in Keychain, app-specific password / notarytool API key. When available:
Developer ID sign → `notarytool submit` → `stapler staple` → re-verify with
`spctl -a -vv` on a clean machine. Optionally scaffold a `script/notarize.sh`
now so it's ready, but leave it inert without credentials.

---

## 4. Known caveats / non-defects (don't "fix" these)

- `spctl -a` failing on the adhoc bundle is expected (see §1).
- `com.apple.provenance` xattr on the bundle is a benign macOS marker, not quarantine.
- Build History records are intentionally **"recorded, not verified"** — promotion to
  evidence is a deliberate manual step via the "Promote to Evidence" button.
- Utility Centre mutating actions (Remove Quarantine, Clean DerivedData) are
  approval-gated by design; default is read-only.

## 5. Definition of done for this handoff

- P1 validation report exists with triaged defects.
- All P2 defects fixed; §1 build/test/launch/codesign all green.
- Test Registry UI and dedicated Environment Registry UI routed and exercised.
- Test count materially up with meaningful (not trivial) assertions.
- No new unrelated subsystems introduced; feature freeze respected.
- Final report: files changed, root causes, tests added, build/test/launch/codesign
  results, manual retest results, remaining/deferred items.
