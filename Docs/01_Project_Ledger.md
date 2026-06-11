# Project Ledger

## Current V1 Slice

- SwiftPM package with `LocalForgeCore`, `LocalForgeApp`, and `LocalForgeCLI`.
- macOS SwiftUI control-room UI.
- Explicit Open Repository flow through `NSOpenPanel`.
- Persisted approved-project records with security-scoped bookmark data where macOS allows it.
- Persisted scan mode, theme preferences, and last active project.
- Visible bookmark states: saved, active, stale, missing, failed, or session-only.
- Read-only scanner that summarizes local project metadata.
- Evidence-classified findings.
- Developer Guardian recommendation panel.
- Copyable Markdown reports with basic redaction.
- Command safety assessor that blocks mutating Git and destructive shell commands.
- Read-only project recognition (`ProjectClassifier`): Xcode, Swift package, AUv3 plugin, Node/web, Python, Rust, Go, or unidentified.
- Read-only Git intelligence (`GitEngine`): branch/detached HEAD, working-tree state, ahead/behind, last commit — with a watchdog so a scan can never hang on Git.

## Recognition & Intelligence Pass (2026-06-07)

- Added `ProjectClassifier` and `ProjectIdentity`: LocalForge now identifies what each opened folder actually is, shown as badges in tabs, sidebar, project list, detail, and Guardian.
- Added `GitEngine` and `GitStatus`: structured read-only Git state surfaced as evidence and findings (detached HEAD, uncommitted changes, behind upstream).
- GUI upgrade: traffic-light health pills, project-type badges, Git chips, a guided empty state explaining repo input, and an honest Posture card row.
- Fixed a Foundation pipe-buffer deadlock in the Git subprocess (concurrent pipe drain + 8s watchdog + non-interactive Git env).
- Tests: 7 → 10 (added classifier, AUv3 detection, and Git non-repo coverage).

## Phase 2 — Project Understanding (2026-06-07)

Pivot from repository metrics (Product A) to a developer command centre (Product C).

- `MissionProfileEngine`, `ApplicabilityEngine`, `RealityEngine` added (read-only, no deps).
- `ProjectClassifier` refined into real subtypes: SwiftUI/AppKit/UIKit App, AUv3 Instrument vs Effect, Framework, CLI Tool, Swift Package.
- `RepoSnapshot` now carries `mission`, `applicability`, and `reality`.
- Workspace dashboard leads with a **Command Centre**: Current Project · Type · Mission · State · Reality Score · Verification Status · Top Risks · Next Action. Includes a "Copy Brief" for agent handoff.
- Guardian panel is mission-aware (mission + reality score + reality-driven next action).
- CLI `scan` and Markdown reports now include mission, reality score, top risk, and next action.
- Tests 10 → 12 (applicability scoping, honest reality scoring). All green.

## Phase 3 — Mission & Verification (2026-06-07)

Stopped adding scanning engines; made the three understanding pillars real instead of guessed.

- **Mission Profile Editor**: user defines mission, category, goals, current phase, and known issues per project (`UserMissionProfile`). Persisted; overrides the inferred guess (shown as Observed, not Inferred).
- **Verification Tracking** (`VerificationEngine` + `VerificationView`): per-area records (Verified / In Progress / Failed / Unknown) seeded from the applicability matrix, editable with notes, persisted. New "Verification" sidebar module.
- **Reality Engine now consumes real truth**: verified areas → verified bucket; failures → top risks + next action; known issues → risks; score is driven by verification coverage (only a fully verified, failure-free project can reach 100); verification chain (`Functional`/`Tested`/`Observed`/`Verified`) reflects records.
- Command Centre gained Define/Edit Mission, goals, current phase, verification counts, and a richer Copy Brief (mission, phase, goals, verification, risks, next action).
- Persistence is backward compatible: new fields are optional so older saved state still loads.
- Tests 12 → 15 (verification reconcile, reality-from-verification, mission/verification persistence). All green.

## Phase 4 — Workflow & UX (2026-06-07)

Focused on making Mission -> Verification -> Reality usable instead of adding more engines.

