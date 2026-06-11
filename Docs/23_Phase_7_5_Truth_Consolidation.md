# 23 — Phase 7.5: Truth System Consolidation (2026-06-09)

Phase 7 created the records (Evidence, Decisions, Risks, Architecture, Assumptions).
Phase 7.5 connects them. The seven priorities, all shipped:

## 1. True cross-linking (UUID, not text)

Every record now carries real UUID link arrays, all backward-compatible
(`decodeIfPresent` → `[]` for pre-7.5 saved state):

| Record | Link fields |
| --- | --- |
| `EvidenceRecord` | linkedVerificationIDs · linkedRiskIDs · linkedDecisionIDs · linkedArchitectureIDs · linkedAssumptionIDs · linkedJournalIDs · linkedNoteIDs |
| `DecisionRecord` | linkedEvidenceIDs · linkedRiskIDs · linkedArchitectureIDs · linkedVerificationIDs |
| `RiskRecord` | linkedEvidenceIDs · linkedDecisionIDs · linkedArchitectureIDs · linkedVerificationIDs |
| `ArchitectureItem` | linkedEvidenceIDs · linkedRiskIDs · linkedDecisionIDs · linkedArchitectureIDs |
| `AssumptionRecord` | linkedEvidenceIDs · linkedRiskIDs · linkedVerificationIDs |

**Design decision: single-direction storage, bidirectional resolution.**
A link is stored once, on whichever record the user linked from.
`TruthEngine.related(to:)` resolves the full neighbourhood by walking forward
links, reverse links (records pointing back at the target), and the legacy
area-name bridges (`linkedVerificationAreas`, `linkedVerificationArea`,
`EvidenceRecord.area`). This means:

- linking once from either side is enough — both records show the relationship;
- no bidirectional write means no desync, no orphaned half-links;
- deleting a record cannot leave a dangling inverse pointer (the resolver simply
  stops finding it).

`VerificationRecord` deliberately stores **no** link arrays: every other record
points *at* verification (by UUID or area), and the resolver computes the
reverse view. One source of truth per edge.

**UI:** a `link` menu (🔗) on every register card and every evidence row toggles
links by record title; a **RELATED** strip on each card shows the resolved
neighbourhood (verification · evidence · risks · decisions · architecture ·
assumptions). New evidence created under a verification row is auto-linked to
that record's UUID.

## 2. Evidence Explorer

Truth Centre tab. Total / Observed / Measured / Verified / Unknown summary
cells, then the full evidence list filtered by confidence classification, area,
and free-text search across summary + body. Each row shows kind, classification,
attachment path, and its RELATED strip.

## 3. Reality Breakdown (explainable score)

`TruthEngine.breakdown(...)` itemises Reality into labelled contributions:
verified records (priority-weighted, age-decayed) · evidence on file · mission
defined · failed verifications · open critical/high risks · active assumptions ·
stale verified records · in-scope unknowns. Rendered as +/− rows under the
score in the Truth Centre. The deltas are attribution, not arithmetic proof —
they show what dominates, the score itself still comes from `RealityEngine`.

## 4. Confidence Engine (separate from Reality)

`TruthEngine.confidence(...)`. Reality measures *project state*; Confidence
measures *evidence quality behind that state*. A failing project with six
reproductions is high-confidence-failed. Inputs: strong vs weak evidence counts,
evidence coverage across in-scope areas, fresh verified records, active
assumptions (sharp drag). Output: 5–100 score + High/Moderate/Low/Very Low label
+ itemised contributions. Shown in the Truth Centre and as a cockpit tile.

## 5. Workspace Truth Centre

New `Truth Centre` sidebar module, Workspace tab: Projects · Verified Records ·
Evidence Records · Open Risks · Active Assumptions · Critical Failures ·
Decisions · Architecture · Stale Verified — aggregated across every open
project from persisted records (no rescan needed).

## 6. Dependency Map

Truth Centre tab. Renders `VerificationRecord.dependsOn` as an indented tree —
roots are areas nothing depends on; children are the areas each depends on.
Colour-coded by state (green Verified / red Failed / blue In Progress / grey
Unknown) with priority pills. Cycle-safe via visited-set. No AI, pure data.

## 7. Register Health

`TruthEngine.registerHealth(...)` — coverage ratios per register against
sensible targets (evidence & architecture: 1 per in-scope area; decisions &
risks: 3 per project; assumptions: 2). Full bars in the Truth Centre; aggregate
**Truth Cover** tile in the Command Centre cockpit, which also gained
**Confidence**, **Evidence**, and **Open Risks** tiles (12 tiles total).

## Verification

- `swift test` → **42/42 passed** (6 new this phase: cross-link round-trip,
  reality breakdown attribution, confidence-separate-from-reality, register
  health coverage, bidirectional related-records resolution, verification
  area/UUID bridges).
- `./script/build_and_run.sh --verify` → built, bundled, launched, process
  confirmed, exit 0.

## Still deferred (deliberately)

- SQLite migration — see `24_SQLite_Migration_Plan.md`. UserDefaults remains a
  documented temporary limitation; registers + evidence + journal will outgrow it.
- Build Intelligence, Runtime Diagnostics, Repo Monitor, Bloat, Security Review,
  AI systems — unchanged, per roadmap.
- Workspace JSON export/import — lands with the SQLite work.
- Journal/Knowledge link pickers (evidence → journal entries) — the UUID fields
  exist (`linkedJournalIDs`, `linkedNoteIDs`); UI deferred to keep the panel lean.
