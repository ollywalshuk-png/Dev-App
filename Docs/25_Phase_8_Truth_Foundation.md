# 25 — Phase 8: Truth System Foundation (2026-06-09)

Phase 7.5 made the truth system connected. Phase 8 makes it scalable,
searchable, and navigable. All seven roadmap items shipped.

## 1. SQLite migration (the headline)

`SQLitePersistenceStore` is now the **default backend**. Implementation per
`24_SQLite_Migration_Plan.md`:

- One file: `~/Library/Application Support/LocalForge/workspace.sqlite`, WAL
  mode, `SQLite3` C API directly — zero new dependencies.
- Schema: `workspace_meta`, `projects`, plus eight collection tables
  (verification / evidence / journal / knowledge / decisions / risks /
  architecture / assumptions), each `(id, project_id, position, payload JSON)`
  with a project index. Codable JSON stays the source of truth; `position`
  preserves array order so a round-trip is **value-equal** (verified by test,
  including the nil-vs-empty-array distinction).
- Writes are whole-state in one transaction — correctness before granularity,
  exactly as the plan staged it. Granular per-record writes are the Phase 9
  follow-up if profiling ever demands them.
- **Migration**: on first load, if the legacy UserDefaults blob exists it is
  imported automatically and reported in the status bar. The blob is never
  deleted in this release (a marker key records that migration happened).
- **Corruption**: an unreadable database (detected at open *or* load) is moved
  aside as `workspace.sqlite.corrupt-<timestamp>`, a fresh store is created,
  and the legacy backup restored if available. The event is always surfaced via
  the status bar — never a silent empty workspace.
- The persistence seam is now a protocol (`WorkspacePersisting`); the
  UserDefaults store remains as the visible fallback if SQLite cannot
  initialise, and for tests.

**Handoff note:** on a machine that has real pre-Phase-8 workspace data, the
first launch of this build performs the migration and the status bar says so.
On the build machine the legacy key was empty (fresh environment), so the
migration path is proven by the test suite rather than by local observation.

## 2. Universal Search

New **Search** sidebar module + `SearchEngine` in core. One query, every record
type, every project: projects, missions, verification, evidence, journal,
knowledge, decisions, risks, architecture, assumptions. Case-insensitive,
snippet-extracting, newest-first, capped at 300 hits. Kind filter chips with
live counts, a release-blocking-risks-only toggle, and every hit is a jump:
click → the owning project is selected and the owning module opens.

"Show all evidence related to Preset System" / "every decision mentioning
AUState" / "open release-blocking risks" — all answerable in one box now.

## 3. Evidence Explorer maturity

The Truth Centre tab gained: author filter, optional **Since** date filter, and
four sort orders — Newest, Oldest, Highest confidence, **Most linked** (ranked
by resolved related-record count, so the most load-bearing evidence floats up).

## 4. Portfolio Dashboard

The multi-project Workspace panel is now a true portfolio: Projects · Healthy ·
Attention · Blocked · **Open Risks · Critical Risks · Evidence · Journal ·
Assumptions · Stale Verified**, plus the existing Highest Risk / Most Complete /
Least Verified jump tiles and a shortcut into Search.

## 5. Timeline Replay

The `Timeline` module — a stub since Phase 1 — is now real. The project's
journal renders as a vertical milestone timeline (kind-coloured dots, day
headers, connecting spine). **Replay** mode reads oldest → newest so a
project's life reads like a story; flip to newest-first to triage. Kind filter
included. Because every register write auto-journals, risks, decisions,
evidence, missions, and verifications all appear without any new bookkeeping.

## 6. Mission Template expansion

New templates: **AUv3 MIDI Processor**, **Developer Tool**, **AV Utility**,
**Media App**, **Automation Tool** — alongside the existing Synth / Sampler /
Effect / macOS / iOS / CLI / Library.

## 7. Verification Pack maturity + suggested risks

- AUv3 Instrument Pack now carries the full advisor chain: Parameter Tree →
  Preset System → State Restore → AU Validation → Host Compatibility, plus
  Automation, Voice Management, CPU Safety.
- AUv3 Effect Pack: Bypass, Wet/Dry, Latency Reporting, Automation, Host Compat.
- macOS/iOS App Packs: Launch, Navigation, Settings, Import/Export,
  Accessibility, Error Handling, Dark Mode, Window State, Sandbox.
- New packs: MIDI Tool, Developer Tool, AV Utility, Media App, Automation Tool.
- **`RiskSeed`**: every pack carries kind-typical risks (e.g. "Preset
  corruption", "Host state restore failure", "Secret leakage in reports").
  Applying a pack seeds them into the Risk Register as Open — skipping any
  title that already exists, so re-applying never duplicates.

## Also shipped

- **Workspace export / import** (Settings → Workspace Data): full-state JSON
  backup and restore. Import is confirmation-gated and clearly destructive.

## Verification

- `swift test` → **48/48 passed** (6 new: SQLite round-trip value-equality,
  legacy migration with blob retention, corruption recovery via backup,
  universal search across types/flags, portfolio truth counts, pack risk seeds
  + matured dependency chains).
- `./script/build_and_run.sh --verify` → built, bundled, launched, process
  confirmed, exit 0. `workspace.sqlite` created in Application Support on
  launch.

## Deferred (unchanged by design)

Build Intelligence (Phase 9 opener now that SQLite is in), Runtime
Diagnostics, Repo Monitor, Bloat, Security Review, AI systems, telemetry,
cloud. Granular per-record SQLite writes if scale demands.
