import Foundation
import SQLite3

/// Phase 8 — SQLite-backed workspace persistence (replaces the UserDefaults
/// blob as the default backend; see Docs/24_SQLite_Migration_Plan.md).
///
/// Shape: one file (`workspace.sqlite`, WAL mode) under Application Support.
/// Records keep their Codable JSON as the source of truth (payload columns);
/// per-collection tables with project_id + position give scalability and keep
/// array order so a round-trip is value-equal. Writes are whole-state inside
/// one transaction — correctness before granularity, per the migration plan.
///
/// Migration: on first load, if the legacy UserDefaults blob exists it is
/// imported into SQLite. The blob is left untouched (plus a marker key) so
/// nothing is destroyed in the release that migrates.
///
/// Corruption: an unreadable database file is moved aside
/// (`workspace.sqlite.corrupt-<timestamp>`), a fresh store is created, and the
/// legacy blob (if any) is restored. The event is surfaced via `lastLoadNote`
/// — never a silent empty workspace.
public final class SQLitePersistenceStore: WorkspacePersisting {
    public enum SQLiteError: Error, LocalizedError {
        case openFailed(String)
        case execFailed(String)
        case encodingFailed(String)
        case decodingFailed(String)

        public var errorDescription: String? {
            switch self {
            case .openFailed(let d): "SQLite open failed: \(d)"
            case .execFailed(let d): "SQLite statement failed: \(d)"
            case .encodingFailed(let d): "SQLite encoding failed: \(d)"
            case .decodingFailed(let d): "SQLite decoding failed: \(d)"
            }
        }
    }

    public let fileURL: URL
    public private(set) var lastLoadNote: String?

    /// Set when init found the existing file unreadable and replaced it; the
    /// next load() reports it (and restores the legacy backup if one exists).
    private var pendingRecoveryNote: String?
    private var db: OpaquePointer?
    private let legacyDefaults: UserDefaults?
    private let legacyKey: String
    private static let migratedMarkerSuffix = ".migratedToSQLite"
    private static let transient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

    /// Collection tables all share one shape: (id, project_id, position, payload).
    private static let collectionTables = [
        "verification_records", "evidence_records", "journal_entries",
        "knowledge_notes", "decision_records", "risk_records",
        "architecture_items", "assumption_records"
    ]

    public init(
        fileURL: URL? = nil,
        legacyDefaults: UserDefaults? = .standard,
        legacyKey: String = "LocalForge.WorkspaceState"
    ) throws {
        if let fileURL {
            self.fileURL = fileURL
        } else {
            let support = try FileManager.default.url(
                for: .applicationSupportDirectory, in: .userDomainMask,
                appropriateFor: nil, create: true
            ).appendingPathComponent("LocalForge", isDirectory: true)
            try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
            self.fileURL = support.appendingPathComponent("workspace.sqlite")
        }
        self.legacyDefaults = legacyDefaults
        self.legacyKey = legacyKey
        do {
            try open()
        } catch {
            // Existing file is not a readable database (corruption, partial
            // write). Move it aside and start fresh — load() will restore from
            // the legacy backup if one exists, and report what happened.
            try recoverFromCorruption(reason: error.localizedDescription)
            pendingRecoveryNote = "Workspace database was unreadable; the damaged file was kept beside it."
        }
    }

    deinit {
        if let db { sqlite3_close_v2(db) }
    }

    // MARK: - WorkspacePersisting

    public func load() throws -> WorkspacePersistenceState {
        lastLoadNote = nil
        do {
            return try loadFromDatabase()
        } catch {
            // Corrupt or unreadable: move the bad file aside, start fresh,
            // restore from the legacy blob if one exists.
            try recoverFromCorruption(reason: error.localizedDescription)
            if let legacy = legacyState() {
                try save(legacy)
                lastLoadNote = "Workspace database was unreadable and has been rebuilt from the saved backup. The damaged file was kept beside it."
                return legacy
            }
            lastLoadNote = "Workspace database was unreadable and has been reset. The damaged file was kept beside it."
            return .empty
        }
    }

