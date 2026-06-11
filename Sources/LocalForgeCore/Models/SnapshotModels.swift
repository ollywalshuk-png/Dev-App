import Foundation

public struct Evidence: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var detail: String
    public var classification: EvidenceClassification
    public var source: String
    public var collectedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        classification: EvidenceClassification,
        source: String,
        collectedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.classification = classification
        self.source = source
        self.collectedAt = collectedAt
    }
}

public struct Finding: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var detail: String
    public var severity: Severity
    public var category: FindingCategory
    public var evidenceClassification: EvidenceClassification

    public init(
        id: UUID = UUID(),
        title: String,
        detail: String,
        severity: Severity,
        category: FindingCategory,
        evidenceClassification: EvidenceClassification
    ) {
        self.id = id
        self.title = title
        self.detail = detail
        self.severity = severity
        self.category = category
        self.evidenceClassification = evidenceClassification
    }
}

public struct RepoSummary: Codable, Hashable, Sendable {
    public var totalFiles: Int
    public var sourceFiles: Int
    public var testFiles: Int
    public var documentationFiles: Int
    public var largeFiles: Int

    public init(
        totalFiles: Int = 0,
        sourceFiles: Int = 0,
        testFiles: Int = 0,
        documentationFiles: Int = 0,
        largeFiles: Int = 0
    ) {
        self.totalFiles = totalFiles
        self.sourceFiles = sourceFiles
        self.testFiles = testFiles
        self.documentationFiles = documentationFiles
        self.largeFiles = largeFiles
    }
}

public struct RepoSnapshot: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var project: ProjectContext
    public var scannedAt: Date
    public var permissionState: PermissionState
    public var scanPolicy: ScanPolicy
    public var identity: ProjectIdentity
    public var mission: MissionProfile
    public var userMission: UserMissionProfile?
    public var applicability: [ApplicabilityItem]
    public var verification: [VerificationRecord]
    public var reality: RealityAssessment
    public var git: GitStatus
    public var summary: RepoSummary
    public var findings: [Finding]
    public var evidence: [Evidence]
    public var isReadOnly: Bool

    public init(
        id: UUID = UUID(),
        project: ProjectContext,
        scannedAt: Date = Date(),
        permissionState: PermissionState,
        scanPolicy: ScanPolicy,
        identity: ProjectIdentity = .unknown,
        mission: MissionProfile = .unknown,
        userMission: UserMissionProfile? = nil,
        applicability: [ApplicabilityItem] = [],
        verification: [VerificationRecord] = [],
        reality: RealityAssessment = .unknown,
        git: GitStatus = .unknown,
        summary: RepoSummary,
        findings: [Finding],
        evidence: [Evidence],
        isReadOnly: Bool = true
    ) {
        self.id = id
        self.project = project
        self.scannedAt = scannedAt
        self.permissionState = permissionState
        self.scanPolicy = scanPolicy
        self.identity = identity
        self.mission = mission
        self.userMission = userMission
        self.applicability = applicability
        self.verification = verification
        self.reality = reality
        self.git = git
        self.summary = summary
        self.findings = findings
        self.evidence = evidence
        self.isReadOnly = isReadOnly
    }

    public var verificationSummary: VerificationSummary { VerificationSummary(records: verification) }
}

public extension RepoSnapshot {
    static func fixture(
        findings: [Finding] = [],
        identity: ProjectIdentity = .unknown,
        git: GitStatus = .unknown
    ) -> RepoSnapshot {
        RepoSnapshot(
            project: ProjectContext(
                name: "Fixture",
                rootURL: URL(fileURLWithPath: "/tmp/fixture"),
                permission: .approved(scopeDescription: "fixture")
            ),
            permissionState: .approved,
            scanPolicy: .balanced,
            identity: identity,
            git: git,
            summary: RepoSummary(totalFiles: 3, sourceFiles: 1, testFiles: 1, documentationFiles: 1),
            findings: findings,
            evidence: [
                Evidence(
                    title: "Fixture evidence",
                    detail: "Synthetic snapshot for tests",
                    classification: .observed,
                    source: "fixture"
                )
            ]
        )
    }
}

