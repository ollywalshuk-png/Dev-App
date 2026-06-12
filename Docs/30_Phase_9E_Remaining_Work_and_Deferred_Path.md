# Phase 9E — Remaining Work and Deferred Path

Date: 2026-06-11

## What remains before release-quality work

1. Keep source control clean.
   - State: resolved after the Phase 10D/10E baseline. The repository now has a committed `main` baseline.
   - Allowed next actions: create focused branches, commit reviewable chunks, and open pull requests.
   - Still prohibited in LocalForge runtime: auto-commit, auto-push, auto-merge, destructive Git automation, or history rewriting.

2. Complete human UI validation.
   - Diagnostic background settings and readability.
   - Light/dark and Reduce Motion.
   - Utility Centre click-through.
   - Backup/export/import/restore.
   - Test Registry add/edit/save.
   - Environment Registry capture/compare.

3. Distribution signing.
   - `script/notarize.sh --check` is available and non-mutating.
   - `script/notarize.sh --submit` requires Developer ID credentials and explicit operator intent.

## Safe capability path

The current app already has manual, read-only foundations for several deferred areas:

- Build Intelligence V1: Build History records manual build observations and successful builds can be promoted into Build evidence.
- Dev Tools V1: preset-only project-scoped commands can run Swift Build, Swift Test, Git Status, Codesign Verify, Gatekeeper Check, and Environment Capture. Results feed existing Build/Test/Evidence/Environment records.
- Repo awareness V1: explicit project scans capture read-only Git status through `GitEngine`.
- Bloat review V1: Utility Centre can manually inspect large files for a selected target.
- Environment Registry V1: snapshots are captured only on explicit click.

## Still deferred by design

- Free-form terminal / arbitrary command execution.
- Full Build Intelligence command orchestration beyond the approved preset list.
- Full Repo Monitor or FSEvents watcher.
- Runtime daemon.
- Background polling.
- Whole-disk scanner.
- Automatic fixes.
- Automatic repository modification.
- AI systems.

## Guardrails for any future implementation

- User initiated only.
- Selected project only.
- Read-only by default.
- No background loops.
- No whole-disk scope.
- No source/repo modification without explicit confirmation, preview, and rollback story.
- Feed existing evidence, verification, reality, and release-readiness models instead of creating parallel systems.
