# Feature Registry

Implemented:

- Workspace dashboard.
- Project tab strip.
- Repository open flow.
- Persisted approved-project list.
- Persisted scan mode, theme preference, and last active project.
- Security-scoped bookmark status and visible access warnings.
- Read-only scan.
- Findings/evidence views.
- Guardian panel.
- Copyable report.
- CLI scan/report/command assessment (scan prints detected type + Git branch/state).
- Project recognition (`ProjectClassifier`): type + confidence badges across tabs, sidebar, list, detail, Guardian.
- Read-only Git intelligence (`GitEngine`): branch, working-tree state, ahead/behind, last commit.
- Traffic-light health pills, Git chips, guided empty state, and Posture cards.
- Project subtype classification (SwiftUI/AppKit/UIKit App, AUv3 Instrument vs Effect, Framework, CLI Tool, Swift Package).
- Mission inference (`MissionProfileEngine`).
- Applicability matrix (`ApplicabilityEngine`) — which checks matter per project.
- Reality assessment (`RealityEngine`): known/verified/unverified/assumed/unknown, reality score, verification chain, top risks, next action.
- Command Centre dashboard + "Copy Brief" handoff.
- Mission-aware Guardian.
- Mission Profile Editor (user-defined mission, goals, phase, known issues; persisted).
- Verification tracking per area (Verified/In Progress/Failed/Unknown) with notes; persisted; "Verification" module.
- Reality score and verification chain driven by real verification records.
- Project Setup Wizard for newly opened repositories.
- Verification timeline with date, note, status, and verifier.
- Knowledge Vault local notes (known issues, decisions, architecture notes, release notes, lessons learned).

Phase 5–6.5 (PromptForge, Journal, Command Centre maturity):

- PromptForge handoffs (`PromptForgeEngine`): Codex/Claude prompt, human handoff, fix proposal, comprehensive pack; redaction-aware.
- Verification priorities + ageing (`VerificationAge` trust decay) feeding Reality.
- Project Journal (`JournalEngine` + `JournalView`): append-only, capped, auto-entries for verification/mission/knowledge/setup.
- Verification dependencies (`dependsOn`) + "Blocked by" surfacing.
- Release Readiness board (`ReleaseReadinessEngine` + view): priority-grouped, Blocked/Not Ready/Ready with Caveats/Ready, Markdown release brief.
- Cross-project Workspace Insights (Healthy/Attention/Blocked; Highest Risk · Most Complete · Least Verified tiles).
- Command Centre cockpit strip.
- Guardian Latest Activity (journal/notes/evidence enrichment, blocked-by, linked counts).

Phase 7 (Evidence + Registers + Templates):

- Evidence Layer (`EvidenceRecord` + inline `EvidencePanel` under every verification row); evidence-aware Reality trust.
- Decision Register, Architecture Register, Risk Register, Assumption Register (`Registers` module, four tabs); risks/assumptions feed Reality.
- Mission Templates + Verification Packs (`MissionTemplateCatalogue`); Apply Pack from Verification; template strip in Mission editor.
- Handoff Pack appends Evidence + all four register sections.

Phase 7.5 (Truth System Consolidation):

- UUID cross-links on Evidence + all registers; one-way storage, bidirectional resolution (`TruthEngine.related(to:)`).
- 🔗 link menus + RELATED strips on register cards and evidence rows; auto-link evidence → verification record.
- Truth Centre module: Workspace Truth tab, Evidence Explorer (filters), Dependency Map (cycle-safe tree).
- Reality Breakdown (itemised contributions), Confidence Engine (evidence quality, separate from Reality), Register Health coverage.
- Cockpit tiles: Confidence · Evidence · Open Risks · Truth Cover.

Phase 8 (Truth System Foundation):

- SQLite persistence as the default backend (`SQLitePersistenceStore`): WAL, per-collection tables, automatic legacy migration, corruption recovery, `WorkspacePersisting` protocol seam.
- Universal Search module (`SearchEngine`): every record type, every project, kind filters, release-blocking toggle, click-to-jump.
- Timeline Replay module: journal as milestone timeline, replay (oldest-first) or triage (newest-first), kind filter.
- Portfolio Dashboard: cross-project truth counts (open/critical risks, evidence, journal, assumptions, stale) + jump tiles.
- Evidence Explorer maturity: author + since filters; Newest / Oldest / Highest confidence / Most linked sorts.
- Template & pack expansion: AUv3 MIDI Processor, Developer Tool, AV Utility, Media App, Automation Tool; matured AUv3/app pack dependency chains; `RiskSeed` suggested risks seeded on pack apply (duplicate-safe).
- Workspace JSON export / import (Settings → Workspace Data).

Phase 9B (Registry UI + visual polish):

- Test Registry module: manual/automated/integration/regression/host test records grouped by kind, editable outcomes including Blocked, linked verification area display, evidence count, release-readiness impact, copy summary.
- Dedicated Environment Registry module: manual environment capture using the existing Utility Centre engine, snapshot history, latest-vs-previous comparison, copy summary.
- Diagnostic rain background: local SwiftUI Canvas visual layer with persisted settings for enablement, intensity, and inactive-window reduction; respects reduced motion and remains light-mode aware.
- Phase 9B persistence coverage: environment snapshots and test records are included in the full SQLite round-trip fixture; diagnostic background settings decode from old workspaces with defaults.

Phase 9C (Professional polish):

- Diagnostic background settings expanded to Intensity (Off/Low/Medium/High), Density (Sparse/Balanced/Dense), and Motion (Still/Slow/Medium), all persisted locally.
- Diagnostic background renderer uses a fixed terminal-style grid: fixed lanes, fixed rows, padded/truncated code tokens, smooth vertical offset, one token per cell, and head/tail replacement rather than overlay.
- Command Centre surfaces a build-recorded-but-not-verified nudge when successful builds exist without Build verification.
- CLI Companion screen now explains read-only scope, available commands, destructive-command blocking, and copy feedback.
- Test Registry and Environment Registry include clearer helper panels describing manual evidence/capture boundaries.

