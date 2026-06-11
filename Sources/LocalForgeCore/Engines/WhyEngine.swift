import Foundation

/// Phase 8.5: builds WhyPanelContent for any major record type so the user
/// can always ask "why does this have this state?" and get a traceable answer.
public struct WhyEngine: Sendable {
    public init() {}

    // MARK: - Reality "Why"

    public func whyReality(
        breakdown: RealityBreakdown,
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        decisions: [DecisionRecord]
    ) -> WhyPanelContent {
        var sections: [WhyPanelSection] = []

        let positiveRows = breakdown.positives.map { c in
            WhyPanelRow(label: c.label, value: "+\(c.delta)", isPositive: true, symbolName: "checkmark.circle.fill")
        }
        if !positiveRows.isEmpty {
            sections.append(.init(title: "Positive Contributions", items: positiveRows))
        }

        let negativeRows = breakdown.negatives.map { c in
            WhyPanelRow(label: c.label, value: "\(c.delta)", isNegative: true, symbolName: "exclamationmark.triangle.fill")
        }
        if !negativeRows.isEmpty {
            sections.append(.init(title: "Negative Contributions", items: negativeRows))
        }

        let recentEvidence = evidence.sorted { $0.createdAt > $1.createdAt }.prefix(5)
        if !recentEvidence.isEmpty {
            let rows = recentEvidence.map { e in
                WhyPanelRow(label: e.summary.isEmpty ? e.kind.rawValue : e.summary, value: e.area, symbolName: "paperclip")
            }
            sections.append(.init(title: "Evidence", items: Array(rows)))
        }

        let openDecisions = decisions.filter { $0.status == .accepted }.prefix(5)
        if !openDecisions.isEmpty {
            let rows = openDecisions.map { d in
                WhyPanelRow(label: d.title, value: d.status.rawValue, symbolName: "signpost.right")
            }
            sections.append(.init(title: "Key Decisions", items: Array(rows)))
        }

        return WhyPanelContent(
            title: "Why is the Reality Score \(breakdown.finalScore)?",
            summary: "Score starts at \(breakdown.baseline) and is modified by each contribution below.",
            sections: sections
        )
    }

    // MARK: - Risk "Why"

    public func whyRisk(
        risk: RiskRecord,
        evidence: [EvidenceRecord],
        verification: [VerificationRecord],
        decisions: [DecisionRecord],
        architecture: [ArchitectureItem]
    ) -> WhyPanelContent {
        var sections: [WhyPanelSection] = []

        let riskRows = [
            WhyPanelRow(label: "Likelihood", value: risk.likelihood.rawValue, symbolName: "chart.line.uptrend.xyaxis"),
            WhyPanelRow(label: "Impact", value: risk.impact.rawValue, isNegative: risk.impact == .critical || risk.impact == .high, symbolName: "exclamationmark.shield"),
            WhyPanelRow(label: "Status", value: risk.status.rawValue, symbolName: "flag"),
        ]
        sections.append(.init(title: "Risk Properties", items: riskRows))

        let linkedEvidence = evidence.filter { risk.linkedEvidenceIDs.contains($0.id) }
        if !linkedEvidence.isEmpty {
            let rows = linkedEvidence.map { e in
                WhyPanelRow(label: e.summary.isEmpty ? e.kind.rawValue : e.summary, value: e.classification.rawValue, symbolName: "paperclip")
            }
            sections.append(.init(title: "Linked Evidence", items: rows))
        }

        let linkedVerification = verification.filter { risk.linkedVerificationIDs.contains($0.id) || risk.linkedVerificationAreas.contains($0.area) }
        if !linkedVerification.isEmpty {
            let rows = linkedVerification.map { v in
                WhyPanelRow(label: v.area, value: v.state.rawValue, isPositive: v.state == .verified, isNegative: v.state == .failed, symbolName: v.state.symbolName)
            }
            sections.append(.init(title: "Linked Verification", items: rows))
        }

        let linkedDecisions = decisions.filter { risk.linkedDecisionIDs.contains($0.id) }
        if !linkedDecisions.isEmpty {
            let rows = linkedDecisions.map { d in
                WhyPanelRow(label: d.title, value: d.status.rawValue, symbolName: "signpost.right")
            }
            sections.append(.init(title: "Linked Decisions", items: rows))
        }

        if !risk.mitigation.isEmpty {
            sections.append(.init(title: "Mitigation", items: [
                WhyPanelRow(label: risk.mitigation, isPositive: true, symbolName: "shield.checkered")
            ]))
        }

        return WhyPanelContent(
            title: "Why does this risk exist?",
            summary: risk.description.isEmpty ? risk.title : risk.description,
            sections: sections
        )
    }

    // MARK: - Verification "Why"