- **Project Setup Wizard** appears after a new project scan. It walks through detected project type, mission, current phase, verifier, and in-scope verification areas generated from the applicability matrix.
- **Verification Timeline** added to the Verification module. Records now include `verifiedBy` and date/time, so entries read like "Preset System — Failed — 7 June 2026 — Verified by Oliver".
- **Knowledge Vault** is now a real local project notebook for known issues, decisions, architecture notes, release notes, and lessons learned. Known Issue notes feed Reality risks.
- Persistence updated for knowledge notes and verifier metadata; older verification records decode with an empty verifier.
- Tests 15 -> 17 (setup draft materialization, verification timeline ordering/verifier, knowledge persistence). All green.

## Phase 5 — Intelligence & Density (2026-06-07)

Made the existing workflow more useful instead of adding scanning engines.

- **PromptForgeEngine** (new, in `LocalForgeCore`) — synthesises Codex prompts, Claude prompts, Fix Proposals, Reviewer Briefs, and a Comprehensive Handoff Pack from the project's real state (identity · mission · applicability · verification · knowledge · reality). Each section is independently copyable.
- **Handoff** module (new sidebar entry, `HandoffView`) — picker over five artefacts, live preview, per-section copy buttons; char + word counts for handoff-size discipline.
- **Guardian rewrite** — now fills **Top Issue · Status · Evidence · Impact · Suggested Action · Verified By**. Failed verification → critical/area-specific suggested fix; known issues → warning with context; required-but-unverified → unverified state with explicit suggestion.
- **Guardian copy actions**: "Copy Guardian Summary", "Copy Fix Proposal" (uses PromptForge), and a one-click jump to the Handoff Pack.
- **Bigger, denser hero**: 38pt project title, 46pt Reality score badge, dense `StatCell` strip (Files · Source · Tests · Docs · Large · In Scope · Coverage · Scanned-ago). Information density up, font visibility up.
- **Sidebar focus**: implemented Command Centre modules first; foundation stubs collapsed behind a "Show foundation stubs" toggle so deferred items don't compete for attention. `WorkspaceModule.isImplemented` is the source of truth.
- **Goals Coverage doc** (`Docs/21_Goals_Coverage.md`) — explicit pass/partial/deferred mapping against the original 130-point spec and every phase. Vision alignment ~80%.
- Tests 17 → 20. New: Guardian failed-verification surfacing, PromptForge artefact generation across all five types, Fix Proposal centring on the failed area with diagnostics + rollback.

## Phase 6 — Workflow Maturity (2026-06-07)

Stopped adding engines. Made the existing workflow feel mature.

- **Verification Priority** (`VerificationPriority`: Critical / High / Medium / Low). Assigned by `ApplicabilityEngine` per area + project kind — AU Validation/DSP/Audio I/O/Preset System on an AUv3 instrument are Critical; UI on an app is High; Document Workflow is Medium.
- **Verification Ageing** (`VerificationAge` + `VerificationRecord.age`/`.ageDescription`). Fresh → Recent → Ageing → Stale → Expired, with trust decay 1.0 → 0.85 → 0.6 → 0.25 → 0.0. Reality decays a verified record's contribution by its age.
- **Reality scoring rewritten**: priority-weighted (Critical = 4×, Low = 1×), age-decayed, and ceiling of 100 now requires every critical in-scope area to be Verified-Fresh. Failures penalise more than verifications reward.
- **Richer Guardian**: surfaces priority, last observed date, and an estimated effort in minutes. New stale-verification path — when nothing is failing but a Verified Critical record has aged out, Guardian flags it.
- **Project Journal** — new sidebar module `JournalView`, backed by `JournalEngine` + `JournalEntry`. Append-only, day-grouped, capped at 500. Auto-entries on verification state changes, mission edits, knowledge notes, and setup; plus free-form notes with author. Copyable as Markdown.
- **VerificationView**: rows show priority chip + age chip, sorted by priority then area. Bigger row typography (18pt area, 14pt fields).
- **Persistence**: `PersistedProjectRecord.journal` (optional, backward compatible) — older saved state decodes cleanly.
- Tests 20 → 26 (priority tagging, priority-weighted scoring, age decay across the trust ladder, Reality drops with age, Guardian flags stale, journal append/cap).

