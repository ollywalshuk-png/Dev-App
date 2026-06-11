import Foundation

/// Builds the Release Readiness board (per-project) and Workspace Insights
/// (cross-project) from real verification records. No automation, no scanning —
/// just an honest read of what the user has marked.
public struct ReleaseReadinessEngine: Sendable {
    public init() {}

    public func board(for snapshot: RepoSnapshot) -> ReleaseReadinessBoard {
        let priorityByArea = Dictionary(uniqueKeysWithValues: snapshot.applicability.map { ($0.area, $0.priority) })
        let stateByArea = Dictionary(uniqueKeysWithValues: snapshot.verification.map { ($0.area, $0.state) })

        let inScope = snapshot.applicability.filter { $0.status.inScope }
        var rows: [ReleaseAreaStatus] = []
        var blockers: [String] = []
        var criticalRemaining = 0
        var highRemaining = 0

        for item in inScope {
            let record = snapshot.verification.first { $0.area == item.area }
            let state = record?.state ?? .unknown
            let ageDesc = record?.ageDescription ?? ""
            let blockedBy = resolveBlockers(for: item.area, in: snapshot.verification, stateByArea: stateByArea)

            rows.append(ReleaseAreaStatus(
                area: item.area,
                priority: item.priority,
                state: state,
                ageDescription: ageDesc,
                blockedBy: blockedBy
            ))

            if state != .verified {
                switch item.priority {
                case .critical: criticalRemaining += 1
                case .high: highRemaining += 1
                default: break
                }
            }
            if state == .failed && (item.priority == .critical || item.priority == .high) {
                blockers.append(item.area)
            }
        }

        rows.sort { lhs, rhs in
            if lhs.priority != rhs.priority { return lhs.priority < rhs.priority }
            return lhs.area < rhs.area
        }

        let counts = VerificationSummary(records: snapshot.verification.filter { record in
            inScope.contains { $0.area == record.area }
        })

        let unknownOrInProgress = rows.filter { $0.state == .unknown || $0.state == .inProgress }.count
        let status = computeStatusFinal(
            blockers: blockers,
            unknownOrInProgress: unknownOrInProgress,
            criticalRemaining: criticalRemaining,
            highRemaining: highRemaining,
            totalInScope: inScope.count
        )

        let headline: String
        switch status {
        case .ready:
            headline = "All in-scope areas verified. Cleared to ship."
        case .readyWithCaveats:
            headline = "Critical and High areas verified, but \(counts.unknown + counts.inProgress) lower-priority area(s) remain unverified."
        case .notReady:
            headline = "\(criticalRemaining + highRemaining) Critical/High area(s) still unverified."
        case .blocked:
            headline = "Blocked by \(blockers.count) failing Critical/High area(s): \(blockers.joined(separator: ", "))."
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
            blockers: blockers
        )
    }

    /// Resolve "which dependencies of this area are currently not verified".
    /// Used to surface "AU Validation blocked by: Preset System (Failed)".
    private func resolveBlockers(
        for area: String,
        in verification: [VerificationRecord],
        stateByArea: [String: VerificationState]
    ) -> [String] {
        guard let record = verification.first(where: { $0.area == area }) else { return [] }
        return record.dependsOn.compactMap { dep in
            switch stateByArea[dep] ?? .unknown {
            case .failed: return "\(dep) (Failed)"
            case .unknown: return "\(dep) (Unknown)"
            case .inProgress: return "\(dep) (In Progress)"
            case .verified: return nil
            }
        }
    }

    public func computeStatusFinal(
        blockers: [String],
        unknownOrInProgress: Int,
        criticalRemaining: Int,
        highRemaining: Int,
        totalInScope: Int
    ) -> ReleaseReadinessStatus {
        if totalInScope == 0 { return .unknown }
        if !blockers.isEmpty { return .blocked }
        if criticalRemaining > 0 || highRemaining > 0 { return .notReady }
        return unknownOrInProgress == 0 ? .ready : .readyWithCaveats
    }

    // MARK: - Cross-project

    public func insights(for snapshots: [RepoSnapshot]) -> WorkspaceInsights {
        let summaries = snapshots.map { summary(for: $0) }
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

    private func summary(for snapshot: RepoSnapshot) -> ProjectInsightSummary {
        let board = board(for: snapshot)
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
        if !board.blockers.isEmpty { return .blocked }
        if board.criticalRemaining > 0 || board.highRemaining > 0 { return .notReady }
        let remaining = board.rows.contains { $0.state != .verified }
        return remaining ? .readyWithCaveats : .ready
    }
}
