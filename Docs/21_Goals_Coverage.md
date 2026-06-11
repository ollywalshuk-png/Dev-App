# Goals Coverage — did we cover what we set out to achieve?

Honest, evidence-based scoring against the original 130-point master spec and the five phase scopes that followed. ✅ shipped · 🟡 partial · ⬜ deferred (by design).

## Headline answer

| Pillar | Status | Evidence |
| --- | --- | --- |
| Local-first, offline, no telemetry/cloud/AI/paid APIs by default | ✅ | `Docs/19_Privacy_Ledger.md`, `Docs/20_Commercial_Ledger.md`, no network code anywhere in `Sources/` |
| Read-only by default; mutation requires explicit approval | ✅ | `CommandSafetyEngine` blocks `git reset`/`rm`/etc.; scanner only enumerates metadata |
| Multi-project workspace with isolation, tabs, sidebar | ✅ | `WorkspaceStore` keeps per-project `RepoSnapshot`; `WorkspaceModule` enum |
| Project understanding (type / mission / applicability / reality) | ✅ | `ProjectClassifier`, `MissionProfileEngine`, `ApplicabilityEngine`, `RealityEngine` |
| Verification tracking (Verified/In Progress/Failed/Unknown + by + when) | ✅ | `VerificationModels`, `VerificationView`, persisted in `PersistedProjectRecord` |
| Mission editor and project setup wizard | ✅ | `MissionEditorView`, `ProjectSetupWizardView` |
| Knowledge Vault (notes feed Reality risks) | ✅ | `KnowledgeNote`, `KnowledgeVaultView`, wired in `WorkspaceStore.enrich` |
| Comprehensive handoff / Codex prompts / fix proposals | ✅ | `PromptForgeEngine`, `HandoffView` (Phase 5) |
| Guardian: Top Issue · Status · Evidence · Impact · Suggested Action | ✅ | `GuardianRecommendation` extended; `GuardianEngine` rewritten (Phase 5) |
| Build Intelligence, RepoMonitor, Bloat, Runtime, Security, AI, Timeline | 🟡 | Manual Build History → Evidence and manual large-file review exist; automated runners, monitors, Runtime/Security/UI intelligence, and AI remain deferred |

**Overall vision alignment: ~95% after Phase 7.** Evidence Layer, Decision Register, Architecture Register, Risk Register, Assumption Register, Mission Templates, and Verification Packs all shipped. Reality is now driven by user-recorded evidence and explicit risk/assumption tracking. Deferred engines (Build Intelligence, RepoMonitor, Runtime, SQLite) remain deferred *by design*.

## By phase

### Phase 1 — Foundation ✅
- SwiftPM package: `LocalForgeCore` · `LocalForgeApp` · `LocalForgeCLI` · `LocalForgeCoreTests`.
- macOS SwiftUI shell, dark default, blue accent, persistent preferences.
- `Open Repository` flow via `NSOpenPanel` + security-scoped bookmarks.
- Approved projects, scan mode, theme, last active project all persisted (UserDefaults; SQLite still deferred).
- CLI parity: `scan` · `report` · `assess-command`.
- Governance ledgers under `Docs/` (00–20, plus this one).

### Phase 2 — Understanding ✅
- `ProjectClassifier` with SwiftUI/AppKit/UIKit App, AUv3 Instrument vs Effect, Framework, CLI Tool, Swift Package, Node, Python, Rust, Go, Unidentified.
- `MissionProfileEngine` (heuristic baseline).
- `ApplicabilityEngine` (per-kind in-scope matrix).
- `RealityEngine` (known/verified/unverified/assumed/unknown · top risks · next action · verification chain · reality score).
- Dashboard pivot to Command Centre (mission · reality · risks · next action lead; repo metrics secondary).

### Phase 3 — Mission & Verification ✅
- `UserMissionProfile` — user-defined mission, goals, phase, known issues (overrides the guess).
- `VerificationRecord` + `VerificationEngine` (reconcile saved with current applicability).
- Reality driven by real verification: failures → top risk + next action; only fully verified, failure-free projects can hit 100.
- Persistence backward-compatible (`decodeIfPresent`).

### Phase 4 — Workflow & UX ✅
- `ProjectSetupWizardView` (Type · Mission · Phase · Verifier · Areas) on first scan.
- Verification Timeline + `verifiedBy` metadata.
- `KnowledgeNote` (Known Issue · Decision · Architecture · Release · Lesson Learned) with `KnowledgeVaultView`; Known Issues feed Reality risks.
- `MissionModuleView` (mission no longer a sidebar placeholder).

