# Agent Handoff

Start here:

1. Read the mandatory ledger docs.
2. Run `swift test` before changing behavior.
3. Keep implementation in the existing package structure.
4. Do not add external services to core functionality.
5. Preserve V1 read-only boundaries.
6. Preserve explicit project selection. Do not infer active project from the whole disk or hidden background scans.
7. Project recognition lives in `LocalForgeCore/Engines/ProjectClassifier.swift`; read-only Git in `GitEngine.swift`. Both are surfaced on `RepoSnapshot` (`identity`, `git`). Keep them read-only and bounded.
8. `GitEngine.run` drains both pipes concurrently with an 8s watchdog — do not revert to a single synchronous `readDataToEndOfFile`, which deadlocks on stderr.
9. Cross-links (Phase 7.5) are stored **one-way** on whichever record the user linked from; `TruthEngine.related(to:)` resolves both directions plus area-name bridges. Do not add reciprocal writes — that reintroduces desync. `VerificationRecord` intentionally stores no link arrays.
10. All persisted models decode new fields with `decodeIfPresent` + defaults. Any new field must follow the same pattern or old workspaces fail to load.
11. Persistence is **SQLite** as of Phase 8 (`SQLitePersistenceStore`, `~/Library/Application Support/LocalForge/workspace.sqlite`, WAL). Whole-state transactional writes; Codable JSON payload columns are the source of truth. The `WorkspacePersisting` protocol is the seam — UserDefaults remains the fallback and the test double. First launch on a machine with pre-Phase-8 data migrates automatically and keeps the old blob; never delete it in this release.
12. When adding a persisted collection to `PersistedProjectRecord`, also add its table + save/load wiring in `SQLitePersistenceStore` (and keep `position` ordering), or the new data silently won't persist.
13. Phase 9B added routed Test Registry and Environment Registry screens using existing `TestRecord` / `EnvironmentSnapshot` models and store methods. Keep the separate `testing` module as a future automated-runner stub; do not merge it with the registry record keeper.
14. Diagnostic rain is a local visual layer only (`DiagnosticRainBackground`) and is controlled by persisted `ThemePreferences`. Phase 9C settings are enablement, Intensity, Density, Motion, and reduce-when-inactive. It must remain fixed-grid, low-rate, disableable, non-overlapping, and respectful of Reduce Motion.
15. Source control is restored. The baseline `main` branch contains the four initial LocalForge commits listed in `Docs/33_Phase_10E_Roadmap_Release_Baseline.md`. Keep future work on focused branches and use reviewable PRs. LocalForge runtime code must still not auto-commit, auto-push, auto-merge, or rewrite repository history.
16. Phase 9E records the remaining-work path in `Docs/30_Phase_9E_Remaining_Work_and_Deferred_Path.md`. Build Intelligence V1 is manual Build History -> Evidence promotion; automated command execution remains deferred.
17. Phase 10A adds Dev Tools as preset-only command execution. Keep it selected-project-scoped, explicit-argument only, no shell strings, no automatic fixes, and no free-form terminal. Command output must feed existing evidence/build/test/environment records rather than parallel stores.
18. New Phase 10A tests exist in `DevCommandEngineTests.swift`; rerun `swift test` when the sandbox/approval limit allows. The app build and launch path already compiles the product.
19. Phase 10B adds the novice explanation layer using `ExplanationCard` in `Components.swift`. Reuse that component for future module guidance instead of inventing one-off helper panels.
20. V1.5 Development Intelligence is documented in `Docs/31_V1_5_Development_Intelligence_Roadmap.md`. Treat it as roadmap unless a capability is already implemented and only needs explanation or polish.
21. Phase 10C adds Recommendations as a safe-intelligence foundation. `CodeBloatScannerEngine` is repo-scoped and read-only; it flags source files over 1,750 lines and creates `RecommendationRecord` metadata. Approval states record user intent only and must not be treated as permission to execute arbitrary fixes.
22. Phase 10E records the current validation baseline, human validation backlog, and Phase 10F-20 capability roadmap in `Docs/33_Phase_10E_Roadmap_Release_Baseline.md`. Phase 11 release engineering lives in `Docs/34_Release_Engineering_Checklist.md`.
23. Developer trust strategy lives in `Docs/35_Developer_Trust_Strategy.md`; developer-tools market positioning lives in `Docs/38_Developer_Tools_Market_Positioning.md`; Truth Centre stress gates live in `Docs/36_Truth_Centre_Stress_Plan.md`. Treat them as product/test guidance until implemented and verified.
24. `SecretScannerEngine` is a Phase 16 foundation slice. It is selected-repository-scoped, local-only, redacts matched values, and creates Safety recommendations only. Do not turn it into background scanning, automatic deletion, history rewriting, credential rotation, cloud upload, commit, or push automation.
25. Upstream release handoff lives in `Docs/39_Upstream_Release_Handoff.md`. Use it only as a permission and evidence checklist for moving notarised fork releases upstream; never add Apple, GitHub, CI, or signing secrets to repo docs.

Useful commands:

```bash
env DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer CLANG_MODULE_CACHE_PATH=.build/ModuleCache swift test --cache-path .build/swiftpm-cache
./script/build_and_run.sh --verify
script/notarize.sh --check
```