## Phase 6.5 — Command Centre Maturity (2026-06-08)

No new engines. Made the six command-centre features feel like a cockpit.

- **Verification Dependencies** (`VerificationRecord.dependsOn`, backward-compatible decode). Each verification row in the GUI now has a "Depends on (comma-separated)" field, and shows **"Blocked by: …"** in orange when any dependency is failed/unknown/in-progress.
- **Release Readiness board** (`ReleaseReadinessEngine`, `ReleaseAreaStatus`, `ReleaseReadinessBoard`). New sidebar module **Release Readiness**: per-priority groups (Critical → Low), per-row state + age + blocker chain, copy-as-Markdown release brief. Status calculated as `Blocked` (failing critical/high) → `Not Ready` (critical/high still unverified) → `Ready with Caveats` → `Ready`.
- **Cross-Project Workspace Overview** (`WorkspaceInsights`, `ProjectInsightSummary`). When ≥ 2 projects are open, the Workspace dashboard leads with a panel showing Projects · Healthy · Attention · Blocked counts and three tappable insight tiles: **Highest Risk · Most Complete · Least Verified**, each jumping straight to the project.
- **Cockpit Strip** at the top of the Command Centre — Reality · Verified · Failed · Unknown · Knowledge · Journal · Last Verified · Release status — everything visible at once, no scrolling/clicks.
- **Guardian Latest Activity** — Guardian now pulls journal entries + knowledge notes mentioning the top issue's area and shows the last three with date stamps, plus a "N journal · N note" badge. `GuardianRecommendation` gained `blockedBy`, `recentActivity`, `linkedJournalCount`, `linkedNotesCount` (all decode-backwards-compatible).
- **Tests 26 → 30**: release-blocking on critical failure, dependency surfacing in the board, cross-project insight ranking, Guardian enrichment with journal + notes.

## Phase 7 — Evidence + Registers + Templates + Packs (2026-06-08)

Made every important claim traceable and every belief explicit.

- **Evidence Layer**: `EvidenceRecord` (id, area, kind, summary, body, attachmentPath, classification, author, createdAt) — backward-compatible decode; persisted per project; inline `EvidencePanel` below every verification row so a Verified record carries proof, and a Failed record carries the reproduction.
- **Evidence-aware Reality**: a Verified area backed by Observed/Measured/Verified evidence keeps trust at ≥0.85 even when the record itself has aged out — supersedes ageing decay so documented truth doesn't decay invisibly.
- **Four Registers** (new `Registers` sidebar module, tabbed):
  - **Decisions** — title, decision, reason, alternatives, trade-offs, status (Proposed/Accepted/Rejected/Superseded/Deprecated/Needs Review).
  - **Architecture** — name, subsystem type, status, purpose, dependencies, linked verification areas.
  - **Risks** — title, description, likelihood × impact (severity score), status, mitigation, contingency; `isReleaseBlocking` computed; open Critical/High risks dock Reality score and surface as Top Risks.
  - **Assumptions** — assumption text, rationale, confidence, verification needed, status; ≥3 active assumptions trigger "Reality limited by N active assumption(s)".
- **Mission Templates + Verification Packs** (new `MissionTemplateCatalogue`): AUv3 Synth / AUv3 Sampler / AUv3 Effect / macOS App / iOS App / CLI Tool / Swift Library starters, each pre-wired with goals and a Verification Pack (with dependency graph baked in — e.g. AU Validation depends on Preset System + DSP + Audio I/O). One-click **Apply Pack** from the Verification view; **Start from a template** strip in the Mission editor.
- **Handoffs upgraded**: comprehensive Handoff Pack now appends sections for Evidence, Risk Register, Decision Register, Architecture, and Assumption Register — every report is auditable.
- **Guardian linked counts**: now tracks linkedEvidenceCount alongside journal + notes.
- **Persistence**: `PersistedProjectRecord.evidence/decisions/architecture/risks/assumptions` (all optional, backward-compatible). Older saved state still decodes.
- Tests 30 → 36. Coverage: evidence backward-compat decode, evidence protects stale verified trust, open critical risks penalise Reality, active assumptions appear, catalogue exposes AUv3 templates + dependency-wired packs, handoff includes all four registers.

