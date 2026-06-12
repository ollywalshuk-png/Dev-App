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

        appendEvidenceProvenance(to: &sections, evidence: evidence)
        appendContradictions(to: &sections, evidence: evidence, projectName: "Current project")

        let recentEvidence = evidence.sorted { $0.createdAt > $1.createdAt }.prefix(5)
        if !recentEvidence.isEmpty {
            let rows = recentEvidence.map { e in
                evidenceRow(e, value: e.area)
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
                evidenceRow(e)
            }
            sections.append(.init(title: "Linked Evidence", items: rows))
            appendEvidenceProvenance(to: &sections, evidence: linkedEvidence)
            appendContradictions(to: &sections, evidence: linkedEvidence, projectName: "Linked risk")
        }

        let linkedVerification = verification.filter { risk.linkedVerificationIDs.contains($0.id) || risk.linkedVerificationAreas.contains($0.area) }
        if !linkedVerification.isEmpty {
            let rows = linkedVerification.map { v in
                WhyPanelRow(label: v.area, value: verificationValue(v), isPositive: v.state == .verified && !isStale(v), isNegative: v.state == .failed || isStale(v), symbolName: v.state.symbolName)
            }
            sections.append(.init(title: "Linked Verification", items: rows))
            appendStaleVerification(to: &sections, verification: linkedVerification)
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
                evidenceRow(e)
            }
            sections.append(.init(title: "Evidence (\(linkedEvidence.count))", items: rows))
            appendEvidenceProvenance(to: &sections, evidence: linkedEvidence)
            appendContradictions(to: &sections, evidence: linkedEvidence, projectName: "Verification")
        } else {
            sections.append(.init(title: "Evidence", items: [
                WhyPanelRow(label: "No evidence attached to this area", isNegative: true, symbolName: "exclamationmark.circle")
            ]))
        }

        appendStaleVerification(to: &sections, verification: [record])

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
        var byClassification: [EvidenceClassification: Int] = [:]

        for e in evidence {
            byClassification[e.classification, default: 0] += 1
        }

        let items = evidenceClassificationOrder.compactMap { classification -> ConfidenceProvenanceItem? in
            let count = byClassification[classification, default: 0]
            guard count > 0 else { return nil }
            return ConfidenceProvenanceItem(
                source: confidenceSource(for: classification),
                count: count,
                label: "\(count) \(classification.rawValue.lowercased()) record(s)"
            )
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
        // Group evidence by the same area semantics used by truth gates:
        // whitespace and case do not create separate areas.
        let byArea = Dictionary(grouping: evidence) { normalizedArea($0.area) }
        var conflicts: [EvidenceConflict] = []

        for (areaKey, records) in byArea where !areaKey.isEmpty {
            let success = records.filter(isSuccessEvidence)
            let failure = records.filter(isFailureEvidence)

            if !success.isEmpty && !failure.isEmpty {
                let area = records
                    .map { $0.area.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .first { !$0.isEmpty } ?? areaKey
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

    // MARK: - Provenance Helpers

    private var evidenceClassificationOrder: [EvidenceClassification] {
        [.verified, .measured, .observed, .inferred, .assumed, .unknown]
    }

    private func appendEvidenceProvenance(to sections: inout [WhyPanelSection], evidence: [EvidenceRecord]) {
        let rows = evidenceProvenanceRows(for: evidence)
        guard !rows.isEmpty else { return }
        sections.append(.init(title: "Evidence Provenance", items: rows))
    }

    private func normalizedArea(_ area: String) -> String {
        area.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func evidenceProvenanceRows(for evidence: [EvidenceRecord]) -> [WhyPanelRow] {
        var counts: [EvidenceClassification: Int] = [:]
        for record in evidence {
            counts[record.classification, default: 0] += 1
        }

        return evidenceClassificationOrder.compactMap { classification in
            let count = counts[classification, default: 0]
            guard count > 0 else { return nil }
            return WhyPanelRow(
                label: "\(classification.rawValue) evidence",
                value: "\(count) record(s)",
                isPositive: classification == .verified || classification == .measured || classification == .observed,
                isNegative: classification == .assumed || classification == .unknown,
                symbolName: symbolName(for: classification)
            )
        }
    }

    private func appendStaleVerification(to sections: inout [WhyPanelSection], verification: [VerificationRecord]) {
        let stale = verification.filter(isStale)
        guard !stale.isEmpty else { return }

        let rows = stale.map { record in
            WhyPanelRow(
                label: record.area,
                value: "\(record.age.rawValue)\(record.ageDescription.isEmpty ? "" : " · \(record.ageDescription)")",
                isNegative: true,
                symbolName: "clock.badge.exclamationmark"
            )
        }
        sections.append(.init(title: "Stale Records", items: rows))
    }

    private func appendContradictions(to sections: inout [WhyPanelSection], evidence: [EvidenceRecord], projectName: String) {
        let conflicts = detectConflicts(evidence: evidence, projectID: UUID(), projectName: projectName)
        guard !conflicts.isEmpty else { return }

        let rows = conflicts.map { conflict in
            WhyPanelRow(
                label: conflict.area,
                value: "\(conflict.successEvidence.count) passing / \(conflict.failureEvidence.count) failing",
                isNegative: true,
                symbolName: "exclamationmark.triangle.fill"
            )
        }
        sections.append(.init(title: "Contradictory Evidence", items: rows))
    }

    private func evidenceRow(_ evidence: EvidenceRecord, value overrideValue: String? = nil) -> WhyPanelRow {
        let value = overrideValue ?? "\(evidence.classification.rawValue) · \(evidence.kind.rawValue)"
        return WhyPanelRow(
            label: evidence.summary.isEmpty ? evidence.kind.rawValue : evidence.summary,
            value: value,
            isPositive: evidence.classification == .verified || evidence.classification == .measured || evidence.classification == .observed,
            isNegative: evidence.classification == .assumed || evidence.classification == .unknown || isFailureEvidence(evidence),
            symbolName: evidence.kind.symbolName
        )
    }

    private func verificationValue(_ record: VerificationRecord) -> String {
        let age = record.ageDescription
        guard !age.isEmpty else { return record.state.rawValue }
        return "\(record.state.rawValue) · \(age)"
    }

    private func isStale(_ record: VerificationRecord) -> Bool {
        record.state == .verified && (record.age == .stale || record.age == .expired)
    }

    private func confidenceSource(for classification: EvidenceClassification) -> ConfidenceSource {
        switch classification {
        case .observed: .observed
        case .measured: .measured
        case .verified: .verified
        case .inferred, .assumed: .inferred
        case .unknown: .unknown
        }
    }

    private func symbolName(for classification: EvidenceClassification) -> String {
        switch classification {
        case .observed: "eye"
        case .measured: "chart.bar"
        case .verified: "checkmark.seal"
        case .inferred: "wand.and.stars"
        case .assumed: "questionmark.diamond"
        case .unknown: "questionmark.circle"
        }
    }

    private func isSuccessEvidence(_ evidence: EvidenceRecord) -> Bool {
        guard isStrongEvidence(evidence.classification), !isFailureEvidence(evidence) else { return false }
        if evidence.classification == .verified { return true }
        return containsSuccessSignal(in: "\(evidence.summary) \(evidence.body)")
    }

    private func isFailureEvidence(_ evidence: EvidenceRecord) -> Bool {
        guard isStrongEvidence(evidence.classification) else { return false }
        return containsFailureSignal(in: "\(evidence.summary) \(evidence.body)")
    }

    private func isStrongEvidence(_ classification: EvidenceClassification) -> Bool {
        classification == .observed || classification == .measured || classification == .verified
    }

    private func containsSuccessSignal(in text: String) -> Bool {
        text.range(
            of: #"(?i)\b(pass(?:ed|es|ing)?|success(?:ful|fully)?|succeeded|works|working|green|clean|accepted|valid(?:ated)?|verified)\b"#,
            options: .regularExpression
        ) != nil
    }

    private func containsFailureSignal(in text: String) -> Bool {
        if text.range(
            of: #"(?i)\b(no|without|zero|0)\s+(fail(?:ed|ing|s|ure|ures)?|error(?:s)?|crash(?:es|ed)?)\b"#,
            options: .regularExpression
        ) != nil {
            return false
        }

        return text.range(
            of: #"(?i)\b(fail(?:ed|ing|s|ure|ures)?|error(?:s)?|broken|crash(?:ed|es)?|timeout|timed out|blocked|regression)\b"#,
            options: .regularExpression
        ) != nil
    }
}
