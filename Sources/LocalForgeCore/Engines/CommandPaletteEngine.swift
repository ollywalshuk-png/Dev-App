import Foundation

/// Phase 8.5: builds the list of searchable items + actions for the global
/// command palette (⌘K). Pure function over loaded workspace state — no IO,
/// no index to corrupt. Fuzzy substring matching, SQLite-backed via the
/// same records the rest of the system uses.
public struct CommandPaletteEngine: Sendable {
    public init() {}

    public func items(
        query: String,
        records: [PersistedProjectRecord],
        projectNames: [UUID: String]
    ) -> [CommandPaletteItem] {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        var results: [CommandPaletteItem] = []

        // Always include global actions (filtered by query).
        results += globalActions(matching: q)

        for record in records {
            let pid = record.id
            let pname = projectNames[pid] ?? record.name

            // Project itself.
            if q.isEmpty || fuzzyMatch(q, in: pname) {
                results.append(.init(
                    kind: .project,
                    title: pname,
                    subtitle: "Open project",
                    projectID: pid,
                    projectName: pname,
                    actionKind: .openProject,
                    relevance: relevance(q, in: pname)
                ))
            }

            // Verifications.
            for v in record.verification ?? [] {
                if q.isEmpty || fuzzyMatch(q, in: v.area) || fuzzyMatch(q, in: v.note) {
                    results.append(.init(
                        kind: .verification,
                        title: v.area,
                        subtitle: "\(v.state.rawValue) · \(pname)",
                        projectID: pid,
                        projectName: pname,
                        recordID: v.id,
                        actionKind: .openVerification,
                        relevance: relevance(q, in: v.area)
                    ))
                }
            }

            // Evidence.
            for e in record.evidence ?? [] {
                if q.isEmpty || fuzzyMatch(q, in: e.summary) || fuzzyMatch(q, in: e.area) {
                    results.append(.init(
                        kind: .evidence,
                        title: e.summary.isEmpty ? e.kind.rawValue : e.summary,
                        subtitle: "Evidence · \(e.area) · \(pname)",
                        projectID: pid,
                        projectName: pname,
                        recordID: e.id,
                        actionKind: .openEvidence,
                        relevance: relevance(q, in: e.summary)
                    ))
                }
            }

            // Risks.
            for r in record.risks ?? [] {
                if q.isEmpty || fuzzyMatch(q, in: r.title) || fuzzyMatch(q, in: r.description) {
                    results.append(.init(
                        kind: .risk,
                        title: r.title,
                        subtitle: "\(r.status.rawValue) · \(r.impact.rawValue) · \(pname)",
                        projectID: pid,
                        projectName: pname,
                        recordID: r.id,
                        actionKind: .openRisk,
                        relevance: relevance(q, in: r.title)
                    ))
                }
            }

            // Decisions.
            for d in record.decisions ?? [] {
                if q.isEmpty || fuzzyMatch(q, in: d.title) || fuzzyMatch(q, in: d.decision) {
                    results.append(.init(
                        kind: .decision,
                        title: d.title,
                        subtitle: "\(d.status.rawValue) · \(pname)",
                        projectID: pid,
                        projectName: pname,
                        recordID: d.id,
                        actionKind: .openDecision,
                        relevance: relevance(q, in: d.title)
                    ))
                }
            }

            // Architecture.
            for a in record.architecture ?? [] {
                if q.isEmpty || fuzzyMatch(q, in: a.name) || fuzzyMatch(q, in: a.purpose) {
                    results.append(.init(
                        kind: .architecture,
                        title: a.name,
                        subtitle: "\(a.status.rawValue) · \(a.subsystemType.rawValue) · \(pname)",
                        projectID: pid,
                        projectName: pname,
                        recordID: a.id,
                        actionKind: .openArchitecture,
                        relevance: relevance(q, in: a.name)
                    ))
                }
            }

            // Assumptions.
            for s in record.assumptions ?? [] {
                if q.isEmpty || fuzzyMatch(q, in: s.assumption) || fuzzyMatch(q, in: s.rationale) {
                    results.append(.init(
                        kind: .assumption,
                        title: s.assumption,
                        subtitle: "\(s.status.rawValue) · \(pname)",
                        projectID: pid,
                        projectName: pname,
                        recordID: s.id,
                        actionKind: .openAssumption,
                        relevance: relevance(q, in: s.assumption)
                    ))
                }
            }

            // Journal.
            for j in record.journal ?? [] {
                if fuzzyMatch(q, in: j.summary) {
                    results.append(.init(
                        kind: .journal,
                        title: j.summary,
                        subtitle: "Journal · \(pname)",
                        projectID: pid,
                        projectName: pname,
                        recordID: j.id,
                        actionKind: .openJournal,
                        relevance: relevance(q, in: j.summary)
                    ))
                }
            }

            // Knowledge notes.
            for n in record.knowledgeNotes ?? [] {
                if q.isEmpty || fuzzyMatch(q, in: n.title) || fuzzyMatch(q, in: n.body) {
                    results.append(.init(
                        kind: .knowledge,
                        title: n.title.isEmpty ? n.kind.rawValue : n.title,
                        subtitle: "Knowledge · \(pname)",
                        projectID: pid,
                        projectName: pname,
                        recordID: n.id,
                        actionKind: .openJournal,
                        relevance: relevance(q, in: n.title)
                    ))
                }
            }
        }

        // Sort: exact title match first, then by relevance descending, then kind order.
        return Array(
            results
                .sorted { lhs, rhs in
                    if lhs.relevance != rhs.relevance { return lhs.relevance > rhs.relevance }
                    return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
                }
                .prefix(60)
        )
    }

