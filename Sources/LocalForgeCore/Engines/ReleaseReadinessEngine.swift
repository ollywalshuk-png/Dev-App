import Foundation

/// Builds the Release Readiness board (per-project) and Workspace Insights
/// (cross-project) from real verification records. No automation, no scanning —
/// just an honest read of what the user has marked.
public struct ReleaseReadinessEngine: Sendable {
    public init() {}

    public func board(
        for snapshot: RepoSnapshot,
        evidence evidenceRecords: [EvidenceRecord] = [],
        risks: [RiskRecord] = [],
        environments: [EnvironmentSnapshot] = []
    ) -> ReleaseReadinessBoard {
        let stateByArea = snapshot.verification.reduce(into: [String: VerificationState]()) { states, record in
            states[normalized(record.area)] = record.state
        }

        let inScope = snapshot.applicability.filter { $0.status.inScope }
        var rows: [ReleaseAreaStatus] = []
        var blockerNodes = Set<String>()
        var caveats: [String] = []
        var criticalRemaining = 0
        var highRemaining = 0

        for item in inScope {
            let record = snapshot.verification.first { normalized($0.area) == normalized(item.area) }
            let state = record?.state ?? .unknown
            let ageDesc = record?.ageDescription ?? ""
            let blockedBy = resolveBlockers(for: item.area, in: snapshot.verification, stateByArea: stateByArea)
            let staleTrust = staleTrustCaveat(for: record)
            let missingEvidence = missingEvidenceCaveat(
                for: record,
                releaseArea: item.area,
                evidenceRecords: evidenceRecords,
                snapshotEvidence: snapshot.evidence
            )
            let releaseSatisfied = state == .verified && blockedBy.isEmpty && staleTrust == nil && missingEvidence == nil

            rows.append(ReleaseAreaStatus(
                area: item.area,
                priority: item.priority,
                state: state,
                ageDescription: ageDesc,
                blockedBy: blockedBy
            ))

            if !releaseSatisfied {
                switch item.priority {
                case .critical: criticalRemaining += 1
                case .high: highRemaining += 1
                default:
                    caveats.append(caveat(
                        for: item.area,
                        state: state,
                        staleTrust: staleTrust,
                        missingEvidence: missingEvidence,
                        blockedBy: blockedBy
                    ))
                }

                if item.priority == .critical || item.priority == .high,
                   staleTrust != nil || missingEvidence != nil || !blockedBy.isEmpty {
                    caveats.append(caveat(
                        for: item.area,
                        state: state,
                        staleTrust: staleTrust,
                        missingEvidence: missingEvidence,
                        blockedBy: blockedBy
                    ))
                }
            }
            if state == .failed && (item.priority == .critical || item.priority == .high) {
                blockerNodes.insert(item.area)
            }
            if !blockedBy.isEmpty && (item.priority == .critical || item.priority == .high) {
                if blockedBy.contains(where: { $0.contains("(Failed)") }) {
                    releaseBlockingDependencies(from: blockedBy).forEach { blockerNodes.insert($0) }
                }
            }
        }

        let riskBlockers = risks.filter(\.isReleaseBlocking).map { $0.title }.sorted()
        let blockers = blockerNodes.sorted()
        if let environmentCaveat = environmentSnapshotCaveat(environments) {
            caveats.append(environmentCaveat)
        }

        rows.sort { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.area < rhs.area
        }

        let counts = VerificationSummary(records: snapshot.verification.filter { record in
            inScope.contains { normalized($0.area) == normalized(record.area) }
        })

        let unknownOrInProgress = rows.filter { $0.state == .unknown || $0.state == .inProgress }.count
        let status = computeStatusFinal(
            blockers: blockers,
            unknownOrInProgress: unknownOrInProgress,
            criticalRemaining: criticalRemaining,
            highRemaining: highRemaining,
            totalInScope: inScope.count,
            riskBlockers: riskBlockers,
            caveatCount: caveats.count
        )

        let headline: String
        switch status {
        case .ready:
            headline = "All in-scope areas verified with fresh, unblocked evidence. No release-blocking risks recorded."
        case .readyWithCaveats:
            headline = "Critical and High gates are clear, but \(caveats.count) lower-priority caveat(s) remain: \(preview(caveats))."
        case .notReady:
            headline = "\(criticalRemaining + highRemaining) Critical/High release gate(s) need verified, fresh, unblocked evidence: \(preview(caveats))."
        case .blocked:
            headline = "Blocked by \(blockers.count) verification blocker(s) and \(riskBlockers.count) release-blocking risk(s): \(preview(blockers + riskBlockers))."
        case .unknown:
            headline = "No in-scope areas to track — set up the project first."
        }

        return ReleaseReadinessBoard(
            status: status,
            headline: headline,
            rows: rows,
            counts: counts,
            criticalRemaining: criticalRemaining,
            highRemaining: highRemaining,
            blockers: blockers,
            caveats: caveats,
            riskBlockers: riskBlockers
        )
    }

