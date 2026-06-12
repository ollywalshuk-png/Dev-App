import Foundation

// MARK: - Universal Search (Phase 8)

public enum SearchHitKind: String, CaseIterable, Hashable, Sendable {
    case project = "Project"
    case mission = "Mission"
    case verification = "Verification"
    case evidence = "Evidence"
    case journal = "Journal"
    case knowledge = "Knowledge"
    case decision = "Decision"
    case risk = "Risk"
    case architecture = "Architecture"
    case assumption = "Assumption"

    public var symbolName: String {
        switch self {
        case .project: "folder"
        case .mission: "scope"
        case .verification: "checkmark.seal"
        case .evidence: "paperclip"
        case .journal: "book.pages"
        case .knowledge: "archivebox"
        case .decision: "signpost.right"
        case .risk: "exclamationmark.shield"
        case .architecture: "square.3.layers.3d"
        case .assumption: "questionmark.diamond"
        }
    }
}

public struct SearchHit: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var projectName: String
    public var kind: SearchHitKind
    public var recordID: UUID?
    public var title: String
    public var snippet: String
    public var date: Date?
    /// Verification area context, when the hit relates to one (for jumps).
    public var area: String?
    /// True for release-blocking risks and evidence linked to them.
    public var isReleaseBlocking: Bool

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        projectName: String,
        kind: SearchHitKind,
        recordID: UUID? = nil,
        title: String,
        snippet: String,
        date: Date? = nil,
        area: String? = nil,
        isReleaseBlocking: Bool = false
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = projectName
        self.kind = kind
        self.recordID = recordID
        self.title = title
        self.snippet = snippet
        self.date = date
        self.area = area
        self.isReleaseBlocking = isReleaseBlocking
    }
}

/// Case-insensitive substring search across every record type in the workspace.
/// Pure aggregation over already-loaded state — no file IO, no index to corrupt.
public struct SearchEngine: Sendable {
    public init() {}

    public func search(_ rawQuery: String, in records: [PersistedProjectRecord]) -> [SearchHit] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard query.count >= 2 else { return [] }
        var hits: [SearchHit] = []

