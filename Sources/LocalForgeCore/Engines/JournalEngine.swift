import Foundation

/// Append-only journal manager. Stays in `LocalForgeCore` so the GUI/CLI both
/// produce identically-formatted entries. The engine itself is stateless; the
/// store passes the existing array in and gets a new one back.
public struct JournalEngine: Sendable {
    public init() {}

    public func appending(_ entry: JournalEntry, to existing: [JournalEntry]) -> [JournalEntry] {
        var result = existing
        result.insert(entry, at: 0)
        // Keep journals reasonable; the user can rotate manually later. 500 is plenty
        // for years of normal use without ballooning UserDefaults.
        if result.count > 500 {
            result = Array(result.prefix(500))
        }
        return result
    }

    /// Group entries by calendar day (most recent first) for timeline display.
    public func grouped(_ entries: [JournalEntry], calendar: Calendar = .current) -> [(day: Date, entries: [JournalEntry])] {
        let sorted = entries.sorted { $0.occurredAt > $1.occurredAt }
        var buckets: [Date: [JournalEntry]] = [:]
        for entry in sorted {
            let day = calendar.startOfDay(for: entry.occurredAt)
            buckets[day, default: []].append(entry)
        }
        return buckets
            .sorted { $0.key > $1.key }
            .map { (day: $0.key, entries: $0.value) }
    }

    // MARK: - Standard entry builders (used by the store so phrasing is consistent)

    public func verificationEntry(area: String, state: VerificationState, note: String, author: String) -> JournalEntry {
        let summary = "\(area) → \(state.rawValue)"
        let detail = note.isEmpty ? "" : note
        return JournalEntry(kind: .verification, summary: summary, detail: detail, author: author)
    }

    public func missionEntry(stated: String, phase: String, author: String) -> JournalEntry {
        let summary = "Mission set: \(stated)"
        let detail = phase.isEmpty ? "" : "Current phase: \(phase)"
        return JournalEntry(kind: .mission, summary: summary, detail: detail, author: author)
    }

    public func knowledgeEntry(title: String, kind noteKind: KnowledgeNoteKind, author: String) -> JournalEntry {
        JournalEntry(
            kind: .knowledge,
            summary: "[\(noteKind.rawValue)] \(title)",
            detail: "",
            author: author
        )
    }

    public func setupEntry(author: String) -> JournalEntry {
        JournalEntry(kind: .setup, summary: "Project setup completed", detail: "", author: author)
    }
}
