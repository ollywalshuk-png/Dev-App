import Foundation

public struct TruthDebtEngine: Sendable {
    public init() {}

    public func report(
        snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        assumptions: [AssumptionRecord]
    ) -> TruthDebtReport {
        let inScope = snapshot.applicability.filter { $0.status.inScope }
        let applicabilityByArea = inScope.reduce(into: [String: ApplicabilityItem]()) { items, item in
            items[item.area] = item
        }
        let verificationByArea = Dictionary(grouping: snapshot.verification, by: \.area)
        let stateByArea = snapshot.verification.reduce(into: [String: VerificationState]()) { states, record in
            states[record.area] = record.state
        }
        let releaseBlockingRiskIDs = Set(risks.filter(\.isReleaseBlocking).map(\.id))

        var gates: [TruthDebtGate] = []

        if snapshot.userMission?.isDefined != true, !inScope.isEmpty {
            gates.append(TruthDebtGate(
                kind: .missingMission,
                severity: .high,
                title: "User-stated mission is missing",
                detail: "The Truth Centre cannot defend the percentage as project-specific release truth without the user's mission.",
                recommendedAction: "Define the project mission in Setup before treating the score as release-grade.",
                blocksReleaseClaim: true
            ))
        }

        for item in inScope {
            let records = verificationByArea[item.area] ?? []
            guard let record = records.first else {
                gates.append(unverifiedGate(area: item.area, priority: item.priority, state: .unknown, sourceID: nil))
                continue
            }

            switch record.state {
            case .verified:
                gates.append(contentsOf: verifiedDebt(
                    record: record,
                    priority: item.priority,
                    evidence: evidence
                ))
            case .failed:
                gates.append(TruthDebtGate(
                    kind: .failedVerification,
                    severity: severity(for: item.priority, failed: true),
                    area: item.area,
                    title: "\(item.area) is failed",
                    detail: "A \(item.priority.rawValue.lowercased()) verification area is explicitly failed.",
                    recommendedAction: "Resolve \(item.area), attach evidence, then update the verification state.",
                    blocksReleaseClaim: blocksReleaseClaim(priority: item.priority),
                    sourceIdentifiers: [record.id.uuidString]
                ))
            case .inProgress, .unknown:
                gates.append(unverifiedGate(
                    area: item.area,
                    priority: item.priority,
                    state: record.state,
                    sourceID: record.id.uuidString
                ))
            }

            gates.append(contentsOf: dependencyDebt(
                record: record,
                priority: item.priority,
                stateByArea: stateByArea
            ))
        }

        for risk in risks where risk.isReleaseBlocking {
            gates.append(TruthDebtGate(
                kind: .releaseBlockingRisk,
                severity: .critical,
                area: risk.linkedVerificationAreas.joined(separator: ", "),
                title: risk.title,
                detail: "Open \(risk.impact.rawValue.lowercased()) risk is release-blocking.",
                recommendedAction: "Mitigate, accept with explicit release rationale, or close this risk before claiming release-ready.",
                blocksReleaseClaim: true,
                sourceIdentifiers: [risk.id.uuidString]
            ))
        }

        for assumption in assumptions where assumption.status == .active {
            let linkedItem = applicabilityByArea[assumption.linkedVerificationArea]
            let linkedRiskBlocks = assumption.linkedRiskIDs.contains { releaseBlockingRiskIDs.contains($0) }
            let blocks = linkedRiskBlocks || linkedItem.map { blocksReleaseClaim(priority: $0.priority) } == true
            gates.append(TruthDebtGate(
                kind: .activeAssumption,
                severity: blocks ? .high : .medium,
                area: assumption.linkedVerificationArea,
                title: assumption.assumption,
                detail: blocks
                    ? "Active assumption is tied to a release-relevant area or release-blocking risk."
                    : "Active assumption remains unresolved.",
                recommendedAction: "Convert the assumption into evidence, mark it verified/disproved, or supersede it.",
                blocksReleaseClaim: blocks,
                sourceIdentifiers: [assumption.id.uuidString]
            ))
        }

        let conflicts = WhyEngine().detectConflicts(
            evidence: evidence,
            projectID: snapshot.project.id,
            projectName: snapshot.project.name
        )
        for conflict in conflicts {
            let priority = applicabilityByArea[conflict.area]?.priority ?? .medium
            gates.append(TruthDebtGate(
                kind: .contradictoryEvidence,
                severity: blocksReleaseClaim(priority: priority) ? .high : .medium,
                area: conflict.area,
                title: "Contradictory evidence for \(conflict.area)",
                detail: conflict.explanation,
                recommendedAction: "Resolve the conflicting evidence before relying on \(conflict.area) for release truth.",
                blocksReleaseClaim: blocksReleaseClaim(priority: priority),
                sourceIdentifiers: (conflict.successEvidence + conflict.failureEvidence).map { $0.id.uuidString }
            ))
        }

        return TruthDebtReport(gates: sort(gates))
    }

