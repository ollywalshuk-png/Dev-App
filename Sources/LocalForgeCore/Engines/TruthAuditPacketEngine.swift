import Foundation

/// Renders a compact, redaction-safe Markdown packet for a selected snapshot.
///
/// This engine does not compute new truth semantics. It delegates scoring,
/// confidence, register health, provenance, and truth debt to the existing
/// engines, then applies deterministic ordering, stable limits, and redaction.
public struct TruthAuditPacketEngine: Sendable {
    private let truthEngine: TruthEngine
    private let truthDebtEngine: TruthDebtEngine
    private let reportEngine: ReportEngine

    public init(
        truthEngine: TruthEngine = TruthEngine(),
        truthDebtEngine: TruthDebtEngine = TruthDebtEngine(),
        reportEngine: ReportEngine = ReportEngine()
    ) {
        self.truthEngine = truthEngine
        self.truthDebtEngine = truthDebtEngine
        self.reportEngine = reportEngine
    }

    public func markdownPacket(
        for snapshot: RepoSnapshot,
        evidence: [EvidenceRecord] = [],
        decisions: [DecisionRecord] = [],
        risks: [RiskRecord] = [],
        architecture: [ArchitectureItem] = [],
        assumptions: [AssumptionRecord] = [],
        positiveContributionLimit: Int = 3,
        negativeContributionLimit: Int = 3,
        actionLimit: Int = 5
    ) -> String {
        let confidence = truthEngine.confidence(
            snapshot: snapshot,
            evidence: evidence,
            assumptions: assumptions
        )
        let registerHealth = truthEngine.registerHealth(
            snapshot: snapshot,
            evidence: evidence,
            decisions: decisions,
            risks: risks,
            architecture: architecture,
            assumptions: assumptions
        )
        let provenance = truthEngine.contributionProvenance(
            snapshot: snapshot,
            evidence: evidence,
            risks: risks,
            assumptions: assumptions
        )
        let debtReport = truthDebtEngine.report(
            snapshot: snapshot,
            evidence: evidence,
            risks: risks,
            assumptions: assumptions
        )

        let positiveRows = topRows(
            provenance,
            direction: .positive,
            limit: positiveContributionLimit
        )
        let negativeRows = topRows(
            provenance,
            direction: .negative,
            limit: negativeContributionLimit
        )
        let nextActions = Array(debtReport.nextActions.prefix(max(0, actionLimit)))
        let warnings = confidenceWarnings(
            confidence: confidence,
            debtReport: debtReport
        )

        var lines: [String] = [
            "# Truth Audit Packet",
            "",
            "- Project: \(safeText(snapshot.project.name))",
            "- Reality: \(snapshot.reality.score)% - \(safeText(snapshot.reality.currentState))",
            "- Next action: \(safeText(snapshot.reality.nextAction))",
            "",
            "## Confidence",
            "- Score: \(confidence.score)% (\(safeText(confidence.label)))",
            "- Summary: \(safeText(confidence.summary))"
        ]

        appendConfidenceWarnings(warnings, to: &lines)

        lines += [
            "",
            "## Register Health",
            "- Coverage: Evidence \(percent(registerHealth.evidenceCoverage))%, Risks \(percent(registerHealth.riskCoverage))%, Decisions \(percent(registerHealth.decisionCoverage))%, Architecture \(percent(registerHealth.architectureCoverage))%, Assumptions \(percent(registerHealth.assumptionCoverage))%",
            "",
            "## Positive Provenance"
        ]

        appendProvenanceRows(positiveRows, to: &lines)
        lines.append("")
        lines.append("## Negative Provenance")
        appendProvenanceRows(negativeRows, to: &lines)

        lines += [
            "",
            "## Truth Debt",
            "- Status: \(safeText(debtReport.status.rawValue))",
            "- Headline: \(safeText(debtReport.headline))",
            "- Blockers: \(debtReport.blockers.count)",
            "- Caveats: \(debtReport.caveats.count)",
            "- Total gates: \(debtReport.gates.count)",
            "",
            "## Next Actions"
        ]

        if nextActions.isEmpty {
            lines.append("- None")
        } else {
            for (index, action) in nextActions.enumerated() {
                lines.append("\(index + 1). \(safeText(action))")
            }
        }

        return reportEngine.redact(lines.joined(separator: "\n"))
    }

