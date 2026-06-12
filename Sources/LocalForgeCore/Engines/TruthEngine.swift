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
        let inScopeAreaKeys = Set(snapshot.applicability.filter { $0.status.inScope }.map { normalizedArea($0.area) })
        let inScopeVerificationAreaByID = snapshot.verification.reduce(into: [UUID: String]()) { areas, record in
            let areaKey = normalizedArea(record.area)
            guard inScopeAreaKeys.contains(areaKey) else { return }
            areas[record.id] = areaKey
        }
        let evidenceForConfidence = evidence.filter {
            evidenceCountsForConfidence(
                $0,
                inScopeAreaKeys: inScopeAreaKeys,
                inScopeVerificationAreaByID: inScopeVerificationAreaByID
            )
        }

        let strongCandidates = uniqueConfidenceEvidence(
            evidenceForConfidence.filter { isStrongConfidenceEvidence($0.classification) }
        )
        let unsupportedFailures = unsupportedFailureEvidence(
            strongCandidates,
            verification: snapshot.verification,
            inScopeAreaKeys: inScopeAreaKeys,
            inScopeVerificationAreaByID: inScopeVerificationAreaByID
        )

        // Strong evidence is the dominant factor, but duplicate rows and failed
        // signals must not make confidence look better than the underlying proof.
        let strong = strongCandidates.filter { !unsupportedFailures.contains($0.id) }
        let weak = uniqueConfidenceEvidence(
            evidenceForConfidence.filter { $0.classification == .assumed || $0.classification == .unknown }
        )
        if !strong.isEmpty {
            let strongSignalCount = cappedStrongConfidenceSignalCount(
                strong,
                inScopeAreaKeys: inScopeAreaKeys,
                inScopeVerificationAreaByID: inScopeVerificationAreaByID
            )
            let d = min(50, strongSignalCount * 5)
            score += d
            let scope = inScopeAreaKeys.isEmpty ? "" : "in-scope "
            items.append(.init(label: "\(strongSignalCount) unique \(scope)strong evidence signal(s)", delta: d))
        }
        if !weak.isEmpty {
            let d = -min(15, weak.count * 3)
            score += d
            let scope = inScopeAreaKeys.isEmpty ? "" : "in-scope "
            items.append(.init(label: "\(weak.count) \(scope)weak evidence record(s) (Assumed/Unknown)", delta: d))
        }
        if !unsupportedFailures.isEmpty {
            let d = -min(25, unsupportedFailures.count * 6)
            score += d
            items.append(.init(label: "\(unsupportedFailures.count) failed evidence signal(s)", delta: d))
        }

        // Coverage: evidence per in-scope area.
        let coveredAreaKeys = Set(strong.flatMap {
            coveredConfidenceAreaKeys(
                for: $0,
                inScopeAreaKeys: inScopeAreaKeys,
                inScopeVerificationAreaByID: inScopeVerificationAreaByID
            )
        })
        if !inScopeAreaKeys.isEmpty {
            let pct = Int(Double(coveredAreaKeys.count) / Double(inScopeAreaKeys.count) * 25)
            score += pct
            items.append(.init(label: "Evidence covers \(coveredAreaKeys.count)/\(inScopeAreaKeys.count) in-scope area(s)", delta: pct))
        }

        let conflictAreaCount = confidenceConflictAreaCount(
            evidence: evidenceForConfidence,
            verification: snapshot.verification,
            inScopeAreaKeys: inScopeAreaKeys,
            inScopeVerificationAreaByID: inScopeVerificationAreaByID
        )
        if conflictAreaCount > 0 {
            let d = -min(25, conflictAreaCount * 10)
            score += d
            items.append(.init(label: "\(conflictAreaCount) contradictory confidence area(s)", delta: d))
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

    private func uniqueConfidenceEvidence(_ evidence: [EvidenceRecord]) -> [EvidenceRecord] {
        var seen = Set<String>()
        return evidence.filter { record in
            seen.insert(confidenceEvidenceFingerprint(record)).inserted
        }
    }

    private func confidenceEvidenceFingerprint(_ evidence: EvidenceRecord) -> String {
        [
            evidence.classification.rawValue,
            evidence.kind.rawValue,
            normalizedArea(evidence.area),
            normalizedText(evidence.summary),
            normalizedText(evidence.body),
            normalizedText(evidence.attachmentPath),
            evidence.linkedID?.uuidString ?? "",
            evidence.linkedVerificationIDs.map(\.uuidString).sorted().joined(separator: ","),
        ].joined(separator: "|")
    }

    private func cappedStrongConfidenceSignalCount(
        _ evidence: [EvidenceRecord],
        inScopeAreaKeys: Set<String>,
        inScopeVerificationAreaByID: [UUID: String]
    ) -> Int {
        var countsByArea: [String: Int] = [:]
        for record in evidence {
            let keys = confidenceAreaKeys(
                for: record,
                inScopeAreaKeys: inScopeAreaKeys,
                inScopeVerificationAreaByID: inScopeVerificationAreaByID
            )
            for key in keys {
                countsByArea[key, default: 0] += 1
            }
        }
        return countsByArea.values.reduce(0) { $0 + min($1, 5) }
    }

    private func confidenceConflictAreaCount(
        evidence: [EvidenceRecord],
        verification: [VerificationRecord],
        inScopeAreaKeys: Set<String>,
        inScopeVerificationAreaByID: [UUID: String]
    ) -> Int {
        let statesByArea = Dictionary(grouping: verification, by: { normalizedArea($0.area) })
            .mapValues { Set($0.map(\.state)) }
        var signalsByArea: [String: (success: Bool, failure: Bool)] = [:]

        for record in uniqueConfidenceEvidence(evidence).filter({ isStrongConfidenceEvidence($0.classification) }) {
            let keys = confidenceAreaKeys(
                for: record,
                inScopeAreaKeys: inScopeAreaKeys,
                inScopeVerificationAreaByID: inScopeVerificationAreaByID
            )
            let success = isConfidenceSuccessEvidence(record)
            let failure = isConfidenceFailureEvidence(record)
            for key in keys {
                signalsByArea[key, default: (false, false)].success = signalsByArea[key, default: (false, false)].success || success
                signalsByArea[key, default: (false, false)].failure = signalsByArea[key, default: (false, false)].failure || failure
            }
        }

        var conflictAreas = Set<String>()
        for (areaKey, signals) in signalsByArea {
            let states = statesByArea[areaKey, default: []]
            if signals.success && signals.failure {
                conflictAreas.insert(areaKey)
            }
            if signals.failure && states.contains(.verified) {
                conflictAreas.insert(areaKey)
            }
            if signals.success && states.contains(.failed) {
                conflictAreas.insert(areaKey)
            }
            if states.contains(.verified) && states.contains(.failed) {
                conflictAreas.insert(areaKey)
            }
        }

        return conflictAreas.count
    }

    private func unsupportedFailureEvidence(
        _ evidence: [EvidenceRecord],
        verification: [VerificationRecord],
        inScopeAreaKeys: Set<String>,
        inScopeVerificationAreaByID: [UUID: String]
    ) -> Set<UUID> {
        let statesByArea = Dictionary(grouping: verification, by: { normalizedArea($0.area) })
            .mapValues { Set($0.map(\.state)) }

        return Set(evidence.compactMap { record in
            guard isConfidenceFailureEvidence(record) else { return nil }
            let keys = confidenceAreaKeys(
                for: record,
                inScopeAreaKeys: inScopeAreaKeys,
                inScopeVerificationAreaByID: inScopeVerificationAreaByID
            )
            guard !keys.contains(where: { statesByArea[$0, default: []].contains(.failed) }) else {
                return nil
            }
            return record.id
        })
    }

    private func confidenceAreaKeys(
        for evidence: EvidenceRecord,
        inScopeAreaKeys: Set<String>,
        inScopeVerificationAreaByID: [UUID: String]
    ) -> Set<String> {
        let covered = Set(coveredConfidenceAreaKeys(
            for: evidence,
            inScopeAreaKeys: inScopeAreaKeys,
            inScopeVerificationAreaByID: inScopeVerificationAreaByID
        ))
        if !covered.isEmpty { return covered }
        let areaKey = normalizedArea(evidence.area)
        return areaKey.isEmpty ? [] : [areaKey]
    }

    private func evidenceCountsForConfidence(
        _ evidence: EvidenceRecord,
        inScopeAreaKeys: Set<String>,
        inScopeVerificationAreaByID: [UUID: String]
    ) -> Bool {
        if inScopeAreaKeys.isEmpty { return true }
        if inScopeAreaKeys.contains(normalizedArea(evidence.area)) { return true }
        if let linkedID = evidence.linkedID, inScopeVerificationAreaByID[linkedID] != nil { return true }
        return evidence.linkedVerificationIDs.contains { inScopeVerificationAreaByID[$0] != nil }
    }

    private func coveredConfidenceAreaKeys(
        for evidence: EvidenceRecord,
        inScopeAreaKeys: Set<String>,
        inScopeVerificationAreaByID: [UUID: String]
    ) -> [String] {
        var covered = Set<String>()
        let areaKey = normalizedArea(evidence.area)
        if inScopeAreaKeys.contains(areaKey) {
            covered.insert(areaKey)
        }
        if let linkedID = evidence.linkedID,
           let linkedArea = inScopeVerificationAreaByID[linkedID] {
            covered.insert(linkedArea)
        }
        for id in evidence.linkedVerificationIDs {
            if let linkedArea = inScopeVerificationAreaByID[id] {
                covered.insert(linkedArea)
            }
        }
        return Array(covered)
    }

    private func normalizedArea(_ area: String) -> String {
        area.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .lowercased()
    }

    private func isStrongConfidenceEvidence(_ classification: EvidenceClassification) -> Bool {
        classification == .observed || classification == .measured || classification == .verified
    }

    private func isConfidenceSuccessEvidence(_ evidence: EvidenceRecord) -> Bool {
        guard isStrongConfidenceEvidence(evidence.classification), !isConfidenceFailureEvidence(evidence) else { return false }
        if evidence.classification == .verified { return true }
        return containsConfidenceSuccessSignal(in: "\(evidence.summary) \(evidence.body)")
    }

    private func isConfidenceFailureEvidence(_ evidence: EvidenceRecord) -> Bool {
        guard isStrongConfidenceEvidence(evidence.classification) else { return false }
        return containsConfidenceFailureSignal(in: "\(evidence.summary) \(evidence.body)")
    }

    private func containsConfidenceSuccessSignal(in text: String) -> Bool {
        text.range(
            of: #"(?i)\b(pass(?:ed|es|ing)?|success(?:ful|fully)?|succeeded|works|working|green|clean|accepted|valid(?:ated)?|verified)\b"#,
            options: .regularExpression
        ) != nil
    }

    private func containsConfidenceFailureSignal(in text: String) -> Bool {
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
