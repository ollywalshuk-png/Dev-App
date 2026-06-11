import Foundation

// MARK: - Mission

/// What a project is *trying to be*. Derived read-only from project type, name,
/// and README keywords. This is intentionally a low-confidence inference in the
/// Phase 2 foundation — it is a starting guess, not ground truth.
public enum MissionCategory: String, Codable, CaseIterable, Sendable {
    case instrument = "Instrument"
    case audioEffect = "Audio Effect"
    case application = "Application"
    case developerTool = "Developer Tool"
    case library = "Library"
    case framework = "Framework"
    case web = "Web / Service"
    case script = "Script / Automation"
    case unknown = "Unknown"
}

public struct MissionProfile: Codable, Hashable, Sendable {
    public var category: MissionCategory
    public var statedMission: String
    public var rationale: String
    public var confidence: EvidenceClassification

    public init(
        category: MissionCategory,
        statedMission: String,
        rationale: String,
        confidence: EvidenceClassification
    ) {
        self.category = category
        self.statedMission = statedMission
        self.rationale = rationale
        self.confidence = confidence
    }

    public static let unknown = MissionProfile(
        category: .unknown,
        statedMission: "Mission not yet determined",
        rationale: "Open and scan a project so LocalForge can infer what it is trying to be.",
        confidence: .unknown
    )
}

// MARK: - Applicability

/// Which checks matter for this project. Prevents flagging "AU validation missing"
/// on a document app, or "document workflow missing" on a synth.
public enum ApplicabilityStatus: String, Codable, CaseIterable, Sendable {
    case required = "Required"
    case expected = "Expected"
    case optional = "Optional"
    case notApplicable = "Not Applicable"
    case unknown = "Unknown"

    /// Whether this area is in scope (should eventually be verified).
    public var inScope: Bool {
        self == .required || self == .expected
    }
}

/// Phase 6: how much a verification area weighs against Reality. Critical areas
/// (release blockers) penalise the score far more when they are failed or unknown
/// than Low areas (e.g. documentation).
public enum VerificationPriority: String, Codable, CaseIterable, Hashable, Sendable, Comparable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    public var weight: Double {
        switch self {
        case .critical: 4
        case .high: 3
        case .medium: 2
        case .low: 1
        }
    }

    public var symbolName: String {
        switch self {
        case .critical: "exclamationmark.octagon.fill"
        case .high: "exclamationmark.triangle.fill"
        case .medium: "circle.fill"
        case .low: "circle"
        }
    }

    private var rank: Int {
        switch self {
        case .critical: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        }
    }

    public static func < (lhs: VerificationPriority, rhs: VerificationPriority) -> Bool {
        lhs.rank < rhs.rank
    }
}

public struct ApplicabilityItem: Identifiable, Codable, Hashable, Sendable {
    public var id: String { area }
    public var area: String
    public var status: ApplicabilityStatus
    public var priority: VerificationPriority

    public init(area: String, status: ApplicabilityStatus, priority: VerificationPriority = .medium) {
        self.area = area
        self.status = status
        self.priority = priority
    }

    private enum CodingKeys: String, CodingKey { case area, status, priority }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        area = try c.decode(String.self, forKey: .area)
        status = try c.decode(ApplicabilityStatus.self, forKey: .status)
        priority = try c.decodeIfPresent(VerificationPriority.self, forKey: .priority) ?? .medium
    }
}

// MARK: - Verification chain

public enum VerificationStage: String, Codable, CaseIterable, Sendable {
    case implemented = "Implemented"
    case built = "Built"
    case loaded = "Loaded"
    case visible = "Visible"
    case reachable = "Reachable"
    case functional = "Functional"
    case tested = "Tested"
    case observed = "Observed"
    case verified = "Verified"
}

public enum StageState: String, Codable, Sendable {
    case reached = "Reached"
    case notReached = "Not Reached"
    case unknown = "Unknown"
}

public struct VerificationStageStatus: Identifiable, Codable, Hashable, Sendable {
    public var id: String { stage.rawValue }
    public var stage: VerificationStage
    public var state: StageState

    public init(stage: VerificationStage, state: StageState) {
        self.stage = stage
        self.state = state
    }
}

// MARK: - Reality

/// The highest-level answer LocalForge exists to give:
/// "What is actually true about this software, and what should happen next?"
public struct RealityAssessment: Codable, Hashable, Sendable {
    public var score: Int                  // 0–100, never 100 until something is Verified
    public var currentState: String
    public var knownFacts: [String]
    public var verified: [String]
    public var unverified: [String]
    public var assumptions: [String]
    public var unknowns: [String]
    public var topRisks: [String]
    public var nextAction: String
    public var chain: [VerificationStageStatus]

    public init(
        score: Int,
        currentState: String,
        knownFacts: [String],
        verified: [String],
        unverified: [String],
        assumptions: [String],
        unknowns: [String],
        topRisks: [String],
        nextAction: String,
        chain: [VerificationStageStatus]
    ) {
        self.score = score
        self.currentState = currentState
        self.knownFacts = knownFacts
        self.verified = verified
        self.unverified = unverified
        self.assumptions = assumptions
        self.unknowns = unknowns
        self.topRisks = topRisks
        self.nextAction = nextAction
        self.chain = chain
    }

    public static let unknown = RealityAssessment(
        score: 0,
        currentState: "Unscanned",
        knownFacts: [],
        verified: [],
        unverified: [],
        assumptions: [],
        unknowns: ["No scan has been run yet."],
        topRisks: [],
        nextAction: "Open a repository and run a read-only scan.",
        chain: VerificationStage.allCases.map { VerificationStageStatus(stage: $0, state: .unknown) }
    )
}
