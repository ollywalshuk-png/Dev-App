import Foundation

public struct ReleaseTruthDebtBridge: Sendable {
    public init() {}

    public func summary(for report: TruthDebtReport, topLimit: Int = 3) -> ReleaseTruthDebtSummary {
        let blockers = prioritized(report.blockers)
        let caveats = prioritized(report.caveats)
        let limit = max(0, topLimit)

        return ReleaseTruthDebtSummary(
            status: ReleaseTruthDebtSummary.Status(report.status),
            topBlockers: blockers.prefix(limit).map(ReleaseTruthDebtFinding.init),
            topCaveats: caveats.prefix(limit).map(ReleaseTruthDebtFinding.init),
            recommendedNextAction: blockers.first?.recommendedAction
                ?? caveats.first?.recommendedAction
                ?? Self.noDebtRecommendedNextAction
        )
    }

    private static let noDebtRecommendedNextAction = "No truth debt action is required; keep release evidence current."

    private func prioritized(_ gates: [TruthDebtGate]) -> [TruthDebtGate] {
        gates.sorted {
            if $0.severity != $1.severity { return $0.severity < $1.severity }
            if $0.area != $1.area { return $0.area < $1.area }
            if $0.title != $1.title { return $0.title < $1.title }
            return $0.id < $1.id
        }
    }
}

public struct ReleaseTruthDebtSummary: Codable, Hashable, Sendable {
    public enum Status: String, Codable, CaseIterable, Hashable, Sendable {
        case blocked = "Blocked"
        case caveated = "Caveated"
        case defensible = "Defensible"

        init(_ status: TruthDebtStatus) {
            switch status {
            case .blocked:
                self = .blocked
            case .caveated:
                self = .caveated
            case .defensible:
                self = .defensible
            }
        }
    }

    public var status: Status
    public var topBlockers: [ReleaseTruthDebtFinding]
    public var topCaveats: [ReleaseTruthDebtFinding]
    public var recommendedNextAction: String

    public init(
        status: Status,
        topBlockers: [ReleaseTruthDebtFinding],
        topCaveats: [ReleaseTruthDebtFinding],
        recommendedNextAction: String
    ) {
        self.status = status
        self.topBlockers = topBlockers
        self.topCaveats = topCaveats
        self.recommendedNextAction = recommendedNextAction
    }
}

public struct ReleaseTruthDebtFinding: Identifiable, Codable, Hashable, Sendable {
    public var id: String
    public var kind: TruthDebtKind
    public var severity: TruthDebtSeverity
    public var area: String
    public var title: String
    public var detail: String
    public var recommendedAction: String
    public var sourceIdentifiers: [String]

    public init(
        id: String,
        kind: TruthDebtKind,
        severity: TruthDebtSeverity,
        area: String,
        title: String,
        detail: String,
        recommendedAction: String,
        sourceIdentifiers: [String]
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.area = area
        self.title = title
        self.detail = detail
        self.recommendedAction = recommendedAction
        self.sourceIdentifiers = sourceIdentifiers
    }

    public init(gate: TruthDebtGate) {
        self.init(
            id: gate.id,
            kind: gate.kind,
            severity: gate.severity,
            area: gate.area,
            title: gate.title,
            detail: gate.detail,
            recommendedAction: gate.recommendedAction,
            sourceIdentifiers: gate.sourceIdentifiers
        )
    }
}