    /// Resolve "which dependencies of this area are currently not verified".
    /// Used to surface "AU Validation blocked by: Preset System (Failed)".
    private func resolveBlockers(
        for area: String,
        in verification: [VerificationRecord],
        stateByArea: [String: VerificationState]
    ) -> [String] {
        guard let record = verification.first(where: { normalized($0.area) == normalized(area) }) else { return [] }
        let blockers = record.dependsOn.compactMap { dep in
            switch stateByArea[normalized(dep)] ?? .unknown {
            case .failed: return "\(dep) (Failed)"
            case .unknown: return "\(dep) (Unknown)"
            case .inProgress: return "\(dep) (In Progress)"
            case .verified: return nil
            }
        }
        return Array(Set(blockers)).sorted()
    }

    private func releaseBlockingDependencies(from blockedBy: [String]) -> [String] {
        blockedBy.compactMap { blocker in
            guard blocker.hasSuffix(" (Failed)") else { return nil }
            return String(blocker.dropLast(" (Failed)".count))
        }
    }

    private func staleTrustCaveat(for record: VerificationRecord?) -> String? {
        guard let record, record.state == .verified else { return nil }
        switch record.age {
        case .stale: return "Stale"
        case .expired: return "Expired"
        case .fresh, .recent, .ageing, .never: return nil
        }
    }

    private func caveat(
        for area: String,
        state: VerificationState,
        staleTrust: String?,
        missingEvidence: String?,
        blockedBy: [String]
    ) -> String {
        if !blockedBy.isEmpty {
            return "\(area) blocked by \(blockedBy.joined(separator: ", "))."
        }
        if let staleTrust {
            return "\(area) verification is \(staleTrust.lowercased())."
        }
        if let missingEvidence {
            return missingEvidence
        }
        return "\(area) is \(state.rawValue)."
    }

    private func missingEvidenceCaveat(
        for record: VerificationRecord?,
        releaseArea: String,
        evidenceRecords: [EvidenceRecord],
        snapshotEvidence: [Evidence]
    ) -> String? {
        guard let record, record.state == .verified else { return nil }
        guard !hasStrongEvidence(
            for: record,
            releaseArea: releaseArea,
            evidenceRecords: evidenceRecords,
            snapshotEvidence: snapshotEvidence
        ) else { return nil }
        return "\(releaseArea) is verified without strong evidence."
    }

    private func hasStrongEvidence(
        for record: VerificationRecord,
        releaseArea: String,
        evidenceRecords: [EvidenceRecord],
        snapshotEvidence: [Evidence]
    ) -> Bool {
        if evidenceRecords.contains(where: { evidence in
            isStrongEvidence(evidence.classification)
                && (
                    normalized(evidence.area) == normalized(record.area)
                        || evidence.linkedVerificationIDs.contains(record.id)
                        || evidence.linkedID == record.id
                )
        }) {
            return true
        }

        return snapshotEvidence.contains { evidence in
            isStrongEvidence(evidence.classification)
                && legacyEvidence(evidence, matchesReleaseArea: releaseArea)
        }
    }

    private func legacyEvidence(_ evidence: Evidence, matchesReleaseArea area: String) -> Bool {
        let needle = normalized(area)
        guard !needle.isEmpty else { return false }
        return normalized(evidence.title).contains(needle)
            || normalized(evidence.detail).contains(needle)
            || normalized(evidence.source).contains(needle)
    }

    private func isStrongEvidence(_ classification: EvidenceClassification) -> Bool {
        classification == .observed || classification == .measured || classification == .verified
    }

