import Foundation

/// Phase 7.5: derives explainable Reality breakdown, Confidence (separate from
/// Reality), and Register Health from the same data the rest of the system uses.
/// No new persistence — pure aggregation.
public struct TruthEngine: Sendable {
    public init() {}

    // MARK: - Reality breakdown

    /// Build an itemised breakdown for the Reality score. The deltas don't have
    /// to add to exactly the final score — they're attribution, not arithmetic
    /// proof — but they're scaled so the user can see roughly what dominates.
    public func breakdown(
        snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        assumptions: [AssumptionRecord]
    ) -> RealityBreakdown {
        var items: [RealityContribution] = []
        let baseline = 30
        let counts = snapshot.verificationSummary

        // Verified records (weighted by priority).
        let priorityByArea = Dictionary(uniqueKeysWithValues: snapshot.applicability.map { ($0.area, $0.priority) })
        let verifiedDelta = snapshot.verification.reduce(0) { acc, record in
            guard record.state == .verified else { return acc }
            let weight = Int((priorityByArea[record.area]?.weight ?? 1.0) * 4)
            let aged = Int(Double(weight) * record.age.trust)
            return acc + aged
        }
        if verifiedDelta > 0 {
            items.append(.init(label: "\(counts.verified) verified record(s) (priority-weighted, age-decayed)", delta: verifiedDelta))
        }

        // Evidence backing.
        let strongEvidence = evidence.filter { [EvidenceClassification.observed, .measured, .verified].contains($0.classification) }
        if !strongEvidence.isEmpty {
            items.append(.init(label: "\(strongEvidence.count) evidence record(s) on file", delta: min(18, strongEvidence.count * 2)))
        }

        // Mission coverage.
        if snapshot.userMission != nil {
            items.append(.init(label: "Mission defined", delta: 8))
        }

        // Failures.
        if counts.failed > 0 {
            items.append(.init(label: "\(counts.failed) failed verification(s)", delta: -min(35, counts.failed * 10)))
        }

        // Open risks.
        let openCritical = risks.filter { $0.status == .open && $0.impact == .critical }.count
        let openHigh = risks.filter { $0.status == .open && $0.impact == .high }.count
        if openCritical > 0 {
            items.append(.init(label: "\(openCritical) open critical risk(s)", delta: -min(20, openCritical * 6)))
        }
        if openHigh > 0 {
            items.append(.init(label: "\(openHigh) open high-impact risk(s)", delta: -min(12, openHigh * 3)))
        }

        // Active assumptions.
        let active = assumptions.filter { $0.status == .active }.count
        if active > 0 {
            items.append(.init(label: "\(active) active assumption(s)", delta: -min(10, active * 2)))
        }

        // Stale verifications.
        let stale = snapshot.verification.filter {
            $0.state == .verified && ($0.age == .stale || $0.age == .expired)
        }.count
        if stale > 0 {
            items.append(.init(label: "\(stale) stale verified record(s)", delta: -min(10, stale * 2)))
        }

        // Unknown in-scope coverage gap.
        let inScope = snapshot.applicability.filter { $0.status.inScope }.count
        let unknownInScope = snapshot.verification.filter { $0.state == .unknown }.count
        if inScope > 0, unknownInScope > 0 {
            items.append(.init(label: "\(unknownInScope) in-scope area(s) unverified", delta: -min(10, unknownInScope * 2)))
        }

        return RealityBreakdown(baseline: baseline, contributions: items, finalScore: snapshot.reality.score)
    }

