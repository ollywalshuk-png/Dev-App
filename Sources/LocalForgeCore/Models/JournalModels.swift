import Foundation

/// Phase 6: the Project Journal. An append-only timeline of meaningful events
/// per project — verifications, mission changes, knowledge notes, setup, and
/// free-form developer entries. Becomes institutional memory: when the developer,
/// Codex, or Claude come back six months later, the journal answers "what
/// happened on this project and why".
public enum JournalEntryKind: String, Codable, CaseIterable, Hashable, Sendable {
    case verification = "Verification"
    case mission = "Mission"
    case knowledge = "Knowledge"
    case setup = "Setup"
    case note = "Note"
    case decision = "Decision"

    public var symbolName: String {
        switch self {
        case .verification: "checkmark.seal"
        case .mission: "scope"
        case .knowledge: "archivebox"
        case .setup: "wand.and.stars"
        case .note: "square.and.pencil"
        case .decision: "signpost.right"
        }
    }
}

public struct JournalEntry: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: JournalEntryKind
    public var summary: String
    public var detail: String
    public var author: String
    public var occurredAt: Date

    public init(
        id: UUID = UUID(),
        kind: JournalEntryKind,
        summary: String,
        detail: String = "",
        author: String = "",
        occurredAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.summary = summary
        self.detail = detail
        self.author = author
        self.occurredAt = occurredAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, kind, summary, detail, author, occurredAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        kind = try c.decodeIfPresent(JournalEntryKind.self, forKey: .kind) ?? .note
        summary = try c.decode(String.self, forKey: .summary)
        detail = try c.decodeIfPresent(String.self, forKey: .detail) ?? ""
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        occurredAt = try c.decodeIfPresent(Date.self, forKey: .occurredAt) ?? Date()
    }
}