    // MARK: - Global actions

    private func globalActions(matching q: String) -> [CommandPaletteItem] {
        let all: [(CommandPaletteActionKind, String, String)] = [
            (.openTimeline, "Open Timeline", "timeline.selection"),
            (.openReport, "Open Reports", "doc.text"),
            (.generateHandoff, "Generate Handoff", "paperplane"),
            (.openTruthCentre, "Open Truth Centre", "checkmark.shield.fill"),
            (.openReleaseReadiness, "Open Release Readiness", "flag.checkered"),
            (.openWorkspaceHealth, "Open Workspace Health", "heart.text.square"),
            (.openWorkspaceDoctor, "Open Workspace Doctor", "stethoscope"),
            (.openBackupCentre, "Open Backup Centre", "externaldrive"),
            (.openUtilityCentre, "Open Utility Centre", "wrench.and.screwdriver"),
        ]
        return all.compactMap { (actionKind, title, _) in
            guard q.isEmpty || fuzzyMatch(q, in: title) else { return nil }
            return CommandPaletteItem(
                kind: .action,
                title: title,
                subtitle: "Action",
                actionKind: actionKind,
                relevance: relevance(q, in: title)
            )
        }
    }

    // MARK: - Fuzzy matching

    /// Fuzzy substring: all query characters must appear in order in the target.
    private func fuzzyMatch(_ query: String, in target: String) -> Bool {
        guard !query.isEmpty else { return true }
        // Fast path: substring.
        if target.range(of: query, options: [.caseInsensitive, .diacriticInsensitive]) != nil {
            return true
        }
        // Fuzzy: every character of query appears in order.
        var idx = target.startIndex
        for ch in query.lowercased() {
            guard let found = target.lowercased()[idx...].firstIndex(of: ch) else { return false }
            idx = target.index(after: found)
        }
        return true
    }

    /// Higher = better match. Exact match > prefix > substring > fuzzy > none.
    private func relevance(_ query: String, in target: String) -> Int {
        guard !query.isEmpty else { return 0 }
        let t = target.lowercased()
        let q = query.lowercased()
        if t == q { return 100 }
        if t.hasPrefix(q) { return 80 }
        if t.range(of: q, options: [.caseInsensitive, .diacriticInsensitive]) != nil { return 60 }
        return 20
    }
}