    /// Returns structured source rows for the material contribution categories
    /// already exposed by `breakdown`. This is provenance only; it does not
    /// compute or alter score values.
    public func contributionProvenance(
        snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        assumptions: [AssumptionRecord]
    ) -> [TruthContributionProvenanceRow] {
        var rows: [TruthContributionProvenanceRow] = []
        var applicabilityByArea: [String: ApplicabilityItem] = [:]
        for item in snapshot.applicability {
            applicabilityByArea[item.area] = item
        }
        let releaseBlockingRiskIDs = Set(risks.filter(\.isReleaseBlocking).map(\.id))

        func priority(for area: String) -> VerificationPriority {
            applicabilityByArea[area]?.priority ?? .medium
        }

        func releaseRelevant(area: String) -> Bool {
            guard let item = applicabilityByArea[area], item.status.inScope else { return false }
            return item.priority == .critical || item.priority == .high
        }

        func releaseRelevant(riskIDs: [UUID], area: String) -> Bool {
            releaseRelevant(area: area) || riskIDs.contains { releaseBlockingRiskIDs.contains($0) }
        }

        for record in snapshot.verification where record.state == .verified {
            let priority = priority(for: record.area)
            let weight = Int(priority.weight * 4)
            let delta = Int(Double(weight) * record.age.trust)
            guard delta > 0 else { continue }
            rows.append(
                TruthContributionProvenanceRow(
                    sourceKind: .verification,
                    sourceIdentifier: record.id.uuidString,
                    sourceArea: record.area,
                    status: record.state.rawValue,
                    freshness: record.age,
                    direction: .positive,
                    reason: "\(priority.rawValue) priority verified record contributes positive, age-decayed Reality signal.",
                    releaseRelevant: releaseRelevant(area: record.area)
                )
            )
        }

        let strongClassifications: Set<EvidenceClassification> = [.observed, .measured, .verified]
        for record in evidence where strongClassifications.contains(record.classification) {
            rows.append(
                TruthContributionProvenanceRow(
                    sourceKind: .evidence,
                    sourceIdentifier: record.id.uuidString,
                    sourceArea: record.area,
                    status: record.classification.rawValue,
                    direction: .positive,
                    reason: "\(record.classification.rawValue) evidence counts as strong supporting evidence.",
                    releaseRelevant: releaseRelevant(riskIDs: record.linkedRiskIDs, area: record.area)
                )
            )
        }

        if let mission = snapshot.userMission {
            rows.append(
                TruthContributionProvenanceRow(
                    sourceKind: .mission,
                    sourceIdentifier: "userMission",
                    status: mission.category.rawValue,
                    direction: .positive,
                    reason: "User-defined mission contributes positive Truth Centre context.",
                    releaseRelevant: false
                )
            )
        }

        for record in snapshot.verification where record.state == .failed {
            let priority = priority(for: record.area)
            rows.append(
                TruthContributionProvenanceRow(
                    sourceKind: .verification,
                    sourceIdentifier: record.id.uuidString,
                    sourceArea: record.area,
                    status: record.state.rawValue,
                    freshness: record.age,
                    direction: .negative,
                    reason: "\(priority.rawValue) priority failed verification reduces Reality score.",
                    releaseRelevant: releaseRelevant(area: record.area)
                )
            )
        }

        for risk in risks where risk.status == .open && (risk.impact == .critical || risk.impact == .high) {
            let area = risk.linkedVerificationAreas.joined(separator: ", ")
            rows.append(
                TruthContributionProvenanceRow(
                    sourceKind: .risk,
                    sourceIdentifier: risk.id.uuidString,
                    sourceArea: area,
                    status: risk.status.rawValue,
                    direction: .negative,
                    reason: "Open \(risk.impact.rawValue.lowercased()) risk reduces Reality score.",
                    releaseRelevant: risk.isReleaseBlocking
                )
            )
        }

        for assumption in assumptions where assumption.status == .active {
            rows.append(
                TruthContributionProvenanceRow(
                    sourceKind: .assumption,
                    sourceIdentifier: assumption.id.uuidString,
                    sourceArea: assumption.linkedVerificationArea,
                    status: assumption.status.rawValue,
                    direction: .negative,
                    reason: "Active assumption reduces trust until verified or superseded.",
                    releaseRelevant: releaseRelevant(
                        riskIDs: assumption.linkedRiskIDs,
                        area: assumption.linkedVerificationArea
                    )
                )
            )
        }

        for record in snapshot.verification
        where record.state == .verified && (record.age == .stale || record.age == .expired) {
            rows.append(
                TruthContributionProvenanceRow(
                    sourceKind: .verification,
                    sourceIdentifier: record.id.uuidString,
                    sourceArea: record.area,
                    status: record.state.rawValue,
                    freshness: record.age,
                    direction: .negative,
                    reason: "Verified record is \(record.age.rawValue.lowercased()), so freshness reduces trust.",
                    releaseRelevant: releaseRelevant(area: record.area)
                )
            )
        }

        let inScope = snapshot.applicability.filter { $0.status.inScope }.count
        if inScope > 0 {
            for record in snapshot.verification where record.state == .unknown {
                rows.append(
                    TruthContributionProvenanceRow(
                        sourceKind: .verificationGap,
                        sourceIdentifier: record.id.uuidString,
                        sourceArea: record.area,
                        status: record.state.rawValue,
                        freshness: record.age,
                        direction: .negative,
                        reason: "In-scope area has no verified record yet.",
                        releaseRelevant: releaseRelevant(area: record.area)
                    )
                )
            }
        }
        return rows
    }