    public func save(_ state: WorkspacePersistenceState) throws {
        let encoder = JSONEncoder()
        try exec("BEGIN IMMEDIATE TRANSACTION")
        do {
            try exec("DELETE FROM workspace_meta")
            try exec("DELETE FROM projects")
            for table in Self.collectionTables {
                try exec("DELETE FROM \(table)")
            }

            try insertMeta("schema_version", "1", encoder: encoder)
            try insertMeta("scan_mode", state.scanMode.rawValue, encoder: encoder)
            try insertMeta("theme", try encodeJSON(state.theme, encoder: encoder), encoder: encoder)
            try insertMeta("saved_views", try encodeJSON(state.savedViews, encoder: encoder), encoder: encoder)
            try insertMeta("pinned_items", try encodeJSON(state.pinnedItems, encoder: encoder), encoder: encoder)
            try insertMeta("favorited_project_ids", try encodeJSON(state.favoritedProjectIDs, encoder: encoder), encoder: encoder)
            if let last = state.lastActiveProjectID {
                try insertMeta("last_active_project", last.uuidString, encoder: encoder)
            }

            for (index, record) in state.projects.enumerated() {
                // Rows live in the collection tables; the core payload keeps an
                // empty-array marker (vs nil) so nil-vs-[] survives a round-trip.
                var core = record
                core.verification = record.verification.map { _ in [] }
                core.knowledgeNotes = record.knowledgeNotes.map { _ in [] }
                core.journal = record.journal.map { _ in [] }
                core.evidence = record.evidence.map { _ in [] }
                core.decisions = record.decisions.map { _ in [] }
                core.architecture = record.architecture.map { _ in [] }
                core.risks = record.risks.map { _ in [] }
                core.assumptions = record.assumptions.map { _ in [] }
                let payload = try encodeJSON(core, encoder: encoder)
                try run(
                    "INSERT OR REPLACE INTO projects(id, position, name, payload) VALUES (?,?,?,?)",
                    bind: [record.id.uuidString, String(index), record.name, payload]
                )
                try insertCollection("verification_records", record.id, record.verification, encoder: encoder)
                try insertCollection("evidence_records", record.id, record.evidence, encoder: encoder)
                try insertCollection("journal_entries", record.id, record.journal, encoder: encoder)
                try insertCollection("knowledge_notes", record.id, record.knowledgeNotes, encoder: encoder)
                try insertCollection("decision_records", record.id, record.decisions, encoder: encoder)
                try insertCollection("risk_records", record.id, record.risks, encoder: encoder)
                try insertCollection("architecture_items", record.id, record.architecture, encoder: encoder)
                try insertCollection("assumption_records", record.id, record.assumptions, encoder: encoder)
            }
            try exec("COMMIT")
        } catch {
            try? exec("ROLLBACK")
            throw error
        }
    }

    // MARK: - Load internals

