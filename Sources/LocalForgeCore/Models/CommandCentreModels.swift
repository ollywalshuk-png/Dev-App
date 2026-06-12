import Foundation

// MARK: - Release Readiness

public enum ReleaseReadinessStatus: String, Codable, Sendable {
    case ready = "Ready"
    case readyWithCaveats = "Ready with Caveats"
    case notReady = "Not Ready"
    case blocked = "Blocked"
    case unknown = "Unknown"
}

/// One row on the Release Readiness board: a single applicability area's
/// release-ready state, sourced entirely from verification records.
public struct ReleaseAreaStatus: Identifiable, Hashable, Sendable {
    public let id: String
    public var area: String
    public var priority: VerificationPriority
    public var state: VerificationState
    public var ageDescription: String
    public var blockedBy: [String]

    public init(
        area: String,
        priority: VerificationPriority,
        state: VerificationState,
        ageDescription: String = "",
        blockedBy: [String] = []
    ) {
        self.id = area
        self.area = area
        self.priority = priority
        self.state = state
        self.ageDescription = ageDescription
        self.blockedBy = blockedBy
    }
}

public struct ReleaseReadinessBoard: Hashable, Sendable {
    public var status: ReleaseReadinessStatus
    public var headline: String
    public var rows: [ReleaseAreaStatus]
    public var counts: VerificationSummary
    public var criticalRemaining: Int
    public var highRemaining: Int
    public var blockers: [String]
    public var caveats: [String]
    public var riskBlockers: [String]

    public init(
        status: ReleaseReadinessStatus,
        headline: String,
        rows: [ReleaseAreaStatus],
        counts: VerificationSummary,
        criticalRemaining: Int,
        highRemaining: Int,
        blockers: [String],
        caveats: [String] = [],
        riskBlockers: [String] = []
    ) {
        self.status = status
        self.headline = headline
        self.rows = rows
        self.counts = counts
        self.criticalRemaining = criticalRemaining
        self.highRemaining = highRemaining
        self.blockers = blockers
        self.caveats = caveats
        self.riskBlockers = riskBlockers
    }

    public var rowsByPriority: [(priority: VerificationPriority, rows: [ReleaseAreaStatus])] {
        let order: [VerificationPriority] = [.critical, .high, .medium, .low]
        return order.map { p in (p, rows.filter { $0.priority == p }) }
    }
}

// MARK: - Workspace insights (cross-project)

public struct ProjectInsightSummary: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var realityScore: Int
    public var verified: Int
    public var failed: Int
    public var unknown: Int
    public var totalTracked: Int
    public var topRisk: String
    public var release: ReleaseReadinessStatus
    public var needsAttention: Bool

    public init(
        id: UUID,
        name: String,
        realityScore: Int,
        verified: Int,
        failed: Int,
        unknown: Int,
        totalTracked: Int,
        topRisk: String,
        release: ReleaseReadinessStatus,
        needsAttention: Bool
    ) {
        self.id = id
        self.name = name
        self.realityScore = realityScore
        self.verified = verified
        self.failed = failed
        self.unknown = unknown
        self.totalTracked = totalTracked
        self.topRisk = topRisk
        self.release = release
        self.needsAttention = needsAttention
    }

    public var coverage: Double {
        totalTracked == 0 ? 0 : Double(verified) / Double(totalTracked)
    }
}

public struct WorkspaceInsights: Hashable, Sendable {
    public var totalProjects: Int
    public var healthyCount: Int
    public var attentionCount: Int
    public var blockedCount: Int
    public var highestRisk: ProjectInsightSummary?
    public var mostComplete: ProjectInsightSummary?
    public var leastVerified: ProjectInsightSummary?
    public var projects: [ProjectInsightSummary]

    public init(
        totalProjects: Int,
        healthyCount: Int,
        attentionCount: Int,
        blockedCount: Int,
        highestRisk: ProjectInsightSummary?,
        mostComplete: ProjectInsightSummary?,
        leastVerified: ProjectInsightSummary?,
        projects: [ProjectInsightSummary]
    ) {
        self.totalProjects = totalProjects
        self.healthyCount = healthyCount
        self.attentionCount = attentionCount
        self.blockedCount = blockedCount
        self.highestRisk = highestRisk
        self.mostComplete = mostComplete
        self.leastVerified = leastVerified
        self.projects = projects
    }

    public static let empty = WorkspaceInsights(
        totalProjects: 0, healthyCount: 0, attentionCount: 0, blockedCount: 0,
        highestRisk: nil, mostComplete: nil, leastVerified: nil, projects: []
    )
}
