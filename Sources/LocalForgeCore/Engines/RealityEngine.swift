import Foundation

/// The highest-level engine. It combines everything LocalForge observed into a
/// single honest answer: what is known, what is merely assumed, what is unverified,
/// the current risk, and the next action. Unknown is never reported as healthy.
public struct RealityEngine: Sendable {
    public init() {}

    public func assess(
        identity: ProjectIdentity,
        mission: MissionProfile,
        applicability: [ApplicabilityItem],
        git: GitStatus,
        summary: RepoSummary,
        findings: [Finding],
        evidence: [Evidence],
        verification: [VerificationRecord] = [],
        knownIssues: [String] = [],
        // Phase 7: per-area evidence records back up verification claims.
        evidenceRecords: [EvidenceRecord] = [],
        riskRecords: [RiskRecord] = [],
        assumptionRecords: [AssumptionRecord] = []
    ) -> RealityAssessment {
        var knownFacts: [String] = []
        var verified: [String] = []
        var unverified: [String] = []
        var assumptions: [String] = []
        var unknowns: [String] = []
        var topRisks: [String] = []

        // Known facts: directly observed or measured evidence.
        for item in evidence where [.observed, .measured].contains(item.classification) {
            knownFacts.append(item.title)
        }
        // Phase 7: user-recorded evidence records are first-class known facts.
        for record in evidenceRecords where [.observed, .measured, .verified].contains(record.classification) {
            knownFacts.append("\(record.area): \(record.summary)")
        }
        for item in evidence where item.classification == .verified {
            verified.append(item.title)
        }
        for finding in findings where finding.evidenceClassification == .verified {
            verified.append(finding.title)
        }

        // Assumptions: inferred/assumed identity and mission.
        if [.inferred, .assumed].contains(identity.confidence) {
            assumptions.append("Project is likely a \(identity.kind.rawValue) (\(identity.confidence.rawValue.lowercased())).")
        }
        if [.inferred, .assumed].contains(mission.confidence), mission.category != .unknown {
            assumptions.append("Mission assumed to be: \(mission.statedMission).")
        }

        // --- Verification-driven truth (the heart of the command centre) ---
        let summaryCounts = VerificationSummary(records: verification)
        for record in verification {
            switch record.state {
            case .verified:
                verified.append(record.note.isEmpty ? "\(record.area) verified." : "\(record.area) verified — \(record.note)")
            case .failed:
                topRisks.append(record.note.isEmpty ? "\(record.area) is failing (user-reported)." : "\(record.area) failing — \(record.note)")
            case .inProgress:
                unverified.append("\(record.area) is in progress.")
            case .unknown:
                unverified.append("\(record.area) has not been verified.")
            }
        }
        // When the user has not started verifying, fall back to in-scope areas.
        if verification.isEmpty {
            for item in applicability where item.status.inScope {
                unverified.append("\(item.area) has no verification evidence yet.")
            }
        }

        // Known issues the user recorded.
        for issue in knownIssues {
            topRisks.append("Known issue: \(issue)")
        }

        // Phase 7: register-driven content.
        let openRisks = riskRecords.filter { $0.status == .open || $0.status == .monitoring }
        for risk in openRisks.sorted(by: { $0.severityScore > $1.severityScore }).prefix(4) {
            let label = risk.isReleaseBlocking ? "Release risk" : "Risk"
            topRisks.append("\(label) (\(risk.impact.rawValue)/\(risk.likelihood.rawValue)): \(risk.title)")
        }

        let activeAssumptions = assumptionRecords.filter { $0.status == .active || $0.status == .needsReview }
        for a in activeAssumptions.prefix(4) {
            assumptions.append("Assumption: \(a.assumption)")
        }
        if activeAssumptions.count >= 3 {
            unknowns.append("Reality limited by \(activeAssumptions.count) active assumption(s) — verify or supersede them.")
        }

        // Unknowns.
        unknowns.append("Build state is unknown — LocalForge does not build the project in this phase.")
        if !git.isRepository { unknowns.append("Version-control state is unknown (no Git repository).") }

        // Risks: failures and findings first, then required-but-unverified areas.
        for finding in findings.sorted(by: { $0.severity > $1.severity })
        where finding.severity >= .warning && [.observed, .measured, .verified].contains(finding.evidenceClassification) {
            topRisks.append("\(finding.title): \(finding.detail)")
        }
        let verifiedAreas = Set(verification.filter { $0.state == .verified }.map(\.area))
        for item in applicability where item.status == .required && !verifiedAreas.contains(item.area) {
            topRisks.append("No verified evidence that \(item.area.lowercased()) works.")
        }
        topRisks = dedupePrefix(topRisks, 6)

        let inScope = applicability.filter { $0.status.inScope }
        let nextAction = recommendNextAction(applicability: applicability, verification: verification, findings: findings)
        let chain = buildChain(summary: summary, counts: summaryCounts, trackedTotal: max(inScope.count, summaryCounts.total))
        let score = computeScore(
            identity: identity,
            git: git,
            findings: findings,
            inScopeCount: inScope.count,
            counts: summaryCounts,
            applicability: applicability,
            verification: verification,
            evidenceRecords: evidenceRecords,
            riskRecords: riskRecords,
            assumptionRecords: assumptionRecords
        )
        let currentState = describeState(identity: identity, git: git, mission: mission)

        return RealityAssessment(
            score: score,
            currentState: currentState,
            knownFacts: knownFacts,
            verified: dedupePrefix(verified, 12),
            unverified: dedupePrefix(unverified, 12),
            assumptions: assumptions,
            unknowns: unknowns,
            topRisks: topRisks,
            nextAction: nextAction,
            chain: chain
        )
    }