    private func loadFromDatabase() throws -> WorkspacePersistenceState {
        let decoder = JSONDecoder()
        var meta: [String: String] = [:]
        try query("SELECT key, value FROM workspace_meta") { stmt in
            if let k = Self.column(stmt, 0), let v = Self.column(stmt, 1) { meta[k] = v }
        }

        // Fresh database: import the legacy UserDefaults blob if present.
        if meta["schema_version"] == nil {
            if let legacy = legacyState() {
                try save(legacy)
                legacyDefaults?.set(true, forKey: legacyKey + Self.migratedMarkerSuffix)
                if let recovery = pendingRecoveryNote {
                    lastLoadNote = recovery + " Workspace was rebuilt from the saved backup (\(legacy.projects.count) project(s))."
                    pendingRecoveryNote = nil
                } else {
                    lastLoadNote = "Workspace migrated from UserDefaults to SQLite (\(legacy.projects.count) project(s)). The old data was kept as a backup."
                }
                return legacy
            }
            if let recovery = pendingRecoveryNote {
                lastLoadNote = recovery + " No backup was available; the workspace starts empty."
                pendingRecoveryNote = nil
            }
            return .empty
        }

        let scanMode = meta["scan_mode"].flatMap(ScanMode.init(rawValue:)) ?? .balanced
        let theme = meta["theme"].flatMap { $0.data(using: .utf8) }
            .flatMap { try? decoder.decode(ThemePreferences.self, from: $0) } ?? .default
        let lastActive = meta["last_active_project"].flatMap(UUID.init(uuidString:))
        let savedViews = try decodeMeta([SavedView].self, key: "saved_views", from: meta, decoder: decoder) ?? []
        let pinnedItems = try decodeMeta([PinnedItem].self, key: "pinned_items", from: meta, decoder: decoder) ?? []
        let favoritedProjectIDs = try decodeMeta([UUID].self, key: "favorited_project_ids", from: meta, decoder: decoder) ?? []

        var projects: [PersistedProjectRecord] = []
        var decodeFailure: Error?
        try query("SELECT payload FROM projects ORDER BY position") { stmt in
            guard let payload = Self.column(stmt, 0), let data = payload.data(using: .utf8) else { return }
            do {
                projects.append(try decoder.decode(PersistedProjectRecord.self, from: data))
            } catch {
                decodeFailure = error
            }
        }
        if let decodeFailure {
            throw SQLiteError.decodingFailed(decodeFailure.localizedDescription)
        }

        func attach<T: Codable>(_ table: String, _ type: T.Type) throws -> [UUID: [T]] {
            var grouped: [UUID: [T]] = [:]
            var failure: Error?
            try query("SELECT project_id, payload FROM \(table) ORDER BY project_id, position") { stmt in
                guard
                    let pid = Self.column(stmt, 0).flatMap(UUID.init(uuidString:)),
                    let payload = Self.column(stmt, 1), let data = payload.data(using: .utf8)
                else { return }
                do {
                    grouped[pid, default: []].append(try decoder.decode(T.self, from: data))
                } catch {
                    failure = error
                }
            }
            if let failure { throw SQLiteError.decodingFailed(failure.localizedDescription) }
            return grouped
        }

        let verification = try attach("verification_records", VerificationRecord.self)
        let evidence = try attach("evidence_records", EvidenceRecord.self)
        let journal = try attach("journal_entries", JournalEntry.self)
        let knowledge = try attach("knowledge_notes", KnowledgeNote.self)
        let decisions = try attach("decision_records", DecisionRecord.self)
        let risks = try attach("risk_records", RiskRecord.self)
        let architecture = try attach("architecture_items", ArchitectureItem.self)
        let assumptions = try attach("assumption_records", AssumptionRecord.self)

        for i in projects.indices {
            let id = projects[i].id
            // Attach rows where they exist; otherwise keep the core marker
            // (nil or []) so the round-trip is value-equal.
            projects[i].verification = verification[id] ?? projects[i].verification
            projects[i].evidence = evidence[id] ?? projects[i].evidence
            projects[i].journal = journal[id] ?? projects[i].journal
            projects[i].knowledgeNotes = knowledge[id] ?? projects[i].knowledgeNotes
            projects[i].decisions = decisions[id] ?? projects[i].decisions
            projects[i].risks = risks[id] ?? projects[i].risks
            projects[i].architecture = architecture[id] ?? projects[i].architecture
            projects[i].assumptions = assumptions[id] ?? projects[i].assumptions
        }

        return WorkspacePersistenceState(
            projects: projects,
            scanMode: scanMode,
            theme: theme,
            lastActiveProjectID: lastActive,
            savedViews: savedViews,
            pinnedItems: pinnedItems,
            favoritedProjectIDs: favoritedProjectIDs
        )
    }

    private func legacyState() -> WorkspacePersistenceState? {
        guard
            let defaults = legacyDefaults,
            let data = defaults.data(forKey: legacyKey),
            let state = try? JSONDecoder().decode(WorkspacePersistenceState.self, from: data)
        else { return nil }
        return state
    }

    private func recoverFromCorruption(reason: String) throws {
        if let db { sqlite3_close_v2(db); self.db = nil }
        let stamp = Int(Date().timeIntervalSince1970)
        let aside = fileURL.deletingLastPathComponent()
            .appendingPathComponent(fileURL.lastPathComponent + ".corrupt-\(stamp)")
        try? FileManager.default.moveItem(at: fileURL, to: aside)
        // WAL side files would poison the fresh database — move them too.
        for ext in ["-wal", "-shm"] {
            let side = fileURL.deletingLastPathComponent()
                .appendingPathComponent(fileURL.lastPathComponent + ext)
            try? FileManager.default.removeItem(at: side)
        }
        try open()
    }

    // MARK: - SQLite plumbing

