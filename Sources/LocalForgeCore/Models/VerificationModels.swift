import Foundation

// MARK: - User-defined mission

/// A mission the user has explicitly defined for a project. This replaces the
/// inferred guess with ground truth about intent: what it is, what it is trying
/// to become, the goals, the current phase, and known issues.
public struct UserMissionProfile: Codable, Hashable, Sendable {
    public var statedMission: String
    public var category: MissionCategory
    public var goals: [String]
    public var currentPhase: String
    public var knownIssues: [String]
    public var updatedAt: Date

    public init(
        statedMission: String,
        category: MissionCategory = .unknown,
        goals: [String] = [],
        currentPhase: String = "",
        knownIssues: [String] = [],
        updatedAt: Date = Date()
    ) {
        self.statedMission = statedMission
        self.category = category
        self.goals = goals
        self.currentPhase = currentPhase
        self.knownIssues = knownIssues
        self.updatedAt = updatedAt
    }

    public var isDefined: Bool {
        !statedMission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    /// Project the user's mission into the display `MissionProfile`. Because the
    /// user stated it directly, it is Observed, not inferred.
    public func asMissionProfile() -> MissionProfile {
        var rationale = "Defined by you."
        if !currentPhase.isEmpty { rationale += " Current phase: \(currentPhase)." }
        return MissionProfile(
            category: category,
            statedMission: statedMission,
            rationale: rationale,
            confidence: .observed
        )
    }
}

// MARK: - Verification records

public enum VerificationState: String, Codable, CaseIterable, Sendable {
    case verified = "Verified"
    case inProgress = "In Progress"
    case failed = "Failed"
    case unknown = "Unknown"