    private func appendConfidenceWarnings(
        _ warnings: [String],
        to lines: inout [String]
    ) {
        lines.append("")
        lines.append("## Confidence Warnings")

        guard !warnings.isEmpty else {
            lines.append("- None")
            return
        }

        for warning in warnings {
            lines.append("- \(safeText(warning))")
        }
    }

    private func appendProvenanceRows(
        _ rows: [TruthContributionProvenanceRow],
        to lines: inout [String]
    ) {
        guard !rows.isEmpty else {
            lines.append("- None")
            return
        }

        lines.append("| Source | Area | Status | Freshness | Release | Reason |")
        lines.append("| --- | --- | --- | --- | --- | --- |")
        for row in rows {
            lines.append([
                safeText(compactSource(for: row), fallback: "Unknown"),
                safeText(row.sourceArea, fallback: "-"),
                safeText(row.status, fallback: "-"),
                safeText(row.freshness?.rawValue ?? "-", fallback: "-"),
                row.releaseRelevant ? "Yes" : "No",
                safeText(row.reason)
            ].joined(separator: " | ").pipeRow)
        }
    }

    private func topRows(
        _ rows: [TruthContributionProvenanceRow],
        direction: TruthContributionDirection,
        limit: Int
    ) -> [TruthContributionProvenanceRow] {
        guard limit > 0 else { return [] }
        return Array(
            rows
                .filter { $0.direction == direction }
                .sorted(by: provenancePrecedes)
                .prefix(limit)
        )
    }

    private func confidenceWarnings(
        confidence: ConfidenceAssessment,
        debtReport: TruthDebtReport
    ) -> [String] {
        var warnings: [String] = []

        if confidence.score < 55 {
            var warning = "Weak confidence: \(confidence.score)% (\(confidence.label)) - \(confidence.summary)"
            let drivers = confidence.contributions
                .filter { $0.delta < 0 }
                .sorted(by: contributionPrecedes)
                .prefix(3)
                .map { "\($0.label) (\($0.delta))" }
            if !drivers.isEmpty {
                warning += " Drivers: \(drivers.joined(separator: "; "))"
            }
            warnings.append(warning)
        }

        let assumptionGates = warningGates(
            from: debtReport,
            kind: .activeAssumption
        )
        if !assumptionGates.isEmpty {
            let blockers = assumptionGates.filter(\.blocksReleaseClaim).count
            warnings.append(
                "Assumptions: \(assumptionGates.count) active assumption gate(s); \(blockers) block release claims. Top: \(gateSummary(assumptionGates))"
            )
        }

        let contradictionGates = warningGates(
            from: debtReport,
            kind: .contradictoryEvidence
        )
        if !contradictionGates.isEmpty {
            warnings.append(
                "Contradictions: \(contradictionGates.count) contradictory evidence gate(s). Top: \(gateSummary(contradictionGates))"
            )
        }

        let staleGates = warningGates(
            from: debtReport,
            kind: .staleVerification
        )
        if !staleGates.isEmpty {
            warnings.append(
                "Stale evidence: \(staleGates.count) stale/expired verification gate(s). Top: \(gateSummary(staleGates))"
            )
        }

        return warnings
    }

    private func warningGates(
        from report: TruthDebtReport,
        kind: TruthDebtKind
    ) -> [TruthDebtGate] {
        report.gates
            .filter { $0.kind == kind }
            .sorted(by: gatePrecedes)
    }