    public func whyVerification(
        record: VerificationRecord,
        evidence: [EvidenceRecord],
        journal: [JournalEntry]
    ) -> WhyPanelContent {
        var sections: [WhyPanelSection] = []

        let stateRows = [
            WhyPanelRow(label: "State", value: record.state.rawValue, isPositive: record.state == .verified, isNegative: record.state == .failed, symbolName: record.state.symbolName),
            WhyPanelRow(label: "Age", value: record.ageDescription, isNegative: record.age == .stale || record.age == .expired, symbolName: "clock"),
        ]
        sections.append(.init(title: "Current State", items: stateRows))

        let linkedEvidence = evidence.filter { $0.area == record.area }
        if !linkedEvidence.isEmpty {
            let rows = linkedEvidence.sorted { $0.createdAt > $1.createdAt }.map { e in
                WhyPanelRow(label: e.summary.isEmpty ? e.kind.rawValue : e.summary, value: e.classification.rawValue, symbolName: "paperclip")
            }
            sections.append(.init(title: "Evidence (\(linkedEvidence.count))", items: rows))
        } else {
            sections.append(.init(title: "Evidence", items: [
                WhyPanelRow(label: "No evidence attached to this area", isNegative: true, symbolName: "exclamationmark.circle")
            ]))
        }

        if !record.dependsOn.isEmpty {
            let rows = record.dependsOn.map { dep in
                WhyPanelRow(label: dep, symbolName: "arrow.down.circle")
            }
            sections.append(.init(title: "Dependencies", items: rows))
        }

        let related = journal.filter { $0.kind == .verification && $0.summary.localizedCaseInsensitiveContains(record.area) }.prefix(5)
        if !related.isEmpty {
            let rows = related.map { j in
                WhyPanelRow(label: j.summary, value: j.occurredAt.formatted(date: .abbreviated, time: .omitted), symbolName: "book.pages")
            }
            sections.append(.init(title: "History", items: Array(rows)))
        }

        return WhyPanelContent(
            title: "Why is '\(record.area)' \(record.state.rawValue)?",
            summary: record.note.isEmpty ? "No note recorded." : record.note,
            sections: sections
        )
    }

    // MARK: - Release "Why"

    public func whyRelease(
        board: ReleaseReadinessBoard,
        risks: [RiskRecord]
    ) -> WhyPanelContent {
        var sections: [WhyPanelSection] = []

        let statusRow = WhyPanelRow(
            label: board.headline,
            isPositive: board.status == .ready,
            isNegative: board.status == .blocked || board.status == .notReady,
            symbolName: "flag.checkered"
        )
        sections.append(.init(title: "Release Status", items: [statusRow]))

        let blockers = board.rows.filter { $0.state == .failed }
        if !blockers.isEmpty {
            let rows = blockers.map { r in
                WhyPanelRow(label: r.area, value: "Failed · \(r.priority.rawValue)", isNegative: true, symbolName: "xmark.octagon.fill")
            }
            sections.append(.init(title: "Blocking Failures", items: rows))
        }

        let unverified = board.rows.filter { $0.state == .unknown || $0.state == .inProgress }
        if !unverified.isEmpty {
            let rows = unverified.prefix(8).map { r in
                WhyPanelRow(label: r.area, value: "\(r.state.rawValue) · \(r.priority.rawValue)", symbolName: "clock")
            }
            sections.append(.init(title: "Not Yet Verified (\(unverified.count))", items: Array(rows)))
        }

        let releaseRisks = risks.filter { $0.isReleaseBlocking }
        if !releaseRisks.isEmpty {
            let rows = releaseRisks.map { r in
                WhyPanelRow(label: r.title, value: "\(r.impact.rawValue) risk", isNegative: true, symbolName: "exclamationmark.shield.fill")
            }
            sections.append(.init(title: "Release-Blocking Risks", items: rows))
        }

        return WhyPanelContent(
            title: "Why is release \(board.status.rawValue)?",
            summary: board.headline,
            sections: sections
        )
    }

    // MARK: - Confidence Provenance

    public func confidenceProvenance(
        assessment: ConfidenceAssessment,
        evidence: [EvidenceRecord]
    ) -> ConfidenceProvenance {
        var bySource: [ConfidenceSource: Int] = [:]

        for e in evidence {
            switch e.classification {
            case .observed: bySource[.observed, default: 0] += 1
            case .measured: bySource[.measured, default: 0] += 1
            case .verified: bySource[.verified, default: 0] += 1
            case .inferred: bySource[.inferred, default: 0] += 1
            case .assumed: bySource[.inferred, default: 0] += 1
            case .unknown: bySource[.unknown, default: 0] += 1
            }
        }

        let items = ConfidenceSource.allCases.compactMap { source -> ConfidenceProvenanceItem? in
            let count = bySource[source, default: 0]
            guard count > 0 else { return nil }
            return ConfidenceProvenanceItem(source: source, count: count, label: "\(count) \(source.rawValue.lowercased()) record(s)")
        }

        return ConfidenceProvenance(
            score: assessment.score,
            label: assessment.label,
            items: items
        )
    }

    // MARK: - Evidence Conflicts

    public func detectConflicts(
        evidence: [EvidenceRecord],
        projectID: UUID,
        projectName: String
    ) -> [EvidenceConflict] {
        // Group evidence by area.
        let byArea = Dictionary(grouping: evidence) { $0.area }
        var conflicts: [EvidenceConflict] = []

        for (area, records) in byArea where !area.isEmpty {
            let success = records.filter { e in
                e.classification == .observed || e.classification == .measured || e.classification == .verified
            }
            let failure = records.filter { e in
                e.summary.localizedCaseInsensitiveContains("fail")
                || e.summary.localizedCaseInsensitiveContains("error")
                || e.summary.localizedCaseInsensitiveContains("broken")
                || e.body.localizedCaseInsensitiveContains("fail")
            }

            if !success.isEmpty && !failure.isEmpty {
                conflicts.append(EvidenceConflict(
                    projectID: projectID,
                    projectName: projectName,
                    area: area,
                    successEvidence: success,
                    failureEvidence: failure
                ))
            }
        }

        return conflicts
    }
}