        for record in records {
            let pid = record.id
            let pname = record.name
            let releaseBlockingRisks = record.risks?.filter(\.isReleaseBlocking) ?? []
            let releaseBlockingRiskIDs = Set(releaseBlockingRisks.map(\.id))
            let releaseBlockingEvidenceIDs = Set(releaseBlockingRisks.flatMap(\.linkedEvidenceIDs))

            if let snippet = match(query, in: [record.name, record.fallbackPath]) {
                hits.append(.init(
                    projectID: pid, projectName: pname, kind: .project,
                    title: record.name, snippet: snippet, date: record.lastOpenedAt
                ))
            }

            if let mission = record.mission {
                let fields = [mission.statedMission, mission.currentPhase]
                    + mission.goals + mission.knownIssues
                if let snippet = match(query, in: fields) {
                    hits.append(.init(
                        projectID: pid, projectName: pname, kind: .mission,
                        title: mission.statedMission.isEmpty ? "Mission" : mission.statedMission,
                        snippet: snippet, date: mission.updatedAt
                    ))
                }
            }

            for v in record.verification ?? [] {
                if let snippet = match(query, in: [v.area, v.note, v.verifiedBy] + v.dependsOn) {
                    hits.append(.init(
                        projectID: pid, projectName: pname, kind: .verification,
                        recordID: v.id, title: "\(v.area) — \(v.state.rawValue)",
                        snippet: snippet, date: v.updatedAt, area: v.area
                    ))
                }
            }

            for e in record.evidence ?? [] {
                let isLinkedToReleaseBlocker = releaseBlockingEvidenceIDs.contains(e.id)
                    || !releaseBlockingRiskIDs.isDisjoint(with: e.linkedRiskIDs)
                let fields = [
                    e.summary,
                    e.body,
                    e.area,
                    e.author,
                    e.attachmentPath,
                    e.kind.rawValue,
                    e.classification.rawValue,
                ]
                if let snippet = match(query, in: fields) {
                    hits.append(.init(
                        projectID: pid, projectName: pname, kind: .evidence,
                        recordID: e.id, title: e.summary, snippet: snippet,
                        date: e.createdAt, area: e.area,
                        isReleaseBlocking: isLinkedToReleaseBlocker
                    ))
                }
            }

            for j in record.journal ?? [] {
                if let snippet = match(query, in: [j.summary, j.detail, j.author]) {
                    hits.append(.init(
                        projectID: pid, projectName: pname, kind: .journal,
                        recordID: j.id, title: j.summary, snippet: snippet, date: j.occurredAt
                    ))
                }
            }

            for n in record.knowledgeNotes ?? [] {
                if let snippet = match(query, in: [n.title, n.body]) {
                    hits.append(.init(
                        projectID: pid, projectName: pname, kind: .knowledge,
                        recordID: n.id, title: n.title.isEmpty ? n.kind.rawValue : n.title,
                        snippet: snippet, date: n.updatedAt
                    ))
                }
            }

            for d in record.decisions ?? [] {
                if let snippet = match(query, in: [d.title, d.decision, d.reason, d.alternativesConsidered, d.tradeOffs]) {
                    hits.append(.init(
                        projectID: pid, projectName: pname, kind: .decision,
                        recordID: d.id, title: d.title, snippet: snippet, date: d.updatedAt
                    ))
                }
            }

            for r in record.risks ?? [] {
                if let snippet = match(query, in: [r.title, r.description, r.mitigation, r.contingency]) {
                    hits.append(.init(
                        projectID: pid, projectName: pname, kind: .risk,
                        recordID: r.id,
                        title: "\(r.title) (\(r.impact.rawValue)/\(r.likelihood.rawValue))",
                        snippet: snippet, date: r.updatedAt,
                        isReleaseBlocking: r.isReleaseBlocking
                    ))
                }
            }

            for a in record.architecture ?? [] {
                if let snippet = match(query, in: [a.name, a.purpose, a.notes] + a.dependencies + a.linkedVerificationAreas) {
                    hits.append(.init(
                        projectID: pid, projectName: pname, kind: .architecture,
                        recordID: a.id, title: a.name, snippet: snippet, date: a.updatedAt
                    ))
                }
            }

            for s in record.assumptions ?? [] {
                if let snippet = match(query, in: [s.assumption, s.rationale, s.verificationNeeded]) {
                    hits.append(.init(
                        projectID: pid, projectName: pname, kind: .assumption,
                        recordID: s.id, title: s.assumption, snippet: snippet, date: s.updatedAt
                    ))
                }
            }
        }

        // Newest first; dateless hits sink to the bottom. Cap to keep the UI sane.
        return Array(
            hits.sorted { ($0.date ?? .distantPast) > ($1.date ?? .distantPast) }.prefix(300)
        )
    }

    /// First field containing the query (case-insensitive), trimmed to a
    /// readable snippet centred on the match.
    private func match(_ query: String, in fields: [String]) -> String? {
        for field in fields where !field.isEmpty {
            if let range = field.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) {
                return snippet(of: field, around: range)
            }
        }
        return nil
    }

    private func snippet(of text: String, around range: Range<String.Index>, radius: Int = 70) -> String {
        let start = text.index(range.lowerBound, offsetBy: -radius, limitedBy: text.startIndex) ?? text.startIndex
        let end = text.index(range.upperBound, offsetBy: radius, limitedBy: text.endIndex) ?? text.endIndex
        var result = String(text[start..<end]).replacingOccurrences(of: "\n", with: " ")
        if start > text.startIndex { result = "…" + result }
        if end < text.endIndex { result += "…" }
        return result
    }
}