Phase 9D / release hardening:

- Build Intelligence V1 remains manual and read-only: Build History records build observations and successful records can be promoted into Build evidence without running commands or modifying repositories.
- Repo awareness remains manual and read-only: Git state is captured through `GitEngine` during approved project scans; no Repo Monitor, FSEvents daemon, or polling loop is active.
- Bloat review remains bounded to the selected target through Utility Centre's manual Large File Finder; no whole-disk scanner exists.
- Developer ID notarisation is scaffolded through `script/notarize.sh`; default `--check` mode is non-mutating, while `--submit` requires explicit credentials and operator intent.

Phase 10A (Preset Dev Tools):

- Dev Tools module: preset-only, selected-project-scoped development command runner.
- Added safe command presets: Swift Build, Swift Test, Git Status, Codesign Verify, Gatekeeper Check, Environment Capture.
- Added `DevToolsCommand` / `DevToolsCommandResult` models and `DevCommandEngine` allowlist/blocklist enforcement.
- Commands run without a shell string; executable and arguments are explicit and preset-controlled.
- Output is captured locally into existing records:
  - Swift Build -> BuildRecord + EvidenceRecord.
  - Swift Test -> BuildRecord + TestRecord + EvidenceRecord.
  - Git Status / Codesign / Gatekeeper -> EvidenceRecord.
  - Environment Capture -> EnvironmentSnapshot + EvidenceRecord.
- No automatic fixes, no automatic repository modification, no background polling, and no whole-disk scan were added.

Phase 10B (Professional explanation layer + roadmap integration):

- Added a shared explanation pattern across major screens so each module states what it is, why it matters, what to do next, and whether it changes the project.
- Command Centre now frames the Project -> Mission -> Verification -> Evidence -> Reality -> Risk -> Release -> Handoff workflow.
- Reality cockpit strip now exposes In Progress and Recorded-but-Unverified counts alongside Verified, Failed, and Unknown.
- Mission, Verification, Evidence/Truth, Guardian, Release Readiness, Test Registry, Environment Registry, Dev Tools, Utility Centre, Build History, Backup Centre, Knowledge Vault, CLI Companion, and Settings now carry clearer novice-friendly guidance.
- Added `Docs/31_V1_5_Development_Intelligence_Roadmap.md` to document future development intelligence, QA, validation, system health, safe-fix workflow, and developer tooling capability categories without claiming implementation.

Phase 10C / V1.6 (Safe intelligence + approval framework foundation):

- Added Recommendations module under Operations.
- Added per-project `RecommendationRecord` metadata with explicit approval states: Open, Acknowledged, Approved, Rejected, Completed.
- Added `CodeBloatScannerEngine`, a selected-repository-scoped scanner for source files over 1,750 lines of code.
- Code-size findings become recommendations with target path, evidence summary, impact, suggested adjustment, safety warning, rollback note, and source-file impact flag.
- Recommendation state changes create evidence and journal entries.
- Approval records intent only; no automatic code rewrite, file split, commit, push, delete, merge, daemon, or background polling was added.
- Added `Docs/32_Phase_10C_V1_6_Safe_Intelligence_and_Approval_Framework.md`.

Phase 10E (Roadmap consolidation and release baseline):

- Added a stable roadmap and validation baseline in `Docs/33_Phase_10E_Roadmap_Release_Baseline.md`.
- Added the Phase 11 release engineering checklist in `Docs/34_Release_Engineering_Checklist.md`.
- Clarified that source control is restored and future work should use reviewable branches/PRs.
- Re-stated the human validation items still needed before any release-quality claim.
- Re-stated the approval-gated safety model for future mutating actions.
- Increased the diagnostic code background's visual identity with stronger intensity levels, accent-tinted fixed-grid streams, larger tokens, and less aggressive light-mode dimming while preserving Reduce Motion, inactive-window reduction, and non-interactive rendering.
- No runtime feature, auto-fix, auto-commit, auto-push, cloud, telemetry, AI, daemon, or whole-disk scanning capability was added.

Developer trust planning docs:

- Added `Docs/35_Developer_Trust_Strategy.md` to define LocalForge's market-grade developer trust contract and Truth Centre percentage/provenance role.
- Added `Docs/36_Truth_Centre_Stress_Plan.md` to define measurable stress gates for future Truth Centre accuracy claims.
- Added `Docs/38_Developer_Tools_Market_Positioning.md` to define LocalForge's developer-tools market category, true current claims, anti-claims, and Truth Centre positioning.
- No runtime feature or scoring change was added by these documents.

Local secret scan foundation:

- Added `SecretScannerEngine`, a selected-repository-scoped, local-only scanner
  for credential-like assignments, provider-token-shaped strings, embedded URL
  credentials, and private-key headers.
- Secret scan findings store only path, line, kind, severity, reason, and a
  redacted preview. Matched credential values are not persisted.
- Findings can become Safety recommendations that instruct manual removal,
  rotation, and Keychain/environment/untracked-config handling.
- Added `Docs/37_Local_Secret_Scan_Foundation.md`.
- No automatic deletion, history rewrite, credential rotation, commit, push,
  cloud upload, daemon, or background scan was added.

Foundation stubs (deferred by design):

- Free-form terminal / arbitrary command execution.
- Testing runner / automated test orchestration.
- Runtime Intelligence.
- UI Intelligence.
- Repo Monitor / whole-disk Bloat / Security Review / AI systems.