    // MARK: - Confidence

    /// Confidence answers "how well do we know this?" — distinct from Reality's
    /// "how well is this going?".
    public func confidence(
        snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        assumptions: [AssumptionRecord]
    ) -> ConfidenceAssessment {
        var score = 30
        var items: [RealityContribution] = []

        // Strong evidence is the dominant factor.
        let strong = evidence.filter { [EvidenceClassification.observed, .measured, .verified].contains($0.classification) }
        let weak = evidence.filter { $0.classification == .assumed || $0.classification == .unknown }
        if !strong.isEmpty {
            let d = min(50, strong.count * 5)
            score += d
            items.append(.init(label: "\(strong.count) strong evidence record(s)", delta: d))
        }
        if !weak.isEmpty {
            let d = -min(15, weak.count * 3)
            score += d
            items.append(.init(label: "\(weak.count) weak evidence record(s) (Assumed/Unknown)", delta: d))
        }

        // Coverage: evidence per in-scope area.
        let inScopeAreas = Set(snapshot.applicability.filter { $0.status.inScope }.map(\.area))
        let coveredAreas = Set(strong.map(\.area)).intersection(inScopeAreas).count
        if !inScopeAreas.isEmpty {
            let pct = Int(Double(coveredAreas) / Double(inScopeAreas.count) * 25)
            score += pct
            items.append(.init(label: "Evidence covers \(coveredAreas)/\(inScopeAreas.count) in-scope area(s)", delta: pct))
        }

        // Recency: fresh verified records lift confidence.
        let freshVerified = snapshot.verification.filter { $0.state == .verified && $0.age == .fresh }.count
        if freshVerified > 0 {
            let d = min(10, freshVerified * 2)
            score += d
            items.append(.init(label: "\(freshVerified) fresh verified record(s)", delta: d))
        }

        // Active assumptions drag confidence down sharply.
        let active = assumptions.filter { $0.status == .active }.count
        if active > 0 {
            let d = -min(25, active * 4)
            score += d
            items.append(.init(label: "\(active) active assumption(s)", delta: d))
        }

        score = max(5, min(100, score))
        let label: String
        let summary: String
        switch score {
        case 80...:
            label = "High"
            summary = "Project state is well backed by evidence."
        case 55..<80:
            label = "Moderate"
            summary = "Some evidence on file; partial coverage."
        case 30..<55:
            label = "Low"
            summary = "Sparse evidence; trust this state cautiously."
        default:
            label = "Very Low"
            summary = "Almost no evidence — most claims are assumed."
        }
        return ConfidenceAssessment(score: score, label: label, summary: summary, contributions: items)
    }

    // MARK: - Register health