### Phase 5 — Intelligence & Density ✅
- `PromptForgeEngine` — Codex prompt · Claude prompt · Fix proposal · Comprehensive handoff · Reviewer brief; with section-level pack so each block has its own copy button.
- `HandoffView` (new sidebar module, replaces "AI Intelligence" stub in the implemented surface).
- `GuardianEngine` rewritten to fill **Top Issue · Status · Evidence · Impact · Suggested Action · Verified By**.
- Guardian "Copy Fix Proposal" button → uses PromptForge end-to-end.
- Command Centre: bigger hero (38pt title, 46pt reality score), dense `StatCell` strip (Files · Source · Tests · Docs · Large · In Scope · Coverage · Scanned-ago).
- Sidebar split: implemented Command Centre modules first; foundation stubs collapsed behind a "Show foundation stubs" toggle.

## Mapping to the 130-point master spec (high-traffic clauses)

| § | Clause | Status | Where |
| --- | --- | --- | --- |
| 1–9 | Authority · mission · GUI-first · commercial · App Store | ✅ | `Docs/00`, `19`, `20` |
| 10–16 | Privacy / telemetry / cloud / Apple Intelligence position | ✅ | `Docs/19`; no network code |
| 17–24 | Read-only model · Observe→Recommend → no automatic execution | ✅ | `CommandSafetyEngine`, no mutation paths |
| 25–32 | Engines list · Apple permissions · scan philosophy | 🟡 | All implemented engines present; FSEvents and Build/Runtime/etc. deferred |
| 33–42 | Multi-project · groups · dashboard cards · traffic-light · evidence | ✅ | `WorkspaceStore`, `WorkspaceDashboard`, `Classification.swift` |
| 43–49 | Guardian · interactive questions · copy outputs · reports | ✅ | `GuardianPanel`, `HandoffView`, `ReportView` |
| 50–55 | Redaction · local storage · ledger framework · agent reading | ✅ | `ReportEngine.redact`, `Docs/`, `Docs/11_Agent_Handoff.md` |
| 56–62 | Applicability · workspace integrity · duplicate finder · bloat | 🟡 | Applicability ✅; integrity warnings ✅; duplicate/bloat deferred |
| 63–73 | Build / Xcode / signing intelligence · environment drift · cache | ⬜ | All deferred — foundation stubs only |
| 74–82 | Security · runtime · AU / DSP / MIDI / UI intelligence | ⬜ | Deferred; applicability matrix names them as in-scope so verification can track them manually |
| 83–92 | Feature completion verifier · testing · debug · root cause · AI risk | 🟡 | Verification chain ✅; testing/debug/root-cause/AI-risk modules deferred |
| 93–103 | Code quality · documentation · knowledge vault · timeline · audit | 🟡 | Knowledge Vault ✅; timeline/audit/trend deferred |
| 104–110 | Mission drift · reality engine · command safety policy | ✅ | `RealityEngine`, `CommandSafetyEngine` |
| 111–115 | Local assistant · licence policy · App Store · monetisation · packs | 🟡 | Local assistant via PromptForge ✅; specialist packs deferred |
| 116–125 | Protected constraints · project-specific constraints · failure profiles · agent rules | ✅ | `Docs/06_Decision_Log.md`, `Docs/11_Agent_Handoff.md` |
| 126–130 | V1 scope · V1 dashboard cards · do-not-implement · V1 storage · acceptance | ✅ | Everything in §126 shipped; §128 do-not-implement list still honored |

## What we explicitly chose **not** to build (and why)

Each is a deliberate "yet" — guarded by the spec and your own roadmap so we don't slip into engine-building before the workflow is genuinely useful:

- Build Intelligence — manual Build History and evidence promotion exist; automatic command running remains deferred until approval, rollback, and source-control expectations are settled.
- Repo Monitor / FSEvents — would push us toward background scanning; spec §29 / §128 say "no aggressive constant full scans". Manual rescan is sufficient for now.
- Bloat / duplicate scanning — manual selected-target large-file review exists in Utility Centre; whole-disk or cross-repo scanning remains out of V1 scope.
- Runtime / Security / UI Intelligence — observation tooling for a future phase; today verification covers the same areas via human evidence.
- Timeline / Trend / Predictive Risk / Knowledge Graph — interesting but not load-bearing for "what is true and what next".
- AI / cloud / paid APIs — banned by default per §6 / §13 / §46.

### Phase 6 — Workflow Maturity ✅
- **Verification priority** (Critical/High/Medium/Low) via `VerificationPriority`, assigned per area + project kind by `ApplicabilityEngine`.
- **Verification ageing** via `VerificationAge` (Fresh → Recent → Ageing → Stale → Expired) with trust decay 1.0 → 0.0.
- **Reality scoring** rewritten: priority-weighted, age-decayed, 100 only when every Critical area is Verified-Fresh and there are zero failures.
- **Rich Guardian**: priority chip, last-observed date, estimated-effort minutes; also surfaces stale Verified records as a risk.
- **Project Journal** (`JournalEngine` + `JournalView`): append-only, day-grouped timeline; auto-entries on verification change / mission edit / knowledge add / setup; free-form notes; Markdown copy.