public struct GuardianRecommendation: Codable, Hashable, Sendable {
    public var mode: String
    public var riskLevel: RiskLevel
    public var topIssue: String
    public var evidence: String
    public var confidence: EvidenceClassification
    public var nextAction: String
    // Phase 5: richer Guardian — Top Issue · Status · Evidence · Impact · Suggested Action.
    public var area: String
    public var status: String
    public var impact: String
    public var suggestedAction: String
    public var verifiedBy: String
    // Phase 6: richer context for the top issue.
    public var lastObservedAt: Date?
    public var estimatedEffortMinutes: Int
    public var priority: VerificationPriority?
    // Phase 6.5: living-document context.
    public var blockedBy: [String]
    public var recentActivity: [String]
    public var linkedJournalCount: Int
    public var linkedNotesCount: Int
    public var linkedEvidenceCount: Int

    public init(
        mode: String,
        riskLevel: RiskLevel,
        topIssue: String,
        evidence: String,
        confidence: EvidenceClassification,
        nextAction: String,
        area: String = "",
        status: String = "",
        impact: String = "",
        suggestedAction: String = "",
        verifiedBy: String = "",
        lastObservedAt: Date? = nil,
        estimatedEffortMinutes: Int = 0,
        priority: VerificationPriority? = nil,
        blockedBy: [String] = [],
        recentActivity: [String] = [],
        linkedJournalCount: Int = 0,
        linkedNotesCount: Int = 0,
        linkedEvidenceCount: Int = 0
    ) {
        self.mode = mode
        self.riskLevel = riskLevel
        self.topIssue = topIssue
        self.evidence = evidence
        self.confidence = confidence
        self.nextAction = nextAction
        self.area = area
        self.status = status
        self.impact = impact
        self.suggestedAction = suggestedAction
        self.verifiedBy = verifiedBy
        self.lastObservedAt = lastObservedAt
        self.estimatedEffortMinutes = estimatedEffortMinutes
        self.priority = priority
        self.blockedBy = blockedBy
        self.recentActivity = recentActivity
        self.linkedJournalCount = linkedJournalCount
        self.linkedNotesCount = linkedNotesCount
        self.linkedEvidenceCount = linkedEvidenceCount
    }

    private enum CodingKeys: String, CodingKey {
        case mode, riskLevel, topIssue, evidence, confidence, nextAction
        case area, status, impact, suggestedAction, verifiedBy
        case lastObservedAt, estimatedEffortMinutes, priority
        case blockedBy, recentActivity, linkedJournalCount, linkedNotesCount
        case linkedEvidenceCount
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        mode = try c.decode(String.self, forKey: .mode)
        riskLevel = try c.decode(RiskLevel.self, forKey: .riskLevel)
        topIssue = try c.decode(String.self, forKey: .topIssue)
        evidence = try c.decode(String.self, forKey: .evidence)
        confidence = try c.decode(EvidenceClassification.self, forKey: .confidence)
        nextAction = try c.decode(String.self, forKey: .nextAction)
        area = try c.decodeIfPresent(String.self, forKey: .area) ?? ""
        status = try c.decodeIfPresent(String.self, forKey: .status) ?? ""
        impact = try c.decodeIfPresent(String.self, forKey: .impact) ?? ""
        suggestedAction = try c.decodeIfPresent(String.self, forKey: .suggestedAction) ?? ""
        verifiedBy = try c.decodeIfPresent(String.self, forKey: .verifiedBy) ?? ""
        lastObservedAt = try c.decodeIfPresent(Date.self, forKey: .lastObservedAt)
        estimatedEffortMinutes = try c.decodeIfPresent(Int.self, forKey: .estimatedEffortMinutes) ?? 0
        priority = try c.decodeIfPresent(VerificationPriority.self, forKey: .priority)
        blockedBy = try c.decodeIfPresent([String].self, forKey: .blockedBy) ?? []
        recentActivity = try c.decodeIfPresent([String].self, forKey: .recentActivity) ?? []
        linkedJournalCount = try c.decodeIfPresent(Int.self, forKey: .linkedJournalCount) ?? 0
        linkedNotesCount = try c.decodeIfPresent(Int.self, forKey: .linkedNotesCount) ?? 0
        linkedEvidenceCount = try c.decodeIfPresent(Int.self, forKey: .linkedEvidenceCount) ?? 0
    }
}

public struct CommandSafetyAssessment: Codable, Hashable, Sendable {
    public var command: String
    public var disposition: CommandDisposition
    public var reason: String

    public init(command: String, disposition: CommandDisposition, reason: String) {
        self.command = command
        self.disposition = disposition
        self.reason = reason
    }
}
