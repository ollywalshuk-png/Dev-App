# Known Issues

- Security-scoped bookmark persistence is implemented with clear stale/missing/failure states, but hardened app sandbox entitlements and App Store packaging are not yet configured.
- Scanner is metadata-focused and does not yet parse Xcode, SwiftPM, build logs, or secrets deeply.
- FSEvents incremental monitoring is not implemented yet.
- SQLite storage is implemented as the default backend; full human migration with pre-Phase-8 live data remains environment-dependent and is covered by tests.
- Project identity now includes marker-based kind detection (Xcode/SwiftPM/AUv3/Node/Python/Rust/Go) via `ProjectClassifier`. Deeper identity (target/scheme/platform parsing from pbxproj) is still deferred.
- `GitEngine` shells out to `git` via `Process`. This works in the unsandboxed V1 build. A future App Store (sandboxed) build will need an alternative, because subprocess launch is restricted; the engine already degrades gracefully (returns "not a repository") when `git` is unavailable.
- AUv3 detection is a heuristic (Info.plist `AudioComponents` / `.appex`) and is labelled Inferred, not Verified.
- Test Registry is a read-only record keeper in Phase 9B; the separate Testing foundation stub is still not an automated runner.
- Environment Registry captures only on explicit user action; no Repo Monitor, whole-disk watch, or background polling is implemented.
- Source control has been restored and the repository has a committed `main` baseline. Future repository changes still need explicit branches, reviewable commits, and pull requests; LocalForge itself must not auto-commit, auto-push, auto-merge, or rewrite Git history.
- Full UI validation is still partly human-only: Codex can build, launch, check codesign, inspect logs, and review source/tests, but cannot reliably click through macOS native panels and visual readability states without operator confirmation.
- Build Intelligence is still manual in V1: Build History can record and promote successful builds into evidence, and Dev Tools can run preset build/test commands only on explicit click. There is no automated runner, daemon, polling loop, or free-form terminal.
- V1.6 recommendations are approval metadata only. LocalForge can flag a source file over 1,750 lines and suggest a refactor direction, but it does not rewrite, split, or fix files automatically.
- `script/notarize.sh` is scaffolded, but actual Developer ID signing/notarisation requires operator credentials and explicit `--submit`.