## Phase 7.5 — Truth System Consolidation (2026-06-09)

Connected the records Phase 7 created. Full detail: `23_Phase_7_5_Truth_Consolidation.md`.

- **True cross-linking**: UUID link arrays on Evidence + all four registers (backward-compatible). Stored one-way, resolved both ways by `TruthEngine.related(to:)` — link once from either side and both records show it. 🔗 link menus on every register card and evidence row; **RELATED** strips render the resolved neighbourhood. New evidence auto-links to its verification record's UUID.
- **Truth Centre** (new sidebar module, three tabs):
  - **Workspace Truth** — Projects / Verified / Evidence / Open Risks / Active Assumptions / Critical Failures / Decisions / Architecture / Stale Verified across the whole workspace, plus the active project's Reality Breakdown, Confidence, and Register Health cards.
  - **Evidence Explorer** — classification summary cells + filters (confidence, area, free-text) over all project evidence.
  - **Dependency Map** — `dependsOn` rendered as an indented, cycle-safe tree, colour-coded by state, with priority pills.
- **Reality Breakdown** — itemised +/− contributions (verified weight, evidence, mission, failures, risks, assumptions, staleness, unknowns) so the score is explainable.
- **Confidence Engine** — separate from Reality: project state vs evidence quality. A failure with six reproductions is high-confidence-failed.
- **Register Health** — per-register coverage ratios; full bars in Truth Centre, aggregate **Truth Cover** tile in the cockpit.
- **Cockpit grew four tiles**: Confidence · Evidence · Open Risks · Truth Cover (12 total).
- Tests 36 → 42 (cross-link round-trip, breakdown attribution, confidence separation, register-health coverage, bidirectional related-records, verification area/UUID bridges).
- New docs: `23_Phase_7_5_Truth_Consolidation.md`, `24_SQLite_Migration_Plan.md`.

## Phase 8 — Truth System Foundation (2026-06-09)

Made the truth system scalable, searchable, and navigable. Full detail: `25_Phase_8_Truth_Foundation.md`.

- **SQLite is now the default persistence backend** (`SQLitePersistenceStore`, SQLite3 C API, WAL, zero dependencies). Automatic one-time migration from the UserDefaults blob (blob retained as backup); corruption recovery moves the damaged file aside and restores from backup — always surfaced in the status bar, never silently empty. Persistence is behind a `WorkspacePersisting` protocol; UserDefaults remains the visible fallback. Round-trip is test-proven value-equal.
- **Universal Search** — new Search module + `SearchEngine`: one query across projects, missions, verification, evidence, journal, knowledge, decisions, risks, architecture, assumptions; kind filter chips, release-blocking toggle, click-to-jump into the owning module.
- **Timeline Replay** — the Timeline stub is now real: the journal as a milestone timeline, oldest-first replay or newest-first triage, kind filter.
- **Portfolio Dashboard** — workspace panel now shows Open/Critical Risks, Evidence, Journal, Assumptions, Stale Verified alongside health counts and jump tiles.
- **Evidence Explorer maturity** — author + since-date filters; sort by Newest / Oldest / Highest confidence / Most linked.
- **Templates & Packs expanded** — new AUv3 MIDI Processor, Developer Tool, AV Utility, Media App, Automation Tool templates+packs; AUv3 packs matured (State Restore, Parameter Tree, Automation, Host Compatibility, CPU Safety chains); every pack now carries `RiskSeed` suggested risks, seeded on apply with duplicate-safe merging.
- **Workspace export / import** — full-state JSON backup and confirmation-gated restore in Settings.
- Tests 42 → 48. New docs: `25_Phase_8_Truth_Foundation.md`; `24_SQLite_Migration_Plan.md` marked implemented.

## Deferred

- FSEvents incremental indexing.
- Xcode build log parsing.
- Runtime monitoring.
- Security scanning beyond report redaction foundations.
- Optional integrations.
- Deep project/app identity (target/scheme/platform parsing); basic marker-based kind detection now shipped.
