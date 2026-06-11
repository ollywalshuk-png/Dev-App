# 24 — SQLite Migration Plan (written 2026-06-09, target: Phase 8 opener)

> **STATUS (2026-06-09): IMPLEMENTED in Phase 8** — `SQLitePersistenceStore`
> shipped as the default backend with automatic legacy migration, corruption
> recovery, and whole-state transactional writes (steps 1–3 + 5 below; step 4,
> granular per-record writes, deliberately remains a Phase 9 follow-up).
> Details: `25_Phase_8_Truth_Foundation.md`. The plan below is kept as the
> design record.

UserDefaults currently stores the entire workspace as one JSON blob
(`WorkspacePersistenceState`). That was the right call through Phase 7.5 — one
codable tree, trivial atomicity, zero dependencies. It stops being right when
Build Intelligence multiplies data volume (build logs, test runs, environment
snapshots). Migrate **before** Build Intelligence, not after.

## Why SQLite (and which flavour)

- **SQLite via `SQLite3` C API wrapped in a thin actor** — no third-party
  dependency, keeps the "no external services, no new licences" constraint.
  GRDB would be nicer but adds a dependency; revisit only if the hand-rolled
  layer grows painful.
- One file: `~/Library/Application Support/LocalForge/workspace.sqlite`
  (WAL mode). Local-first, offline, App-Store-safe, Time-Machine-friendly.

## Schema (v1)

```
projects        (id TEXT PK, name, fallback_path, bookmark BLOB, scan_policy JSON,
                 bookmark_status JSON, created_at, updated_at)
missions        (project_id PK → projects, payload JSON, updated_at)
verification    (id TEXT PK, project_id →, area, state, note, verified_by,
                 updated_at, depends_on JSON)
evidence        (id TEXT PK, project_id →, area, kind, classification, summary,
                 body, attachment_path, author, created_at, links JSON)
decisions       (id TEXT PK, project_id →, payload JSON, updated_at)
risks           (id TEXT PK, project_id →, payload JSON, updated_at)
architecture    (id TEXT PK, project_id →, payload JSON, updated_at)
assumptions     (id TEXT PK, project_id →, payload JSON, updated_at)
journal         (id TEXT PK, project_id →, kind, summary, detail, author, occurred_at)
knowledge       (id TEXT PK, project_id →, payload JSON, updated_at)
links           (from_id TEXT, from_type TEXT, to_id TEXT, to_type TEXT,
                 PRIMARY KEY (from_id, to_id))        -- optional: normalised
                 -- mirror of the JSON link arrays, for indexed reverse lookups
workspace_meta  (key TEXT PK, value JSON)              -- scan mode, theme,
                 -- last active project, schema_version
```

Payload-JSON columns keep the Codable models as the single source of truth;
hot columns (area/state/dates) are real columns for filtering. The `links`
table is a derived index, rebuilt from record payloads — records stay the truth.

## Migration steps

1. `PersistenceBackend` protocol with `load() -> WorkspacePersistenceState` /
   `save(...)`; current `WorkspacePersistenceStore` becomes the
   `UserDefaultsBackend`. (The store API already isolates persistence — no
   call-site changes.)
2. `SQLiteBackend` implementing the same protocol (read/write whole-state at
   first — correctness before granularity).
3. On first launch with SQLite: if defaults blob exists and sqlite file does
   not → import, verify row counts, keep the defaults blob as backup under a
   `migrated.v1` key. Never delete the old data in the same release.
4. Per-record granular writes (replace whole-state save) once stable.
5. Export/import workspace JSON ships in the same phase (it's a `SELECT *` away).

## Invariants to test

- Round-trip: defaults state → sqlite → loaded state is `==`.
- Old-version records (missing Phase 7/7.5 keys) decode identically.
- Corrupt sqlite file → fall back to backup blob with a visible warning, never
  a silent empty workspace.
- 10k journal entries: load under 100 ms (the reason we're doing this).

## Out of scope

iCloud sync, multi-device, server anything. Local file, full stop.