    private func verifiedDebt(
        record: VerificationRecord,
        priority: VerificationPriority,
        evidence: [EvidenceRecord]
    ) -> [TruthDebtGate] {
        var gates: [TruthDebtGate] = []

        switch record.age {
        case .stale, .expired:
            gates.append(TruthDebtGate(
                kind: .staleVerification,
                severity: record.age == .expired ? .critical : severity(for: priority, failed: false),
                area: record.area,
                title: "\(record.area) verification is \(record.age.rawValue.lowercased())",
                detail: "Verified state has decayed and should not be treated as fresh release proof.",
                recommendedAction: "Re-run or refresh evidence for \(record.area).",
                blocksReleaseClaim: blocksReleaseClaim(priority: priority),
                sourceIdentifiers: [record.id.uuidString]
            ))
        case .fresh, .recent, .ageing, .never:
            break
        }

        if !hasStrongEvidence(for: record, in: evidence) {
            gates.append(TruthDebtGate(
                kind: .missingEvidence,
                severity: severity(for: priority, failed: false),
                area: record.area,
                title: "\(record.area) is verified without strong evidence",
                detail: "Verified state exists, but no observed, measured, or verified evidence record backs it.",
                recommendedAction: "Attach observed, measured, or verified evidence to \(record.area).",
                blocksReleaseClaim: blocksReleaseClaim(priority: priority),
                sourceIdentifiers: [record.id.uuidString]
            ))
        }

        return gates
    }

    private func dependencyDebt(
        record: VerificationRecord,
        priority: VerificationPriority,
        stateByArea: [String: VerificationState]
    ) -> [TruthDebtGate] {
        record.dependsOn.compactMap { dependency -> TruthDebtGate? in
            let dependencyState = stateByArea[dependency] ?? .unknown
            guard dependencyState != .verified else { return nil }
            return TruthDebtGate(
                kind: .blockedDependency,
                severity: dependencyState == .failed ? .critical : .high,
                area: record.area,
                title: "\(record.area) is blocked by \(dependency)",
                detail: "Dependency \(dependency) is \(dependencyState.rawValue).",
                recommendedAction: "Verify or resolve \(dependency) before relying on \(record.area).",
                blocksReleaseClaim: blocksReleaseClaim(priority: priority),
                sourceIdentifiers: [record.id.uuidString]
            )
        }
    }

    private func unverifiedGate(
        area: String,
        priority: VerificationPriority,
        state: VerificationState,
        sourceID: String?
    ) -> TruthDebtGate {
        TruthDebtGate(
            kind: .unverifiedArea,
            severity: severity(for: priority, failed: false),
            area: area,
            title: "\(area) is \(state.rawValue)",
            detail: "\(priority.rawValue) in-scope verification is not proven yet.",
            recommendedAction: "Verify \(area) and attach evidence before using it as release proof.",
            blocksReleaseClaim: blocksReleaseClaim(priority: priority),
            sourceIdentifiers: sourceID.map { [$0] } ?? []
        )
    }

    private func hasStrongEvidence(for record: VerificationRecord, in evidence: [EvidenceRecord]) -> Bool {
        evidence.contains { item in
            isStrong(item.classification)
                && (
                    normalized(item.area) == normalized(record.area)
                    || item.linkedVerificationIDs.contains(record.id)
                    || item.linkedID == record.id
                )
        }
    }

    private func isStrong(_ classification: EvidenceClassification) -> Bool {
        classification == .observed || classification == .measured || classification == .verified
    }

    private func blocksReleaseClaim(priority: VerificationPriority) -> Bool {
        priority == .critical || priority == .high
    }

    private func severity(for priority: VerificationPriority, failed: Bool) -> TruthDebtSeverity {
        switch priority {
        case .critical:
            return failed ? .critical : .high
        case .high:
            return .high
        case .medium:
            return .medium
        case .low:
            return .low
        }
    }

    private func sort(_ gates: [TruthDebtGate]) -> [TruthDebtGate] {
        gates.sorted {
            if $0.blocksReleaseClaim != $1.blocksReleaseClaim { return $0.blocksReleaseClaim && !$1.blocksReleaseClaim }
            if $0.severity != $1.severity { return $0.severity < $1.severity }
            if $0.area != $1.area { return $0.area < $1.area }
            return $0.title < $1.title
        }
    }