    private func dedupePrefix(_ items: [String], _ limit: Int) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for item in items where !seen.contains(item) {
            seen.insert(item)
            result.append(item)
            if result.count >= limit { break }
        }
        return result
    }

    private func recommendNextAction(applicability: [ApplicabilityItem], verification: [VerificationRecord], findings: [Finding]) -> String {
        // A failing area is the most urgent thing to address.
        if let failing = verification.first(where: { $0.state == .failed }) {
            return "Fix \(failing.area): it is currently failing\(failing.note.isEmpty ? "." : " — \(failing.note)")."
        }
        // Then verify the highest-priority area that is still unknown.
        let verifiedAreas = Set(verification.filter { $0.state == .verified }.map(\.area))
        let unknownInScope = applicability.filter { $0.status.inScope && !verifiedAreas.contains($0.area) }
        if let target = unknownInScope.first, let suggestion = suggestion(for: target.area) {
            return suggestion
        }
        if let top = findings.sorted(by: { $0.severity > $1.severity }).first(where: { $0.severity >= .warning }) {
            return "Investigate: \(top.title)."
        }
        if !applicability.isEmpty, verifiedAreas.count >= applicability.filter({ $0.status.inScope }).count {
            return "All in-scope areas are marked verified. Re-confirm periodically as verification ages."
        }
        return "Continue read-only monitoring; no in-scope verification gaps were identified."
    }

    private func suggestion(for area: String) -> String? {
        let suggestions: [String: String] = [
            "AU Validation": "Run auval against the built component and record the result.",
            "Preset System": "Test preset save/load and state restore in a host (e.g. Logic).",
            "DSP": "Verify the audio engine renders without real-time-thread violations.",
            "MIDI": "Verify note-on/note-off handling and check for stuck notes in a host.",
            "Audio I/O": "Confirm the plugin produces audio at the expected sample rate.",
            "Persistence": "Confirm data survives a relaunch.",
            "User Interface": "Confirm every declared control is visible and reachable.",
            "Build": "Run a build and confirm it succeeds.",
            "Signing & Notarisation": "Verify code signing and notarisation status.",
            "Automated Tests": "Run the test suite and record the results.",
            "API Stability": "Review the public API surface for unintended breaking changes."
        ]
        return suggestions[area] ?? "Verify \(area) and record the result."
    }

    private func buildChain(summary: RepoSummary, counts: VerificationSummary, trackedTotal: Int) -> [VerificationStageStatus] {
        let anyVerified = counts.verified > 0
        let anyFailed = counts.failed > 0
        let allVerified = trackedTotal > 0 && counts.verified >= trackedTotal && !anyFailed

        return VerificationStage.allCases.map { stage in
            let state: StageState
            switch stage {
            case .implemented:
                state = summary.sourceFiles > 0 ? .reached : .notReached
            case .functional:
                state = anyFailed ? .notReached : (anyVerified ? .reached : .unknown)
            case .tested, .observed:
                state = anyVerified ? .reached : (counts.total > 0 ? .notReached : .unknown)
            case .verified:
                state = allVerified ? .reached : (anyVerified ? .unknown : .notReached)
            default:
                // Built/Loaded/Visible/Reachable are not measured in this phase.
                state = .unknown
            }
            return VerificationStageStatus(stage: stage, state: state)
        }
    }

    private func computeScore(
        identity: ProjectIdentity,
        git: GitStatus,
        findings: [Finding],
        inScopeCount: Int,
        counts: VerificationSummary,
        applicability: [ApplicabilityItem],
        verification: [VerificationRecord],
        evidenceRecords: [EvidenceRecord] = [],
        riskRecords: [RiskRecord] = [],
        assumptionRecords: [AssumptionRecord] = []
    ) -> Int {
        // Phase 6: weighted by priority and decayed by age.
        // A Critical verified-fresh record contributes 4 × 1.0 = 4 weight.
        // A Low verified-stale record contributes 1 × 0.25 = 0.25 weight.
        // Failed-Critical subtracts heavily; Failed-Low barely moves the needle.
        let priorities = Dictionary(uniqueKeysWithValues: applicability.map { (verificationAreaKey($0.area), $0.priority) })
        let inScopeAreaKeys = Set(
            applicability
                .filter { $0.status.inScope }
                .map { verificationAreaKey($0.area) }
        )
        let totalWeight = applicability
            .filter { $0.status.inScope }
            .reduce(0.0) { $0 + $1.priority.weight }

        let strongClassifications: Set<EvidenceClassification> = [.observed, .measured, .verified]
        let backedAreas = Set(
            evidenceRecords
                .filter { strongClassifications.contains($0.classification) }
                .map { verificationAreaKey($0.area) }
        )
        let scoredVerification = effectiveVerificationRecords(
            from: verification,
            scopedTo: totalWeight > 0 ? inScopeAreaKeys : nil
        )
        let effectiveVerificationByArea = Dictionary(
            uniqueKeysWithValues: scoredVerification.map { (verificationAreaKey($0.area), $0) }
        )

        var earned = 0.0
        var penalty = 0.0
        for record in scoredVerification {
            let areaKey = verificationAreaKey(record.area)
            let priority = priorities[areaKey] ?? .medium
            let weight = priority.weight
            switch record.state {
            case .verified:
                // Backed-by-evidence keeps trust at 1.0 even if the record itself has aged.
                let trust = backedAreas.contains(areaKey) ? max(record.age.trust, 0.85) : record.age.trust
                earned += weight * trust
            case .inProgress:
                earned += weight * 0.25 // partial credit while in-flight
            case .failed:
                // Failures with documented evidence still bite, but a tiny credit for honesty.
                penalty += weight * (backedAreas.contains(areaKey) ? 1.1 : 1.25)
            case .unknown:
                break
            }
        }

        var score: Int
        if totalWeight > 0 {
            let coverage = max(0.0, min(1.0, earned / totalWeight))
            // 30 baseline + up to 60 for coverage.
            score = 30 + Int((coverage * 60).rounded())
            // Convert penalty back to a score subtraction relative to totalWeight.
            let penaltyPoints = min(35, Int((penalty / max(1.0, totalWeight)) * 60))
            score -= penaltyPoints
        } else {
            // No applicability matrix yet (unidentified project): recognition + Git only.
            score = 50
            switch identity.confidence {
            case .observed, .measured: score += 16
            case .verified: score += 20
            case .inferred: score += 9
            case .assumed: score += 4
            case .unknown: score -= 25
            }
            score -= min(20, inScopeCount * 3)
        }

        if git.isRepository {
            score += git.isClean ? 8 : 4
            if git.isDetached { score -= 5 }
        }

        let criticals = findings.filter { $0.severity == .critical }.count
        let warnings = findings.filter { $0.severity == .warning }.count
        score -= min(20, criticals * 8 + warnings * 3)

        // Phase 7: open risks and active assumptions tug the score down.
        let openCritical = riskRecords.filter { $0.status == .open && $0.impact == .critical }.count
        let openHigh = riskRecords.filter { $0.status == .open && $0.impact == .high }.count
        let activeAssumptions = assumptionRecords.filter { $0.status == .active }.count
        score -= min(20, openCritical * 6 + openHigh * 3)
        score -= min(10, activeAssumptions * 2)

        // Only a project with no failures and all in-scope areas verified-fresh may reach 100.
        let allCriticalCovered = applicability
            .filter { $0.priority == .critical && $0.status.inScope }
            .allSatisfy { area in
                let record = effectiveVerificationByArea[verificationAreaKey(area.area)]
                return record?.state == .verified && record?.age == .fresh
            }
        let allInScopeVerified = !inScopeAreaKeys.isEmpty && inScopeAreaKeys.allSatisfy {
            effectiveVerificationByArea[$0]?.state == .verified
        }
        let hasCriticalFailure = scoredVerification.contains { record in
            record.state == .failed && priorities[verificationAreaKey(record.area)] == .critical
        }
        let hasUnbackedStaleCritical = scoredVerification.contains { record in
            let areaKey = verificationAreaKey(record.area)
            guard record.state == .verified, priorities[areaKey] == .critical, !backedAreas.contains(areaKey) else {
                return false
            }
            return record.age == .stale || record.age == .expired || record.age == .never
        }
        let fullyVerified = allInScopeVerified && !scoredVerification.contains { $0.state == .failed } && allCriticalCovered
        var ceiling = fullyVerified ? 100 : 96
        if hasUnbackedStaleCritical { ceiling = min(ceiling, 88) }
        if openCritical > 0 { ceiling = min(ceiling, 82) }
        if activeAssumptions >= 3 { ceiling = min(ceiling, 88) }
        if hasCriticalFailure { ceiling = min(ceiling, 72) }
        return max(5, min(ceiling, score))
    }

    private func effectiveVerificationRecords(
        from verification: [VerificationRecord],
        scopedTo areaKeys: Set<String>?
    ) -> [VerificationRecord] {
        var grouped: [String: [VerificationRecord]] = [:]
        for record in verification {
            let key = verificationAreaKey(record.area)
            guard !key.isEmpty else { continue }
            if let areaKeys, !areaKeys.contains(key) { continue }
            grouped[key, default: []].append(record)
        }

        return grouped.compactMap { _, records in
            effectiveVerificationRecord(from: records)
        }
        .sorted { verificationAreaKey($0.area) < verificationAreaKey($1.area) }
    }

    private func effectiveVerificationRecord(from records: [VerificationRecord]) -> VerificationRecord? {
        let failures = records.filter { $0.state == .failed }
        if !failures.isEmpty {
            return failures.max(by: verificationRecordSort)
        }
        return records.max(by: verificationRecordSort)
    }

    private func verificationRecordSort(_ lhs: VerificationRecord, _ rhs: VerificationRecord) -> Bool {
        if lhs.updatedAt != rhs.updatedAt {
            return lhs.updatedAt < rhs.updatedAt
        }
        return verificationStateRiskRank(lhs.state) < verificationStateRiskRank(rhs.state)
    }

    private func verificationStateRiskRank(_ state: VerificationState) -> Int {
        switch state {
        case .verified: 0
        case .inProgress: 1
        case .unknown: 2
        case .failed: 3
        }
    }

    private func verificationAreaKey(_ area: String) -> String {
        area.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func describeState(identity: ProjectIdentity, git: GitStatus, mission: MissionProfile) -> String {
        if identity.kind == .unidentified { return "Unrecognised" }
        let gitPart: String
        if !git.isRepository {
            gitPart = "no Git"
        } else if git.isDetached {
            gitPart = "detached HEAD"
        } else {
            gitPart = git.isClean ? "working tree clean" : "uncommitted changes"
        }
        return "Recognised · \(gitPart)"
    }
}
