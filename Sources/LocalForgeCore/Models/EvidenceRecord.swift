import Foundation

/// Phase 7: an attachable piece of evidence backing a verification record.
/// Notes, screenshots, log paths, environment details, and links to journal /
/// other verification records. Local-only — no upload, no remote linking.
public enum EvidenceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case observation = "Observation"
    case reproduction = "Reproduction"
    case logExcerpt = "Log Excerpt"
    case environment = "Environment"
    case attachment = "Attachment"
    case journalLink = "Journal Link"
    case verificationLink = "Verification Link"
    case decisionLink = "Decision Link"

    public var symbolName: String {
        switch self {
        case .observation: "eye"
        case .reproduction: "arrow.triangle.2.circlepath"
        case .logExcerpt: "doc.plaintext"
        case .environment: "gear"
        case .attachment: "paperclip"
        case .journalLink: "book.pages"
        case .verificationLink: "checkmark.seal"
        case .decisionLink: "signpost.right"
        }
    }
}

/// A single piece of evidence. Body is free-form; `attachmentPath` is an
/// optional reference to a local file the user has on disk (we never copy or
/// upload it — we just remember where it is).
public struct EvidenceRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    /// Area name this evidence backs (e.g. "Preset System").
    public var area: String
    public var kind: EvidenceKind
    public var summary: String
    public var body: String
    /// Local file path (read-only; we only remember the reference).
    public var attachmentPath: String
    /// UUID of a linked `JournalEntry`, `VerificationRecord`, or `KnowledgeNote`.
    public var linkedID: UUID?
    public var classification: EvidenceClassification
    public var author: String
    public var createdAt: Date
    // Phase 7.5: real UUID cross-links instead of free-text references.
    public var linkedVerificationIDs: [UUID]
    public var linkedRiskIDs: [UUID]
    public var linkedDecisionIDs: [UUID]
    public var linkedArchitectureIDs: [UUID]
    public var linkedAssumptionIDs: [UUID]
    public var linkedJournalIDs: [UUID]
    public var linkedNoteIDs: [UUID]

    public init(
        id: UUID = UUID(),
        area: String,
        kind: EvidenceKind = .observation,
        summary: String,
        body: String = "",
        attachmentPath: String = "",
        linkedID: UUID? = nil,
        classification: EvidenceClassification = .observed,
        author: String = "",
        createdAt: Date = Date(),
        linkedVerificationIDs: [UUID] = [],
        linkedRiskIDs: [UUID] = [],
        linkedDecisionIDs: [UUID] = [],
        linkedArchitectureIDs: [UUID] = [],
        linkedAssumptionIDs: [UUID] = [],
        linkedJournalIDs: [UUID] = [],
        linkedNoteIDs: [UUID] = []
    ) {
        self.id = id
        self.area = area
        self.kind = kind
        self.summary = summary
        self.body = body
        self.attachmentPath = attachmentPath
        self.linkedID = linkedID
        self.classification = classification
        self.author = author
        self.createdAt = createdAt
        self.linkedVerificationIDs = linkedVerificationIDs
        self.linkedRiskIDs = linkedRiskIDs
        self.linkedDecisionIDs = linkedDecisionIDs
        self.linkedArchitectureIDs = linkedArchitectureIDs
        self.linkedAssumptionIDs = linkedAssumptionIDs
        self.linkedJournalIDs = linkedJournalIDs
        self.linkedNoteIDs = linkedNoteIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, area, kind, summary, body, attachmentPath, linkedID, classification, author, createdAt
        case linkedVerificationIDs, linkedRiskIDs, linkedDecisionIDs, linkedArchitectureIDs, linkedAssumptionIDs, linkedJournalIDs, linkedNoteIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        area = try c.decode(String.self, forKey: .area)
        kind = try c.decodeIfPresent(EvidenceKind.self, forKey: .kind) ?? .observation
        summary = try c.decode(String.self, forKey: .summary)
        body = try c.decodeIfPresent(String.self, forKey: .body) ?? ""
        attachmentPath = try c.decodeIfPresent(String.self, forKey: .attachmentPath) ?? ""
        linkedID = try c.decodeIfPresent(UUID.self, forKey: .linkedID)
        classification = try c.decodeIfPresent(EvidenceClassification.self, forKey: .classification) ?? .observed
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        linkedVerificationIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedVerificationIDs) ?? []
        linkedRiskIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedRiskIDs) ?? []
        linkedDecisionIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedDecisionIDs) ?? []
        linkedArchitectureIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedArchitectureIDs) ?? []
        linkedAssumptionIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedAssumptionIDs) ?? []
        linkedJournalIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedJournalIDs) ?? []
        linkedNoteIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedNoteIDs) ?? []
    }
}
