import Foundation

public enum TruthContributionSourceKind: String, Codable, CaseIterable, Hashable, Sendable {
    case verification = "Verification"
    case evidence = "Evidence"
    case mission = "Mission"
    case risk = "Risk"
    case assumption = "Assumption"
    case verificationGap = "Verification Gap"
}

public enum TruthContributionDirection: String, Codable, CaseIterable, Hashable, Sendable {
    case positive = "Positive"
    case negative = "Negative"
}

/// Structured source metadata for a material Truth Centre contribution.
///
/// This is attribution, not a second scoring system: rows identify the records
/// that explain existing Truth Centre score inputs without recalculating or
/// changing the score.
public struct TruthContributionProvenanceRow: Identifiable, Codable, Comparable, Hashable, Sendable {
    public var id: String
    public var sourceKind: TruthContributionSourceKind
    public var sourceIdentifier: String
    public var sourceArea: String
    public var status: String
    public var freshness: VerificationAge?
    public var direction: TruthContributionDirection
    public var reason: String
    public var releaseRelevant: Bool

    public init(
        sourceKind: TruthContributionSourceKind,
        sourceIdentifier: String,
        sourceArea: String = "",
        status: String,
        freshness: VerificationAge? = nil,
        direction: TruthContributionDirection,
        reason: String,
        releaseRelevant: Bool
    ) {
        self.sourceKind = sourceKind
        self.sourceIdentifier = sourceIdentifier
        self.sourceArea = sourceArea
        self.status = status
        self.freshness = freshness
        self.direction = direction
        self.reason = reason
        self.releaseRelevant = releaseRelevant
        id = [
            sourceKind.rawValue,
            Self.identityComponent(identifier: sourceIdentifier, area: sourceArea),
            direction.rawValue,
            Self.canonicalAuditComponent(reason)
        ].joined(separator: "|")
    }

    public static func < (lhs: TruthContributionProvenanceRow, rhs: TruthContributionProvenanceRow) -> Bool {
        lhs.auditSortComponents.lexicographicallyPrecedes(rhs.auditSortComponents)
    }

    public static func auditSorted(
        _ rows: [TruthContributionProvenanceRow]
    ) -> [TruthContributionProvenanceRow] {
        rows.sorted()
    }

    private var auditSortComponents: [String] {
        [
            releaseRelevant ? "0" : "1",
            direction == .positive ? "0" : "1",
            sourceKind.rawValue,
            Self.canonicalAuditComponent(sourceArea),
            Self.canonicalAuditComponent(status),
            freshness?.rawValue ?? "",
            Self.canonicalAuditComponent(sourceIdentifier),
            Self.canonicalAuditComponent(reason),
            id
        ]
    }

    private static func identityComponent(identifier: String, area: String) -> String {
        let canonicalIdentifier = canonicalAuditComponent(identifier)
        if !canonicalIdentifier.isEmpty {
            return canonicalIdentifier
        }
        return canonicalAuditComponent(area)
    }

    private static func canonicalAuditComponent(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }
}