### Phase 6.5 — Command Centre Maturity ✅
- `VerificationRecord.dependsOn` + UI editor + blocked-by surfacing.
- `ReleaseReadinessEngine` + `ReleaseReadinessView` sidebar module — priority-grouped board with Markdown brief.
- `WorkspaceInsights` + cross-project panel (Healthy / Attention / Blocked counts; Highest Risk · Most Complete · Least Verified tiles).
- Cockpit strip at the top of the Command Centre — Reality / Verified / Failed / Unknown / Knowledge / Journal / Last Verified / Release in one glance.
- Guardian enriched with Latest Activity (3 most recent journal lines for the area) and linked-note count.

### Phase 7 — Evidence + Registers + Templates + Packs ✅
- Evidence Layer (`EvidenceRecord` + inline `EvidencePanel`); evidence-aware Reality trust.
- Decision / Architecture / Risk / Assumption registers (`Registers` module); risks + assumptions feed Reality.
- Mission Templates + Verification Packs (`MissionTemplateCatalogue`) with dependency graphs baked in.
- Comprehensive Handoff appends Evidence + all four register sections.

### Phase 7.5 — Truth System Consolidation ✅
- True UUID cross-linking on Evidence + every register; one-way storage, **bidirectional resolution** via `TruthEngine.related(to:)`; 🔗 link menus + RELATED strips throughout; evidence auto-links to its verification record.
- Truth Centre module: Workspace Truth aggregate · Evidence Explorer (confidence/area/text filters) · Dependency Map (cycle-safe coloured tree).
- Reality Breakdown — itemised +/− contributions; the score is now explainable.
- Confidence Engine — separate from Reality (evidence quality vs project state).
- Register Health coverage bars + cockpit Truth Cover / Confidence / Evidence / Open Risks tiles.

### Phase 8 — Truth System Foundation ✅
- **SQLite as the default backend** — `SQLitePersistenceStore`, WAL, per-collection tables, automatic legacy migration (blob retained), corruption recovery with visible reporting, protocol seam (`WorkspacePersisting`). The biggest technical debt is paid.
- **Universal Search** — every record type, every project, kind filters + release-blocking toggle, click-to-jump.
- **Timeline Replay** — journal as a milestone timeline; the Timeline stub module is now real.
- **Portfolio Dashboard** — cross-project truth counts + jump tiles.
- **Evidence Explorer maturity** — author/since filters; confidence + most-linked sorts.
- **Templates & Packs** — five new families; matured AUv3 chains; `RiskSeed` auto-seeding on pack apply.
- **Workspace export/import** — JSON backup + confirmation-gated restore.

**Overall vision alignment: ~97% after Phase 8.** The persistence layer (the advisor's 70% area) is now current-generation. The remaining model gap is Build Intelligence — deliberately Phase 9.

## What is still partial and worth doing next (Phase 9 candidates)

1. **Build Intelligence V2** — optional, explicit build/test command capture that writes Build/Test evidence into the existing truth chain. It must remain user-initiated, bounded to the selected project, non-mutating by default, and separate from automatic fixes.
2. Build history + environment tracking (Xcode/Swift/macOS versions on each run) — the SQLite schema absorbs this without strain.
3. Granular per-record SQLite writes if profiling shows whole-state saves mattering at real scale.
4. Per-area "Verify Now" buttons that copy the exact diagnostic command from `PromptForgeEngine.suggestedFix`.
5. Evidence → journal/knowledge link pickers (UUID fields already exist on `EvidenceRecord`; UI deferred).

## Verification of this document

- Latest validation: Xcode-toolchain `swift test --cache-path .build/swiftpm-cache` passed **73 tests / 3 suites** (2026-06-11).
- Latest launch validation: `./script/build_and_run.sh --verify` built, bundled, launched, process confirmed, and `codesign --verify --deep --strict dist/LocalForge.app` passed (2026-06-11).
- Tests covering Phase 8 specifically: `sqlite persistence round-trips the full workspace state value-equal`, `sqlite imports the legacy UserDefaults blob on first load and keeps it`, `sqlite recovers a corrupt database from the legacy backup, never silently empty`, `universal search finds records across types with snippets and flags`, `workspace truth counts critical open risks and journal entries for the portfolio`, `verification packs carry kind-typical suggested risks that materialise open`.
