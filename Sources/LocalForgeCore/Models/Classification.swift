import Foundation

public enum EvidenceClassification: String, Codable, CaseIterable, Sendable {
    case observed = "Observed"
    case measured = "Measured"
    case verified = "Verified"
    case inferred = "Inferred"
    case assumed = "Assumed"
    case unknown = "Unknown"
}

public enum Severity: String, Codable, CaseIterable, Comparable, Sendable {
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"

    private var rank: Int {
        switch self {
        case .info: 0
        case .warning: 1
        case .critical: 2
        }
    }

    public static func < (lhs: Severity, rhs: Severity) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum FindingCategory: String, Codable, CaseIterable, Sendable {
    case repository = "Repository"
    case build = "Build"
    case verification = "Verification"
    case security = "Security"
    case privacy = "Privacy"
    case commercial = "Commercial"
    case aiGenerated = "AI Generated"
    case workspaceIntegrity = "Workspace Integrity"
}

public enum RiskLevel: String, Codable, CaseIterable, Comparable, Sendable {
    case healthy = "Healthy"
    case info = "Info"
    case warning = "Warning"
    case critical = "Critical"
    case unknown = "Unknown"

    private var rank: Int {
        switch self {
        case .healthy: 0
        case .info: 1
        case .warning: 2
        case .critical: 3
        case .unknown: -1
        }
    }

    public static func < (lhs: RiskLevel, rhs: RiskLevel) -> Bool {
        lhs.rank < rhs.rank
    }
}

public enum CommandDisposition: String, Codable, Sendable {
    case allowedReadOnly = "Allowed Read-Only"
    case previewOnly = "Preview Only"
    case blocked = "Blocked"
}