    public var symbolName: String {
        switch self {
        case .verified: "checkmark.circle.fill"
        case .inProgress: "clock.fill"
        case .failed: "xmark.octagon.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

/// A single area of a project and whether the user (or observation) has verified it.
/// Verification decays in spirit: it records who/when so trust can age later.
public struct VerificationRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var area: String
    public var state: VerificationState
    public var note: String
    public var verifiedBy: String
    public var updatedAt: Date
    /// Phase 6.5: other areas (by name) this area depends on. Used to compute
    /// "AU Validation is blocked by Preset System (Failed)" without any AI.
    public var dependsOn: [String]

    public init(
        id: UUID = UUID(),
        area: String,
        state: VerificationState = .unknown,
        note: String = "",
        verifiedBy: String = "",
        updatedAt: Date = Date(),
        dependsOn: [String] = []
    ) {
        self.id = id
        self.area = area
        self.state = state
        self.note = note
        self.verifiedBy = verifiedBy
        self.updatedAt = updatedAt
        self.dependsOn = dependsOn
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case area
        case state
        case note
        case verifiedBy
        case updatedAt
        case dependsOn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        area = try container.decode(String.self, forKey: .area)
        state = try container.decodeIfPresent(VerificationState.self, forKey: .state) ?? .unknown
        note = try container.decodeIfPresent(String.self, forKey: .note) ?? ""
        verifiedBy = try container.decodeIfPresent(String.self, forKey: .verifiedBy) ?? ""
        updatedAt = try container.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        dependsOn = try container.decodeIfPresent([String].self, forKey: .dependsOn) ?? []
    }
}

/// Phase 6: trust in a verification decays over time. Fresh evidence is gold;
/// six-month-old evidence needs re-confirmation.
public enum VerificationAge: String, Codable, Hashable, Sendable {
    case fresh = "Fresh"           // <= 7 days
    case recent = "Recent"         // 8–30 days
    case ageing = "Ageing"         // 31–90 days
    case stale = "Stale"           // 91–180 days
    case expired = "Expired"       // > 180 days
    case never = "Never"           // no timestamp yet

    public static func from(_ date: Date?, now: Date = Date()) -> VerificationAge {
        guard let date else { return .never }
        let days = Int(now.timeIntervalSince(date) / 86_400)
        if days <= 7 { return .fresh }
        if days <= 30 { return .recent }
        if days <= 90 { return .ageing }
        if days <= 180 { return .stale }
        return .expired
    }

    /// Multiplier applied to a Verified record's contribution. Fresh = full credit;
    /// stale = quarter credit; expired = treated as unknown.
    public var trust: Double {
        switch self {
        case .fresh: 1.0
        case .recent: 0.85
        case .ageing: 0.6
        case .stale: 0.25
        case .expired: 0.0
        case .never: 0.0
        }
    }
}

public extension VerificationRecord {
    var age: VerificationAge {
        state == .unknown ? .never : VerificationAge.from(updatedAt)
    }

    /// Short relative phrase ("2d ago", "Today", "3 months ago"). Empty for unknown.
    var ageDescription: String {
        guard state != .unknown else { return "" }
        let seconds = Int(Date().timeIntervalSince(updatedAt))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86_400 { return "\(seconds / 3600)h ago" }
        let days = seconds / 86_400
        if days == 1 { return "yesterday" }
        if days <= 30 { return "\(days)d ago" }
        if days <= 365 { return "\(days / 30)mo ago" }
        return "\(days / 365)y ago"
    }
}

public struct VerificationSummary: Codable, Hashable, Sendable {
    public var verified: Int
    public var inProgress: Int
    public var failed: Int
    public var unknown: Int

    public init(verified: Int = 0, inProgress: Int = 0, failed: Int = 0, unknown: Int = 0) {
        self.verified = verified
        self.inProgress = inProgress
        self.failed = failed
        self.unknown = unknown
    }

    public init(records: [VerificationRecord]) {
        self.init()
        for record in records {
            switch record.state {
            case .verified: verified += 1
            case .inProgress: inProgress += 1
            case .failed: failed += 1
            case .unknown: unknown += 1
            }
        }
    }

    public var total: Int { verified + inProgress + failed + unknown }
    public var coverage: Double { total == 0 ? 0 : Double(verified) / Double(total) }
}

// MARK: - Project setup

public struct ProjectSetupDraft: Codable, Hashable, Sendable {
    public var mission: String
    public var category: MissionCategory
    public var currentPhase: String
    public var selectedVerificationAreas: [String]
    public var author: String

    public init(
        mission: String,
        category: MissionCategory,
        currentPhase: String,
        selectedVerificationAreas: [String],
        author: String = ""
    ) {
        self.mission = mission
        self.category = category
        self.currentPhase = currentPhase
        self.selectedVerificationAreas = selectedVerificationAreas
        self.author = author
    }

    public func materialize() -> ProjectSetupResult {
        let trimmedMission = mission.trimmingCharacters(in: .whitespacesAndNewlines)
        let phase = currentPhase.trimmingCharacters(in: .whitespacesAndNewlines)
        let records = selectedVerificationAreas.map { area in
            VerificationRecord(
                area: area,
                state: .unknown,
                note: "",
                verifiedBy: author
            )
        }
        return ProjectSetupResult(
            mission: UserMissionProfile(
                statedMission: trimmedMission,
                category: category,
                currentPhase: phase
            ),
            verification: records
        )
    }
}

public struct ProjectSetupResult: Codable, Hashable, Sendable {
    public var mission: UserMissionProfile
    public var verification: [VerificationRecord]

    public init(mission: UserMissionProfile, verification: [VerificationRecord]) {
        self.mission = mission
        self.verification = verification
    }
}

// MARK: - Knowledge

public enum KnowledgeNoteKind: String, Codable, CaseIterable, Hashable, Sendable {
    case knownIssue = "Known Issue"
    case decision = "Decision"
    case architectureNote = "Architecture Note"
    case releaseNote = "Release Note"
    case lessonLearned = "Lesson Learned"
}

public struct KnowledgeNote: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var body: String
    public var kind: KnowledgeNoteKind
    public var author: String
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        body: String,
        kind: KnowledgeNoteKind,
        author: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.kind = kind
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