    private func open() throws {
        var handle: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        guard sqlite3_open_v2(fileURL.path, &handle, flags, nil) == SQLITE_OK, let handle else {
            let message = handle.map { String(cString: sqlite3_errmsg($0)) } ?? "unknown"
            if let handle { sqlite3_close_v2(handle) }
            throw SQLiteError.openFailed(message)
        }
        db = handle
        try exec("PRAGMA journal_mode=WAL")
        try exec("""
        CREATE TABLE IF NOT EXISTS workspace_meta(
            key TEXT PRIMARY KEY,
            value TEXT NOT NULL
        )
        """)
        try exec("""
        CREATE TABLE IF NOT EXISTS projects(
            id TEXT PRIMARY KEY,
            position INTEGER NOT NULL,
            name TEXT NOT NULL,
            payload TEXT NOT NULL
        )
        """)
        for table in Self.collectionTables {
            try exec("""
            CREATE TABLE IF NOT EXISTS \(table)(
                id TEXT PRIMARY KEY,
                project_id TEXT NOT NULL,
                position INTEGER NOT NULL,
                payload TEXT NOT NULL
            )
            """)
            try exec("CREATE INDEX IF NOT EXISTS idx_\(table)_project ON \(table)(project_id)")
        }
    }

    private func exec(_ sql: String) throws {
        guard let db else { throw SQLiteError.openFailed("database is not open") }
        var errorMessage: UnsafeMutablePointer<CChar>?
        guard sqlite3_exec(db, sql, nil, nil, &errorMessage) == SQLITE_OK else {
            let message = errorMessage.map { String(cString: $0) } ?? "unknown"
            sqlite3_free(errorMessage)
            throw SQLiteError.execFailed(message)
        }
    }

    private func run(_ sql: String, bind values: [String?]) throws {
        guard let db else { throw SQLiteError.openFailed("database is not open") }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw SQLiteError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        for (i, value) in values.enumerated() {
            let index = Int32(i + 1)
            if let value {
                sqlite3_bind_text(stmt, index, value, -1, Self.transient)
            } else {
                sqlite3_bind_null(stmt, index)
            }
        }
        guard sqlite3_step(stmt) == SQLITE_DONE else {
            throw SQLiteError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
    }

    private func query(_ sql: String, row: (OpaquePointer) -> Void) throws {
        guard let db else { throw SQLiteError.openFailed("database is not open") }
        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &stmt, nil) == SQLITE_OK, let stmt else {
            throw SQLiteError.execFailed(String(cString: sqlite3_errmsg(db)))
        }
        defer { sqlite3_finalize(stmt) }
        while true {
            let code = sqlite3_step(stmt)
            if code == SQLITE_ROW {
                row(stmt)
            } else if code == SQLITE_DONE {
                break
            } else {
                throw SQLiteError.execFailed(String(cString: sqlite3_errmsg(db)))
            }
        }
    }

    private static func column(_ stmt: OpaquePointer, _ index: Int32) -> String? {
        guard let text = sqlite3_column_text(stmt, index) else { return nil }
        return String(cString: text)
    }

    private func encodeJSON<T: Encodable>(_ value: T, encoder: JSONEncoder) throws -> String {
        guard let string = String(data: try encoder.encode(value), encoding: .utf8) else {
            throw SQLiteError.encodingFailed(String(describing: T.self))
        }
        return string
    }

    private func decodeMeta<T: Decodable>(
        _ type: T.Type,
        key: String,
        from meta: [String: String],
        decoder: JSONDecoder
    ) throws -> T? {
        guard let value = meta[key], let data = value.data(using: .utf8) else { return nil }
        do {
            return try decoder.decode(type, from: data)
        } catch {
            throw SQLiteError.decodingFailed("\(key): \(error.localizedDescription)")
        }
    }

    private func insertMeta(_ key: String, _ value: String, encoder: JSONEncoder) throws {
        try run("INSERT OR REPLACE INTO workspace_meta(key, value) VALUES (?,?)", bind: [key, value])
    }

    private func insertCollection<T: Codable & Identifiable>(
        _ table: String,
        _ projectID: UUID,
        _ records: [T]?,
        encoder: JSONEncoder
    ) throws where T.ID == UUID {
        guard let records else { return }
        for (index, record) in records.enumerated() {
            try run(
                "INSERT OR REPLACE INTO \(table)(id, project_id, position, payload) VALUES (?,?,?,?)",
                bind: [record.id.uuidString, projectID.uuidString, String(index), try encodeJSON(record, encoder: encoder)]
            )
        }
    }
}