    /// Returns coverage ratios for each register, 0.0–1.0.
    /// Coverage = registers populated relative to a sensible per-project target
    /// (the in-scope verification count, since that's the project's surface area).
    public func registerHealth(
        snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        decisions: [DecisionRecord],
        risks: [RiskRecord],
        architecture: [ArchitectureItem],
        assumptions: [AssumptionRecord]
    ) -> RegisterHealth {
        let inScope = max(1, snapshot.applicability.filter { $0.status.inScope }.count)
        func ratio(_ count: Int, target: Int) -> Double {
            min(1.0, Double(count) / Double(max(1, target)))
        }
        // Evidence target: at least 1 per in-scope verification.
        // Decisions target: ~3 per project.
        // Risks target: ~3 per project.
        // Architecture target: at least 1 per in-scope verification (a subsystem each).
        // Assumptions target: ~2 per project.
        return RegisterHealth(
            evidenceCoverage: ratio(evidence.count, target: inScope),
            riskCoverage: ratio(risks.count, target: 3),
            decisionCoverage: ratio(decisions.count, target: 3),
            architectureCoverage: ratio(architecture.count, target: inScope),
            assumptionCoverage: ratio(assumptions.count, target: 2)
        )
    }

    // MARK: - Related records ("Show Related")

    /// Resolve everything connected to one record. Links are stored one-way on
    /// whichever record the user linked from; this resolver walks both
    /// directions (and the legacy area-name references) so a single link shows
    /// up on every screen that touches either record.
    public func related(
        to ref: TruthRecordRef,
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        decisions: [DecisionRecord],
        architecture: [ArchitectureItem],
        assumptions: [AssumptionRecord],
        verification: [VerificationRecord]
    ) -> RelatedRecords {
        var out = RelatedRecords()

        switch ref {
        case .evidence(let id):
            guard let me = evidence.first(where: { $0.id == id }) else { return out }
            out.risks = risks.filter { me.linkedRiskIDs.contains($0.id) || $0.linkedEvidenceIDs.contains(id) }
            out.decisions = decisions.filter { me.linkedDecisionIDs.contains($0.id) || $0.linkedEvidenceIDs.contains(id) }
            out.architecture = architecture.filter { me.linkedArchitectureIDs.contains($0.id) || $0.linkedEvidenceIDs.contains(id) }
            out.assumptions = assumptions.filter { me.linkedAssumptionIDs.contains($0.id) || $0.linkedEvidenceIDs.contains(id) }
            out.verification = verification.filter {
                me.linkedVerificationIDs.contains($0.id) || me.linkedID == $0.id || $0.area == me.area
            }

        case .risk(let id):
            guard let me = risks.first(where: { $0.id == id }) else { return out }
            out.evidence = evidence.filter { me.linkedEvidenceIDs.contains($0.id) || $0.linkedRiskIDs.contains(id) }
            out.decisions = decisions.filter { me.linkedDecisionIDs.contains($0.id) || $0.linkedRiskIDs.contains(id) }
            out.architecture = architecture.filter { me.linkedArchitectureIDs.contains($0.id) || $0.linkedRiskIDs.contains(id) }
            out.assumptions = assumptions.filter { $0.linkedRiskIDs.contains(id) }
            out.verification = verification.filter {
                me.linkedVerificationIDs.contains($0.id) || me.linkedVerificationAreas.contains($0.area)
            }

        case .decision(let id):
            guard let me = decisions.first(where: { $0.id == id }) else { return out }
            out.evidence = evidence.filter { me.linkedEvidenceIDs.contains($0.id) || $0.linkedDecisionIDs.contains(id) }
            out.risks = risks.filter { me.linkedRiskIDs.contains($0.id) || $0.linkedDecisionIDs.contains(id) }
            out.architecture = architecture.filter { me.linkedArchitectureIDs.contains($0.id) || $0.linkedDecisionIDs.contains(id) }
            out.verification = verification.filter { me.linkedVerificationIDs.contains($0.id) }

        case .architecture(let id):
            guard let me = architecture.first(where: { $0.id == id }) else { return out }
            out.evidence = evidence.filter { me.linkedEvidenceIDs.contains($0.id) || $0.linkedArchitectureIDs.contains(id) }
            out.risks = risks.filter { me.linkedRiskIDs.contains($0.id) || $0.linkedArchitectureIDs.contains(id) }
            out.decisions = decisions.filter { me.linkedDecisionIDs.contains($0.id) || $0.linkedArchitectureIDs.contains(id) }
            out.architecture = architecture.filter { $0.id != id && me.linkedArchitectureIDs.contains($0.id) }
            out.verification = verification.filter { me.linkedVerificationAreas.contains($0.area) }

        case .assumption(let id):
            guard let me = assumptions.first(where: { $0.id == id }) else { return out }
            out.evidence = evidence.filter { me.linkedEvidenceIDs.contains($0.id) || $0.linkedAssumptionIDs.contains(id) }
            out.risks = risks.filter { me.linkedRiskIDs.contains($0.id) }
            out.verification = verification.filter {
                me.linkedVerificationIDs.contains($0.id) || (!me.linkedVerificationArea.isEmpty && $0.area == me.linkedVerificationArea)
            }

        case .verification(let id):
            guard let me = verification.first(where: { $0.id == id }) else { return out }
            out.evidence = evidence.filter {
                $0.linkedVerificationIDs.contains(id) || $0.linkedID == id || $0.area == me.area
            }
            out.risks = risks.filter {
                $0.linkedVerificationIDs.contains(id) || $0.linkedVerificationAreas.contains(me.area)
            }
            out.decisions = decisions.filter { $0.linkedVerificationIDs.contains(id) }
            out.architecture = architecture.filter { $0.linkedVerificationAreas.contains(me.area) }
            out.assumptions = assumptions.filter {
                $0.linkedVerificationIDs.contains(id) || (!$0.linkedVerificationArea.isEmpty && $0.linkedVerificationArea == me.area)
            }
        }
        return out
    }

