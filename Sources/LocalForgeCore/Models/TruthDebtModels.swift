import Foundation

public enum TruthDebtKind: String, Codable, CaseIterable, Hashable, Sendable {
    case missingMission = "Missing Mission"
    case missingEvidence = "Missing Evidence"
    case unverifiedArea = "Unverified Area"
    case failedVerification = "Failed Verification"
    case staleVerification = "Stale Verification"
    case blockedDependency = "Blocked Dependency"
    case releaseBlockingRisk = "Release-Blocking Risk"
    case activeAssumption = "Active Assumption"
    case contradictoryEvidence = "Contradictory Evidence"
}

public enum TruthDebtSeverity: String, Codable, CaseIterable, Hashable, Sendable, Comparable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    private var rank: Int {
        switch self {
        case .critical: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        }
    }

    public static func < (lhs: TruthDebtSeverity, rhs: TruthDebtSeverity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum TruthDebtStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case blocked = "Blocked"
    case caveated = "Caveated"
    case defensible = "Defensible"
}

public struct TruthDebtGate: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: TruthDebtKind
    public var severity: TruthDebtSeverity
    public var area: String
    public var title: String
    public var detail: String
    public var recommendedAction: String
    public var blocksReleaseClaim: Bool
    public var sourceIdentifiers: [String]

    public init(
        kind: TruthDebtKind,
        severity: TruthDebtSeverity,
        area: String = "",
        title: String,
        detail: String,
        recommendedAction: String,
        blocksReleaseClaim: Bool,
        sourceIdentifiers: [String] = []
    ) {
        self.kind = kind
        self.severity = severity
        self.area = area
        self.title = title
        self.detail = detail
        self.recommendedAction = recommendedAction
        self.blocksReleaseClaim = blocksReleaseClaim
        self.sourceIdentifiers = sourceIdentifiers
        id = [
            kind.rawValue,
            area,
            title,
            sourceIdentifiers.sorted().joined(separator: ",")
        ].joined(separator: "|")
    }
}

public struct TruthDebtReport: Codable, Hashable, Sendable {
    public var gates: [TruthDebtGate]

    public init(gates: [TruthDebtGate]) {
        self.gates = gates
    }

    public var status: TruthDebtStatus {
        if gates.contains(where: \.blocksReleaseClaim) { return .blocked }
        return gates.isEmpty ? .defensible : .caveated
    }

    public var isReleaseClaimDefensible: Bool {
        !gates.contains(where: \.blocksReleaseClaim)
    }

    public var blockers: [TruthDebtGate] {
        gates.filter(\.blocksReleaseClaim)
    }

    public var caveats: [TruthDebtGate] {
        gates.filter { !$0.blocksReleaseClaim }
    }

    public var headline: String {
        switch status {
        case .blocked:
            "\(blockers.count) truth debt gate(s) block a release-ready claim."
        case .caveated:
            "\(caveats.count) truth debt caveat(s) remain, but no Critical/High claim blocker is present."
        case .defensible:
            "No truth debt gates detected for the current records."
        }
    }

    public var nextActions: [String] {
        gates.prefix(5).map(\.recommendedAction)
    }
}
