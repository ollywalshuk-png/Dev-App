# Phase 10E - Roadmap Consolidation, Release Baseline, and Next Capability Plan

Date: 2026-06-12

Status: documentation, validation, and planning baseline. This phase does not
claim implementation of the future roadmap items below.

## Current Repository Baseline

Source control is restored. The baseline branch is `main` with these commits:

- `e848a4b` - `chore: establish LocalForge repository baseline`
- `fc09f5f` - `feat(core): add LocalForge intelligence engines`
- `32c7b58` - `feat(app): add LocalForge command centre UI`
- `89257a0` - `test: add LocalForge core coverage`

Continuation work should happen on focused branches and be sent back through
reviewable pull requests. LocalForge itself still must not auto-commit,
auto-push, auto-merge, or modify repository history.

## Machine Validation Baseline

Observed on 2026-06-12:

- `git status -sb` was clean before this documentation pass.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift build --cache-path .build/swiftpm-cache` passed.
- `DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift test --cache-path .build/swiftpm-cache` passed with 82 Swift Testing tests across 5 suites.
- `./script/build_and_run.sh --verify` passed and re-signed `dist/LocalForge.app`.
- `codesign --verify --deep --strict --verbose=2 dist/LocalForge.app` passed.
- `codesign -dv --verbose=4 dist/LocalForge.app` shows an ad-hoc signature. Developer ID signing is still deferred to the release engineering phase.

Known compiler warnings at this baseline:

- `ReleaseReadinessEngine.swift` has an unused `priorityByArea` local.
- `GitEngine.swift` has Swift concurrency warnings around captured mutable pipe data.

These warnings are not part of the Phase 10E documentation scope. They should be
handled in a small follow-up code-quality PR if desired.

## Implemented State

Implemented and validated foundations include:

- LocalForgeCore.
- LocalForgeApp.
- LocalForgeCLI.
- Docs ledgers.
- Tests.
- Mission, Verification, Evidence, Reality workflow.
- Knowledge Vault.
- Test Registry.
- Environment Registry.
- Dev Tools.
- Utility Centre.
- Build History.
- Diagnostic background.
- Recommendation system.
- Approval states.
- Code bloat scanner over 1,750 lines.
- Evidence and journal logging.
- Git repository baseline.
- More visible diagnostic code background with accent-tinted fixed-grid streams.

## Deferred State

The remaining items are roadmap-scale product work, not quick fixes:

- Full runtime intelligence.
- Full UI intelligence.
- Full build intelligence.
- Full repository intelligence.
- Automated test discovery and orchestration.
- System and environment health intelligence beyond explicit manual captures.
- Security intelligence beyond current local utility/report foundations.
- Expanded developer toolbox utilities.
- Apple development centre awareness.
- Agent centre records.
- Optional local-only AI summaries.

## Human Validation Still Needed

Phase 10F should complete the manual validation pass:

- Runtime validation pass.
- UI smoke test.
- Utility Centre no-hang test.
- Dev Tools preset test.
- Backup/export/import test.
- Settings persistence test.
- Diagnostic background visual review.

The detailed walk-through remains in `Docs/26_Runtime_Validation_Checklist.md`.

## Next Capability Roadmap

### Phase 10F - Manual Validation Completion

- Runtime validation pass.
- UI smoke test.
- Utility Centre no-hang test.
- Dev Tools preset test.
- Backup/export/import test.
- Settings persistence test.
- Diagnostic background visual review.

### Phase 11 - Release Engineering

- Release build checklist.
- Developer ID signing preparation.
- Notarisation script scaffold.
- Stapling checklist.
- Clean-machine verification guide.
- User guide.
- Troubleshooting guide.

See `Docs/34_Release_Engineering_Checklist.md`.

### Phase 12 - Build Intelligence

- Build trend history.
- Warning/error tracking.
- Build duration tracking.
- Failed build comparison.
- Recorded-but-unverified handling.
- No background daemon.

### Phase 13 - Repository Intelligence

- Manual repo health refresh.
- Branch/commit/tag summary.
- Large file tracking.
- Duplicate asset reporting.
- Stale artefact reporting.
- No automatic cleanup.

### Phase 14 - Test Intelligence

- Test discovery.
- Test inventory.
- Missing coverage hints.
- Failed test history.
- Manual promotion to verification evidence.

### Phase 15 - System / Environment Health

- Disk space warnings.
- DerivedData growth.
- Xcode version checks.
- Swift version checks.
- SDK availability.
- Signing certificate visibility.
- No constant polling.

### Phase 16 - Security Intelligence

- Secret scanning.
- Token/API key detection.
- Certificate detection.
- Local-only reports.
- No cloud upload.
- No automatic deletion.

### Phase 17 - Developer Toolbox

- JSON formatter.
- Regex tester.
- Base64.
- URL encode/decode.
- UUID generator.
- Hashing.
- Timestamp converter.
- Diff viewer.
- Colour / contrast tools.

### Phase 18 - Apple Development Centre

- Xcode scheme awareness.
- Swift package awareness.
- SwiftUI hierarchy awareness.
- AUv3 awareness.
- Instruments capture tracking.
- TestFlight readiness notes.
- Reality Composer Pro awareness.

### Phase 19 - Agent Centre

- Codex session records.
- Claude session records.
- ChatGPT handoffs.
- Prompt archive.
- Files changed.
- Verification result.
- Evidence-linked handoffs.

### Phase 20 - Optional Local AI Layer

- Local-only Foundation Models support only.
- No cloud AI unless explicitly approved.
- Summaries only.
- No automatic code modification.

## Safety Model

All future mutating actions must follow this sequence:

1. Observe.
2. Analyse.
3. Explain.
4. Recommend.
5. Preview.
6. Request approval.
7. Execute one approved action.
8. Record evidence.

Never use this sequence:

1. Observe.
2. Execute automatically.

Every risky action must show:

- Action type.
- Target path.
- What will change.
- Why it is recommended.
- Risk level.
- Rollback note.
- Whether source files are affected.
- Whether Git state will change.

## Safe Next Implementation Scope

Safe low-risk follow-ups:

- Roadmap docs.
- Release checklist docs.
- Validation checklist improvements.
- Clearer feature registry.
- Clearer known issues.
- Clearer handoff.
- Improved visual identity where it uses existing layout-safe rendering layers.
- Improved dashboard wording where it clarifies existing behaviour.
- Improved recommendation explanations where it clarifies existing behaviour.
- Tests for documentation-independent logic only.

Do not implement the full future phases in a single pass. Do not add cloud,
telemetry, paid APIs, AI, whole-disk scanning, destructive automation,
background polling, auto-fixes, auto-commits, or auto-pushes.