    private func normalized(_ area: String) -> String {
        area.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

public extension TruthDebtReport {
    func markdownExport(topGateLimit: Int = 5, actionLimit: Int = 5) -> String {
        TruthDebtMarkdownFormatter(
            report: self,
            topGateLimit: topGateLimit,
            actionLimit: actionLimit
        ).render()
    }
}

private struct TruthDebtMarkdownFormatter {
    let report: TruthDebtReport
    let topGateLimit: Int
    let actionLimit: Int

    func render() -> String {
        let gates = report.gates.sorted(by: gatePrecedes)
        let topGates = Array(gates.prefix(max(0, topGateLimit)))
        let actions = Array(uniqueActions(from: gates).prefix(max(0, actionLimit)))
        var lines = [
            "# Truth Debt Export",
            "",
            "- Status: \(safeText(report.status.rawValue))",
            "- Headline: \(safeText(report.headline))",
            "- Blockers: \(report.blockers.count)",
            "- Caveats: \(report.caveats.count)",
            "- Total gates: \(report.gates.count)",
            "",
            "## Top Gates"
        ]

        if topGates.isEmpty {
            lines.append("- None")
        } else {
            for (index, gate) in topGates.enumerated() {
                appendGate(gate, index: index + 1, to: &lines)
            }
        }

        lines.append("")
        lines.append("## Actions")

        if actions.isEmpty {
            lines.append("- None")
        } else {
            lines.append(contentsOf: actions.enumerated().map { index, action in
                "\(index + 1). \(action)"
            })
        }

        return lines.joined(separator: "\n")
    }

    private func appendGate(_ gate: TruthDebtGate, index: Int, to lines: inout [String]) {
        let area = safeText(gate.area, fallback: "")
        let areaSuffix = area.isEmpty ? "" : " - \(area)"
        lines.append("\(index). **\(safeText(gate.severity.rawValue))** \(safeText(gate.title))\(areaSuffix)")
        lines.append("   - Kind: \(safeText(gate.kind.rawValue))")
        lines.append("   - Blocks release claim: \(gate.blocksReleaseClaim ? "Yes" : "No")")
        lines.append("   - Detail: \(safeText(gate.detail))")
        lines.append("   - Action: \(safeText(gate.recommendedAction))")
        lines.append("   - Source IDs: \(sourceLine(gate.sourceIdentifiers))")
    }

    private func uniqueActions(from gates: [TruthDebtGate]) -> [String] {
        var seen = Set<String>()
        var actions: [String] = []

        for gate in gates {
            let action = safeText(gate.recommendedAction, fallback: "")
            guard !action.isEmpty, seen.insert(action).inserted else { continue }
            actions.append(action)
        }

        return actions
    }

    private func sourceLine(_ identifiers: [String]) -> String {
        let sourceIDs = Set(identifiers.map { safeText($0, fallback: "") }.filter { !$0.isEmpty })
            .sorted()
        return sourceIDs.isEmpty ? "None" : sourceIDs.joined(separator: ", ")
    }

    private func safeText(_ text: String, fallback: String = "Unknown") -> String {
        let redacted = redact(text)
        let collapsed = redacted
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return collapsed.isEmpty ? fallback : collapsed
    }

    private func redact(_ text: String) -> String {
        ReportEngine().redact(text).replacingOccurrences(
            of: #"(?i)\b(token|api[_-]?key|password|secret)\s*[:=]\s*\[REDACTED_SECRET\]"#,
            with: "[REDACTED_SECRET]",
            options: .regularExpression
        )
    }

    private func gatePrecedes(_ lhs: TruthDebtGate, _ rhs: TruthDebtGate) -> Bool {
        if lhs.blocksReleaseClaim != rhs.blocksReleaseClaim {
            return lhs.blocksReleaseClaim && !rhs.blocksReleaseClaim
        }
        if lhs.severity != rhs.severity { return lhs.severity < rhs.severity }

        let lhsArea = sortKey(lhs.area)
        let rhsArea = sortKey(rhs.area)
        if lhsArea != rhsArea { return lhsArea < rhsArea }
        if lhs.kind.rawValue != rhs.kind.rawValue { return lhs.kind.rawValue < rhs.kind.rawValue }
        if lhs.title != rhs.title { return lhs.title < rhs.title }
        return lhs.id < rhs.id
    }

    private func sortKey(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