    private func environmentSnapshotCaveat(_ environments: [EnvironmentSnapshot]) -> String? {
        guard let latest = environments.sorted(by: { $0.capturedAt > $1.capturedAt }).first else { return nil }

        let missingFields = [
            ("macOS", latest.macOSVersion),
            ("Xcode", latest.xcodeVersion),
            ("Swift", latest.swiftVersion),
            ("SDK", latest.sdkVersion),
        ]
        .filter { $0.1.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        .map(\.0)

        let age = VerificationAge.from(latest.capturedAt)
        let recapture = "Capture a fresh local environment snapshot before release claims."

        if !missingFields.isEmpty {
            let fieldList = missingFields.joined(separator: ", ")
            if age == .stale || age == .expired {
                return "Environment snapshot is \(age.rawValue.lowercased()) and incomplete (missing \(fieldList)). \(recapture)"
            }
            return "Environment snapshot is incomplete (missing \(fieldList)). \(recapture)"
        }

        if age == .stale || age == .expired {
            return "Environment snapshot is \(age.rawValue.lowercased()). \(recapture)"
        }

        return nil
    }

    private func normalized(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func preview(_ items: [String]) -> String {
        let visible = items.prefix(3)
        guard !visible.isEmpty else { return "none" }
        let suffix = items.count > visible.count ? " +\(items.count - visible.count) more" : ""
        return visible.joined(separator: ", ") + suffix
    }

    public func computeStatusFinal(
        blockers: [String],
        unknownOrInProgress: Int,
        criticalRemaining: Int,
        highRemaining: Int,
        totalInScope: Int,
        riskBlockers: [String] = [],
        caveatCount: Int? = nil
    ) -> ReleaseReadinessStatus {
        if totalInScope == 0 { return .unknown }
        if !blockers.isEmpty || !riskBlockers.isEmpty { return .blocked }
        if criticalRemaining > 0 || highRemaining > 0 { return .notReady }
        let unresolvedCaveats = caveatCount ?? unknownOrInProgress
        return unresolvedCaveats == 0 ? .ready : .readyWithCaveats
    }

    // MARK: - Cross-project

    public func insights(
        for snapshots: [RepoSnapshot],
        evidenceByProjectID: [UUID: [EvidenceRecord]] = [:],
        risksByProjectID: [UUID: [RiskRecord]] = [:]
    ) -> WorkspaceInsights {
        let summaries = snapshots.map { snapshot in
            summary(
                for: snapshot,
                evidence: evidenceByProjectID[snapshot.project.id] ?? [],
                risks: risksByProjectID[snapshot.project.id] ?? []
            )
        }
        let healthy = summaries.filter { !$0.needsAttention && $0.failed == 0 }.count
        let blocked = summaries.filter { $0.failed > 0 }.count
        let attention = summaries.filter { $0.needsAttention && $0.failed == 0 }.count

        let highestRisk = summaries
            .filter { $0.failed > 0 || $0.realityScore < 60 }
            .sorted { $0.realityScore < $1.realityScore }
            .first
        let mostComplete = summaries
            .sorted { $0.coverage > $1.coverage || ($0.coverage == $1.coverage && $0.realityScore > $1.realityScore) }
            .first
        let leastVerified = summaries
            .filter { $0.totalTracked > 0 }
            .sorted { $0.coverage < $1.coverage }
            .first

        return WorkspaceInsights(
            totalProjects: snapshots.count,
            healthyCount: healthy,
            attentionCount: attention,
            blockedCount: blocked,
            highestRisk: highestRisk,
            mostComplete: mostComplete,
            leastVerified: leastVerified,
            projects: summaries
        )
    }

    private func summary(
        for snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        risks: [RiskRecord]
    ) -> ProjectInsightSummary {
        let board = board(for: snapshot, evidence: evidence, risks: risks)
        let counts = snapshot.verificationSummary
        let needsAttention = snapshot.project.bookmarkStatus.requiresAttention || counts.failed > 0 || (counts.verified == 0 && counts.total > 0)
        return ProjectInsightSummary(
            id: snapshot.project.id,
            name: snapshot.project.name,
            realityScore: snapshot.reality.score,
            verified: counts.verified,
            failed: counts.failed,
            unknown: counts.unknown,
            totalTracked: counts.total,
            topRisk: snapshot.reality.topRisks.first ?? "—",
            release: board.status,
            needsAttention: needsAttention
        )
    }
}

public extension ReleaseReadinessEngine {
    /// Convenience for tests / UI: compute the final status from a board.
    static func finalStatus(for board: ReleaseReadinessBoard) -> ReleaseReadinessStatus {
        if board.rows.isEmpty { return .unknown }
        if !board.blockers.isEmpty || !board.riskBlockers.isEmpty { return .blocked }
        if board.criticalRemaining > 0 || board.highRemaining > 0 { return .notReady }
        return board.caveats.isEmpty ? .ready : .readyWithCaveats
    }
}