    private func gateSummary(
        _ gates: [TruthDebtGate],
        limit: Int = 2
    ) -> String {
        gates
            .prefix(max(0, limit))
            .map(\.title)
            .joined(separator: "; ")
    }

    private func contributionPrecedes(
        _ lhs: RealityContribution,
        _ rhs: RealityContribution
    ) -> Bool {
        if lhs.delta != rhs.delta { return lhs.delta < rhs.delta }
        return lhs.label < rhs.label
    }

    private func gatePrecedes(
        _ lhs: TruthDebtGate,
        _ rhs: TruthDebtGate
    ) -> Bool {
        if lhs.blocksReleaseClaim != rhs.blocksReleaseClaim {
            return lhs.blocksReleaseClaim && !rhs.blocksReleaseClaim
        }

        if lhs.severity != rhs.severity { return lhs.severity < rhs.severity }

        let lhsArea = sortKey(lhs.area)
        let rhsArea = sortKey(rhs.area)
        if lhsArea != rhsArea { return lhsArea < rhsArea }

        if lhs.title != rhs.title { return lhs.title < rhs.title }
        return lhs.id < rhs.id
    }

    private func provenancePrecedes(
        _ lhs: TruthContributionProvenanceRow,
        _ rhs: TruthContributionProvenanceRow
    ) -> Bool {
        if lhs.releaseRelevant != rhs.releaseRelevant {
            return lhs.releaseRelevant && !rhs.releaseRelevant
        }

        let lhsKind = sourceKindRank(lhs.sourceKind)
        let rhsKind = sourceKindRank(rhs.sourceKind)
        if lhsKind != rhsKind { return lhsKind < rhsKind }

        let lhsArea = sortKey(lhs.sourceArea)
        let rhsArea = sortKey(rhs.sourceArea)
        if lhsArea != rhsArea { return lhsArea < rhsArea }

        if lhs.status != rhs.status { return lhs.status < rhs.status }

        let lhsFreshness = freshnessRank(lhs.freshness)
        let rhsFreshness = freshnessRank(rhs.freshness)
        if lhsFreshness != rhsFreshness { return lhsFreshness < rhsFreshness }

        if lhs.sourceIdentifier != rhs.sourceIdentifier {
            return lhs.sourceIdentifier < rhs.sourceIdentifier
        }
        return lhs.reason < rhs.reason
    }

    private func sourceKindRank(_ kind: TruthContributionSourceKind) -> Int {
        switch kind {
        case .verification: 0
        case .evidence: 1
        case .mission: 2
        case .risk: 3
        case .assumption: 4
        case .verificationGap: 5
        }
    }

    private func freshnessRank(_ age: VerificationAge?) -> Int {
        switch age {
        case .fresh: 0
        case .recent: 1
        case .ageing: 2
        case .stale: 3
        case .expired: 4
        case .never: 5
        case nil: 6
        }
    }

    private func compactSource(for row: TruthContributionProvenanceRow) -> String {
        let identifier = row.sourceIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !identifier.isEmpty else { return row.sourceKind.rawValue }
        if UUID(uuidString: identifier) != nil {
            return "\(row.sourceKind.rawValue) \(identifier.prefix(8))"
        }
        return "\(row.sourceKind.rawValue) \(identifier)"
    }

    private func percent(_ value: Double) -> Int {
        let clamped = min(1.0, max(0.0, value))
        return Int((clamped * 100).rounded())
    }

    private func safeText(_ text: String, fallback: String = "Unknown") -> String {
        let redacted = reportEngine.redact(text)
            .replacingOccurrences(
                of: #"(?i)\b(token|api[_-]?key|password|secret)\s*[:=]\s*\[REDACTED_SECRET\]"#,
                with: "[REDACTED_SECRET]",
                options: .regularExpression
            )
        let collapsed = redacted
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .replacingOccurrences(of: "|", with: "\\|")
        return collapsed.isEmpty ? fallback : collapsed
    }

    private func sortKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

private extension String {
    var pipeRow: String { "| \(self) |" }
}