    // MARK: - Workspace Truth summary

    public func workspaceTruth(records: [PersistedProjectRecord], snapshots: [RepoSnapshot]) -> WorkspaceTruthSummary {
        let verifiedRecords = records.reduce(0) { $0 + ($1.verification?.filter { $0.state == .verified }.count ?? 0) }
        let evidenceRecords = records.reduce(0) { $0 + ($1.evidence?.count ?? 0) }
        let openRisks = records.reduce(0) { $0 + ($1.risks?.filter { $0.status == .open || $0.status == .monitoring }.count ?? 0) }
        let activeAssumptions = records.reduce(0) { $0 + ($1.assumptions?.filter { $0.status == .active }.count ?? 0) }
        let criticalFailures = snapshots.reduce(0) { acc, snap in
            let prio = Dictionary(uniqueKeysWithValues: snap.applicability.map { ($0.area, $0.priority) })
            return acc + snap.verification.filter {
                $0.state == .failed && (prio[$0.area] == .critical || prio[$0.area] == .high)
            }.count
        }
        let decisions = records.reduce(0) { $0 + ($1.decisions?.count ?? 0) }
        let architecture = records.reduce(0) { $0 + ($1.architecture?.count ?? 0) }
        let stale = records.reduce(0) { $0 + ($1.verification?.filter {
            $0.state == .verified && ($0.age == .stale || $0.age == .expired)
        }.count ?? 0) }
        let criticalOpenRisks = records.reduce(0) { $0 + ($1.risks?.filter {
            $0.status == .open && $0.impact == .critical
        }.count ?? 0) }
        let journalEntries = records.reduce(0) { $0 + ($1.journal?.count ?? 0) }
        return WorkspaceTruthSummary(
            totalProjects: records.count,
            verifiedRecords: verifiedRecords,
            evidenceRecords: evidenceRecords,
            openRisks: openRisks,
            activeAssumptions: activeAssumptions,
            criticalFailures: criticalFailures,
            decisionRecords: decisions,
            architectureItems: architecture,
            staleVerifications: stale,
            criticalOpenRisks: criticalOpenRisks,
            journalEntries: journalEntries
        )
    }
}
