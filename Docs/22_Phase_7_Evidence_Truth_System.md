# Phase 7 — Evidence & Truth System

## What "Developer Truth System" means here

LocalForge's chain is now:

```
Project → Mission → Evidence → Verification → Reality → Risk → Action → Release → Handoff
```

Every link is now backed by a real, user-editable record persisted locally.

## What landed

### Evidence Layer
- `EvidenceRecord` lives in `LocalForgeCore/Models/EvidenceRecord.swift`.
- Inline `EvidencePanel` under every verification row (`LocalForgeApp/Views/EvidencePanel.swift`) — add/remove/attach local file path.
- `RealityEngine.assess(..., evidenceRecords:)` — a Verified area backed by Observed/Measured/Verified evidence keeps trust ≥0.85 even when the record itself is stale.

### Decision Register
- `DecisionRecord` (title, decision, reason, alternatives, trade-offs, status). Auto-journals as a `.decision` entry.
- UI lives in the new `Registers` sidebar module, Decisions tab.

### Architecture Register
- `ArchitectureItem` (name, subsystem type, purpose, status, dependencies, linkedVerificationAreas).
- Maps cleanly onto `VerificationRecord.dependsOn` — a single dependency graph used everywhere.

### Risk Register
- `RiskRecord` (likelihood × impact severity, status, mitigation, contingency).
- `isReleaseBlocking` flag (open + Critical, or open + High not-Low).
- Open Critical / High risks subtract from Reality score and appear as Top Risks.

### Assumption Register
- `AssumptionRecord` (assumption, rationale, confidence, verificationNeeded, status).
- Active assumptions appear in `RealityAssessment.assumptions`; ≥3 active triggers "Reality limited by …" unknown.

### Mission Templates + Verification Packs
- `MissionTemplateCatalogue` provides AUv3 Synth / Sampler / Effect / macOS / iOS / CLI / Library starters.
- Each template references a `VerificationPack` with the area list **and dependency graph** pre-wired.
- Apply Pack from the Verification view; "Start from a template" strip in the Mission editor.

### Handoffs
- `PromptForgeEngine.handoffSections(..., risks:, decisions:, architecture:, assumptions:)` appends a section per register.
- Every comprehensive handoff is now auditable.

## What was deliberately deferred (still)

- **Build Intelligence** — would automatically flip Build verification from observation. Not yet.
- **Runtime Diagnostics** — observation-only, but next-phase.
- **Repo Monitor** — event-driven only when added.
- **SQLite migration** — UserDefaults is the persistence layer. A migration plan should be drafted next phase (`Docs/23_SQLite_Migration_Plan.md` is the placeholder for that work).
- **Cloud AI / telemetry / paid APIs** — explicitly banned.

## Safety constraints reaffirmed

- Read-only by default — no automation introduced this phase mutates the user's repository.
- Local-first — every new model persists in the existing local `UserDefaults` workspace state.
- No network code added.
- No new external dependencies — all engines are pure Swift.

## Verification

- `swift test` (with the documented Xcode-toolchain fallback) → **36/36 passed**.
- `./script/build_and_run.sh --verify` → app built, bundled, launched, exit 0.
