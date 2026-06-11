import Foundation

// MARK: - Command Palette

public enum CommandPaletteItemKind: String, CaseIterable, Hashable, Sendable {
    case project = "Project"
    case verification = "Verification"
    case evidence = "Evidence"
    case risk = "Risk"
    case decision = "Decision"
    case architecture = "Architecture"
    case assumption = "Assumption"
    case journal = "Journal"
    case knowledge = "Knowledge"
    case report = "Report"
    case handoff = "Handoff"
    case action = "Action"

    public var symbolName: String {
        switch self {
        case .project: "folder"
        case .verification: "checkmark.seal"
        case .evidence: "paperclip"
        case .risk: "exclamationmark.shield"
        case .decision: "signpost.right"
        case .architecture: "square.3.layers.3d"
        case .assumption: "questionmark.diamond"
        case .journal: "book.pages"
        case .knowledge: "archivebox"
        case .report: "doc.text"
        case .handoff: "paperplane"
        case .action: "bolt"
        }
    }
}

public struct CommandPaletteItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var kind: CommandPaletteItemKind
    public var title: String
    public var subtitle: String
    public var projectID: UUID?
    public var projectName: String
    public var recordID: UUID?
    public var actionKind: CommandPaletteActionKind?
    public var relevance: Int

    public init(
        id: UUID = UUID(),
        kind: CommandPaletteItemKind,
        title: String,
        subtitle: String = "",
        projectID: UUID? = nil,
        projectName: String = "",
        recordID: UUID? = nil,
        actionKind: CommandPaletteActionKind? = nil,
        relevance: Int = 0
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.subtitle = subtitle
        self.projectID = projectID
        self.projectName = projectName
        self.recordID = recordID
        self.actionKind = actionKind
        self.relevance = relevance
    }
}

public enum CommandPaletteActionKind: String, CaseIterable, Hashable, Sendable {
    case openProject = "Open Project"
    case openVerification = "Open Verification"
    case openEvidence = "Open Evidence"
    case openRisk = "Open Risk"
    case openDecision = "Open Decision"
    case openArchitecture = "Open Architecture"
    case openAssumption = "Open Assumption"
    case openTimeline = "Open Timeline"
    case openReport = "Open Report"
    case generateHandoff = "Generate Handoff"
    case openJournal = "Open Journal"
    case openTruthCentre = "Open Truth Centre"
    case openReleaseReadiness = "Open Release Readiness"
    case openWorkspaceHealth = "Open Workspace Health"
    case openWorkspaceDoctor = "Open Workspace Doctor"
    case openBackupCentre = "Open Backup Centre"
    case openUtilityCentre = "Open Utility Centre"
}

// MARK: - Why Panel

public struct WhyPanelSection: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var items: [WhyPanelRow]

    public init(id: UUID = UUID(), title: String, items: [WhyPanelRow]) {
        self.id = id
        self.title = title
        self.items = items
    }
}

public struct WhyPanelRow: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var label: String
    public var value: String
    public var isPositive: Bool
    public var isNegative: Bool
    public var symbolName: String

    public init(
        id: UUID = UUID(),
        label: String,
        value: String = "",
        isPositive: Bool = false,
        isNegative: Bool = false,
        symbolName: String = "info.circle"
    ) {
        self.id = id
        self.label = label
        self.value = value
        self.isPositive = isPositive
        self.isNegative = isNegative
        self.symbolName = symbolName
    }
}

public struct WhyPanelContent: Hashable, Sendable {
    public var title: String
    public var summary: String
    public var sections: [WhyPanelSection]

    public init(title: String, summary: String, sections: [WhyPanelSection] = []) {
        self.title = title
        self.summary = summary
        self.sections = sections
    }

    public static let empty = WhyPanelContent(title: "", summary: "Nothing selected.")
}

// MARK: - Workspace Health

public enum HealthIssueCategory: String, CaseIterable, Hashable, Sendable {
    case truthDecay = "Truth Decay"
    case evidenceDecay = "Evidence Decay"
    case registerDecay = "Register Decay"
    case assumptionDecay = "Assumption Decay"
    case architectureDrift = "Architecture Drift"
    case dependencyIssues = "Dependency Issues"
}

public enum HealthIssueSeverity: String, Codable, CaseIterable, Hashable, Sendable {
    case critical = "Critical"
    case high = "High"
    case medium = "Medium"
    case low = "Low"

    public var symbolName: String {
        switch self {
        case .critical: "xmark.octagon.fill"
        case .high: "exclamationmark.triangle.fill"
        case .medium: "exclamationmark.circle.fill"
        case .low: "info.circle.fill"
        }
    }
}

public struct WorkspaceHealthIssue: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var category: HealthIssueCategory
    public var severity: HealthIssueSeverity
    public var projectID: UUID
    public var projectName: String
    public var title: String
    public var detail: String
    public var recommendation: String

    public init(
        id: UUID = UUID(),
        category: HealthIssueCategory,
        severity: HealthIssueSeverity,
        projectID: UUID,
        projectName: String,
        title: String,
        detail: String,
        recommendation: String
    ) {
        self.id = id
        self.category = category
        self.severity = severity
        self.projectID = projectID
        self.projectName = projectName
        self.title = title
        self.detail = detail
        self.recommendation = recommendation
    }
}

public struct WorkspaceHealthReport: Hashable, Sendable {
    public var issues: [WorkspaceHealthIssue]
    public var generatedAt: Date

    public init(issues: [WorkspaceHealthIssue] = [], generatedAt: Date = Date()) {
        self.issues = issues
        self.generatedAt = generatedAt
    }

    public var criticalCount: Int { issues.filter { $0.severity == .critical }.count }
    public var highCount: Int { issues.filter { $0.severity == .high }.count }
    public var isEmpty: Bool { issues.isEmpty }

    public func issues(for category: HealthIssueCategory) -> [WorkspaceHealthIssue] {
        issues.filter { $0.category == category }
    }
}

// MARK: - Evidence Conflicts

public struct EvidenceConflict: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var projectID: UUID
    public var projectName: String
    public var area: String
    public var successEvidence: [EvidenceRecord]
    public var failureEvidence: [EvidenceRecord]
    public var explanation: String

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        projectName: String,
        area: String,
        successEvidence: [EvidenceRecord],
        failureEvidence: [EvidenceRecord]
    ) {
        self.id = id
        self.projectID = projectID
        self.projectName = projectName
        self.area = area
        self.successEvidence = successEvidence
        self.failureEvidence = failureEvidence
        self.explanation = "\(successEvidence.count) passing and \(failureEvidence.count) failing evidence record(s) exist for '\(area)'. Confidence is reduced until resolved."
    }
}

// MARK: - Confidence Provenance

public enum ConfidenceSource: String, CaseIterable, Hashable, Sendable {
    case observed = "Observed"
    case measured = "Measured"
    case verified = "Verified"
    case inferred = "Inferred"
    case unknown = "Unknown"

    public var symbolName: String {
        switch self {
        case .observed: "eye"
        case .measured: "chart.bar"
        case .verified: "checkmark.seal"
        case .inferred: "wand.and.stars"
        case .unknown: "questionmark.circle"
        }
    }
}

public struct ConfidenceProvenanceItem: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var source: ConfidenceSource
    public var count: Int
    public var label: String

    public init(id: UUID = UUID(), source: ConfidenceSource, count: Int, label: String) {
        self.id = id
        self.source = source
        self.count = count
        self.label = label
    }
}

public struct ConfidenceProvenance: Hashable, Sendable {
    public var score: Int
    public var label: String
    public var items: [ConfidenceProvenanceItem]

    public init(score: Int, label: String, items: [ConfidenceProvenanceItem] = []) {
        self.score = score
        self.label = label
        self.items = items
    }

    public static let empty = ConfidenceProvenance(score: 0, label: "No data")
}

// MARK: - Release Blocking Chain

public struct ReleaseBlockNode: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var label: String
    public var kind: ReleaseBlockNodeKind
    public var state: String
    public var isBlocking: Bool
    public var children: [ReleaseBlockNode]

    public init(
        id: UUID = UUID(),
        label: String,
        kind: ReleaseBlockNodeKind,
        state: String,
        isBlocking: Bool = false,
        children: [ReleaseBlockNode] = []
    ) {
        self.id = id
        self.label = label
        self.kind = kind
        self.state = state
        self.isBlocking = isBlocking
        self.children = children
    }
}

public enum ReleaseBlockNodeKind: String, Hashable, Sendable {
    case release = "Release"
    case verification = "Verification"
    case risk = "Risk"
    case dependency = "Dependency"
}

// MARK: - Saved Views

public enum SavedViewKind: String, Codable, CaseIterable, Hashable, Sendable {
    case myBlockers = "My Blockers"
    case openRisks = "Open Risks"
    case releaseRisks = "Release Risks"
    case staleVerification = "Stale Verification"
    case architectureReview = "Architecture Review"
    case recentEvidence = "Recent Evidence"
    case criticalAssumptions = "Critical Assumptions"
    case pinnedIssues = "Pinned Issues"
    case custom = "Custom"
}

public struct SavedView: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: SavedViewKind
    public var name: String
    public var filterJSON: String
    public var createdAt: Date
    public var isPinned: Bool

    public init(
        id: UUID = UUID(),
        kind: SavedViewKind,
        name: String,
        filterJSON: String = "",
        createdAt: Date = Date(),
        isPinned: Bool = false
    ) {
        self.id = id
        self.kind = kind
        self.name = name
        self.filterJSON = filterJSON
        self.createdAt = createdAt
        self.isPinned = isPinned
    }
}

// MARK: - Pinned Items

public enum PinnedItemKind: String, Codable, CaseIterable, Hashable, Sendable {
    case project = "Project"
    case evidence = "Evidence"
    case risk = "Risk"
    case decision = "Decision"
    case architecture = "Architecture"
}

public struct PinnedItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var kind: PinnedItemKind
    public var recordID: UUID
    public var projectID: UUID
    public var label: String
    public var pinnedAt: Date

    public init(
        id: UUID = UUID(),
        kind: PinnedItemKind,
        recordID: UUID,
        projectID: UUID,
        label: String,
        pinnedAt: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.recordID = recordID
        self.projectID = projectID
        self.label = label
        self.pinnedAt = pinnedAt
    }
}

// MARK: - Workspace Doctor

public enum DoctorIssueKind: String, CaseIterable, Hashable, Sendable {
    case brokenLink = "Broken Link"
    case orphanEvidence = "Orphan Evidence"
    case orphanRisk = "Orphan Risk"
    case invalidDate = "Invalid Date"
    case missingReference = "Missing Reference"
    case duplicateRecord = "Duplicate Record"
    case corruptRelationship = "Corrupt Relationship"
    case brokenDependencyChain = "Broken Dependency Chain"
    case missingAttachment = "Missing Attachment"
    case invalidEnumValue = "Invalid Enum Value"
}

public struct WorkspaceDoctorIssue: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var kind: DoctorIssueKind
    public var severity: HealthIssueSeverity
    public var projectID: UUID
    public var projectName: String
    public var title: String
    public var impact: String
    public var recommendation: String

    public init(
        id: UUID = UUID(),
        kind: DoctorIssueKind,
        severity: HealthIssueSeverity,
        projectID: UUID,
        projectName: String,
        title: String,
        impact: String,
        recommendation: String
    ) {
        self.id = id
        self.kind = kind
        self.severity = severity
        self.projectID = projectID
        self.projectName = projectName
        self.title = title
        self.impact = impact
        self.recommendation = recommendation
    }
}

public struct WorkspaceDoctorReport: Hashable, Sendable {
    public var issues: [WorkspaceDoctorIssue]
    public var checkedAt: Date
    public var projectsChecked: Int

    public init(issues: [WorkspaceDoctorIssue] = [], checkedAt: Date = Date(), projectsChecked: Int = 0) {
        self.issues = issues
        self.checkedAt = checkedAt
        self.projectsChecked = projectsChecked
    }

    public var isEmpty: Bool { issues.isEmpty }
    public var criticalCount: Int { issues.filter { $0.severity == .critical }.count }
}

// MARK: - Project Review Mode

public struct ProjectReviewQuestion: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var question: String
    public var answer: String
    public var isAnswered: Bool

    public init(id: UUID = UUID(), question: String, answer: String = "", isAnswered: Bool = false) {
        self.id = id
        self.question = question
        self.answer = answer
        self.isAnswered = isAnswered
    }
}

public struct ProjectReviewSession: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var projectID: UUID
    public var startedAt: Date
    public var completedAt: Date?
    public var questions: [ProjectReviewQuestion]
    public var generatedJournalEntries: [UUID]

    public init(
        id: UUID = UUID(),
        projectID: UUID,
        startedAt: Date = Date(),
        completedAt: Date? = nil,
        questions: [ProjectReviewQuestion] = [],
        generatedJournalEntries: [UUID] = []
    ) {
        self.id = id
        self.projectID = projectID
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.questions = questions
        self.generatedJournalEntries = generatedJournalEntries
    }

    private enum CodingKeys: String, CodingKey {
        case id, projectID, startedAt, completedAt, generatedJournalEntries
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        projectID = try c.decode(UUID.self, forKey: .projectID)
        startedAt = try c.decodeIfPresent(Date.self, forKey: .startedAt) ?? Date()
        completedAt = try c.decodeIfPresent(Date.self, forKey: .completedAt)
        generatedJournalEntries = try c.decodeIfPresent([UUID].self, forKey: .generatedJournalEntries) ?? []
        questions = []
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(projectID, forKey: .projectID)
        try c.encode(startedAt, forKey: .startedAt)
        try c.encodeIfPresent(completedAt, forKey: .completedAt)
        try c.encode(generatedJournalEntries, forKey: .generatedJournalEntries)
    }
}

// MARK: - Phase 9 Foundation: Build History

public enum BuildType: String, Codable, CaseIterable, Hashable, Sendable {
    case swiftBuild = "swift build"
    case swiftTest = "swift test"
    case xcodeBuild = "xcodebuild"
    case auVal = "auval"
    case custom = "Custom"
}

public enum BuildResult: String, Codable, CaseIterable, Hashable, Sendable {
    case success = "Success"
    case failure = "Failure"
    case warning = "Warning"
    case cancelled = "Cancelled"
    case unknown = "Unknown"

    public var symbolName: String {
        switch self {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .warning: "exclamationmark.triangle.fill"
        case .cancelled: "slash.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }
}

public struct BuildRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var buildType: BuildType
    public var startTime: Date
    public var endTime: Date?
    public var result: BuildResult
    public var environment: String
    public var notes: String
    public var linkedEvidenceIDs: [UUID]
    public var linkedVerificationAreas: [String]

    public init(
        id: UUID = UUID(),
        buildType: BuildType,
        startTime: Date = Date(),
        endTime: Date? = nil,
        result: BuildResult = .unknown,
        environment: String = "",
        notes: String = "",
        linkedEvidenceIDs: [UUID] = [],
        linkedVerificationAreas: [String] = []
    ) {
        self.id = id
        self.buildType = buildType
        self.startTime = startTime
        self.endTime = endTime
        self.result = result
        self.environment = environment
        self.notes = notes
        self.linkedEvidenceIDs = linkedEvidenceIDs
        self.linkedVerificationAreas = linkedVerificationAreas
    }

    public var duration: TimeInterval? {
        guard let end = endTime else { return nil }
        return end.timeIntervalSince(startTime)
    }

    public var durationDisplay: String {
        guard let d = duration else { return "—" }
        if d < 60 { return "\(Int(d))s" }
        return "\(Int(d / 60))m \(Int(d.truncatingRemainder(dividingBy: 60)))s"
    }

    private enum CodingKeys: String, CodingKey {
        case id, buildType, startTime, endTime, result, environment, notes, linkedEvidenceIDs, linkedVerificationAreas
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        buildType = try c.decodeIfPresent(BuildType.self, forKey: .buildType) ?? .swiftBuild
        startTime = try c.decodeIfPresent(Date.self, forKey: .startTime) ?? Date()
        endTime = try c.decodeIfPresent(Date.self, forKey: .endTime)
        result = try c.decodeIfPresent(BuildResult.self, forKey: .result) ?? .unknown
        environment = try c.decodeIfPresent(String.self, forKey: .environment) ?? ""
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        linkedEvidenceIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedEvidenceIDs) ?? []
        linkedVerificationAreas = try c.decodeIfPresent([String].self, forKey: .linkedVerificationAreas) ?? []
    }
}

// MARK: - Phase 9 Foundation: Environment Registry

public struct EnvironmentSnapshot: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var macOSVersion: String
    public var xcodeVersion: String
    public var swiftVersion: String
    public var sdkVersion: String
    public var auValVersion: String
    public var capturedAt: Date
    public var notes: String

    public init(
        id: UUID = UUID(),
        macOSVersion: String = "",
        xcodeVersion: String = "",
        swiftVersion: String = "",
        sdkVersion: String = "",
        auValVersion: String = "",
        capturedAt: Date = Date(),
        notes: String = ""
    ) {
        self.id = id
        self.macOSVersion = macOSVersion
        self.xcodeVersion = xcodeVersion
        self.swiftVersion = swiftVersion
        self.sdkVersion = sdkVersion
        self.auValVersion = auValVersion
        self.capturedAt = capturedAt
        self.notes = notes
    }

    private enum CodingKeys: String, CodingKey {
        case id, macOSVersion, xcodeVersion, swiftVersion, sdkVersion, auValVersion, capturedAt, notes
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        macOSVersion = try c.decodeIfPresent(String.self, forKey: .macOSVersion) ?? ""
        xcodeVersion = try c.decodeIfPresent(String.self, forKey: .xcodeVersion) ?? ""
        swiftVersion = try c.decodeIfPresent(String.self, forKey: .swiftVersion) ?? ""
        sdkVersion = try c.decodeIfPresent(String.self, forKey: .sdkVersion) ?? ""
        auValVersion = try c.decodeIfPresent(String.self, forKey: .auValVersion) ?? ""
        capturedAt = try c.decodeIfPresent(Date.self, forKey: .capturedAt) ?? Date()
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
    }
}

public struct EnvironmentSnapshotDiff: Identifiable, Hashable, Sendable {
    public var id: String { field }
    public var field: String
    public var previousValue: String
    public var currentValue: String

    public init(field: String, previousValue: String, currentValue: String) {
        self.field = field
        self.previousValue = previousValue
        self.currentValue = currentValue
    }

    public var changed: Bool { previousValue != currentValue }
}

public extension EnvironmentSnapshot {
    func comparison(to previous: EnvironmentSnapshot) -> [EnvironmentSnapshotDiff] {
        [
            EnvironmentSnapshotDiff(field: "macOS", previousValue: previous.macOSVersion, currentValue: macOSVersion),
            EnvironmentSnapshotDiff(field: "Xcode", previousValue: previous.xcodeVersion, currentValue: xcodeVersion),
            EnvironmentSnapshotDiff(field: "Swift", previousValue: previous.swiftVersion, currentValue: swiftVersion),
            EnvironmentSnapshotDiff(field: "SDK", previousValue: previous.sdkVersion, currentValue: sdkVersion),
            EnvironmentSnapshotDiff(field: "auval", previousValue: previous.auValVersion, currentValue: auValVersion),
        ]
    }

    var summaryLines: [String] {
        [
            "macOS: \(macOSVersion.isEmpty ? "Unknown" : macOSVersion)",
            "Xcode: \(xcodeVersion.isEmpty ? "Unknown" : xcodeVersion)",
            "Swift: \(swiftVersion.isEmpty ? "Unknown" : swiftVersion)",
            "SDK: \(sdkVersion.isEmpty ? "Unknown" : sdkVersion)",
            "auval: \(auValVersion.isEmpty ? "Unknown" : auValVersion)",
        ]
    }
}

// MARK: - Phase 9 Foundation: Test Registry

public enum TestKind: String, Codable, CaseIterable, Hashable, Sendable {
    case manual = "Manual"
    case automated = "Automated"
    case integration = "Integration"
    case regression = "Regression"
    case hostTest = "Host Test"
}

public enum TestOutcome: String, Codable, CaseIterable, Hashable, Sendable {
    case passed = "Passed"
    case failed = "Failed"
    case blocked = "Blocked"
    case skipped = "Skipped"
    case unknown = "Unknown"

    public var symbolName: String {
        switch self {
        case .passed: "checkmark.circle.fill"
        case .failed: "xmark.circle.fill"
        case .blocked: "hand.raised.circle.fill"
        case .skipped: "minus.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    public var releaseReadinessImpact: String {
        switch self {
        case .passed:
            "Supports release confidence"
        case .failed:
            "Blocks release until resolved"
        case .blocked:
            "Blocks release evidence"
        case .skipped:
            "Not counted as verification"
        case .unknown:
            "Needs verification"
        }
    }
}

public struct TestRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var kind: TestKind
    public var outcome: TestOutcome
    public var linkedVerificationArea: String
    public var linkedEvidenceIDs: [UUID]
    public var notes: String
    public var testedAt: Date
    public var author: String

    public init(
        id: UUID = UUID(),
        name: String,
        kind: TestKind = .manual,
        outcome: TestOutcome = .unknown,
        linkedVerificationArea: String = "",
        linkedEvidenceIDs: [UUID] = [],
        notes: String = "",
        testedAt: Date = Date(),
        author: String = ""
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.outcome = outcome
        self.linkedVerificationArea = linkedVerificationArea
        self.linkedEvidenceIDs = linkedEvidenceIDs
        self.notes = notes
        self.testedAt = testedAt
        self.author = author
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, kind, outcome, linkedVerificationArea, linkedEvidenceIDs, notes, testedAt, author
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        kind = try c.decodeIfPresent(TestKind.self, forKey: .kind) ?? .manual
        outcome = try c.decodeIfPresent(TestOutcome.self, forKey: .outcome) ?? .unknown
        linkedVerificationArea = try c.decodeIfPresent(String.self, forKey: .linkedVerificationArea) ?? ""
        linkedEvidenceIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedEvidenceIDs) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        testedAt = try c.decodeIfPresent(Date.self, forKey: .testedAt) ?? Date()
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
    }
}

// MARK: - Utility Centre

public enum SecurityToolKind: String, CaseIterable, Hashable, Sendable {
    case quarantineInspector = "Quarantine Inspector"
    case removeQuarantine = "Remove Quarantine"
    case gatekeeperCheck = "Gatekeeper Check"
    case signatureInspector = "Signature Inspector"
    case signatureVerification = "Signature Verification"
    case entitlementViewer = "Entitlement Viewer"
    case notarisationCheck = "Notarisation Check"
}

public enum BuildUtilityKind: String, CaseIterable, Hashable, Sendable {
    case derivedDataManager = "DerivedData Manager"
    case buildCleaner = "Build Cleaner"
    case buildLogViewer = "Build Log Viewer"
    case buildSummary = "Build Summary"
    case bundleInspector = "Bundle Inspector"
}

public enum RepoUtilityKind: String, CaseIterable, Hashable, Sendable {
    case gitHealth = "Git Health"
    case largeFileFinder = "Large File Finder"
    case duplicateAssetFinder = "Duplicate Asset Finder"
    case emptyFolderFinder = "Empty Folder Finder"
}

public struct UtilityResult: Identifiable, Hashable, Sendable {
    public let id: UUID
    public var title: String
    public var status: UtilityCentreEngine.Status
    public var output: String
    public var command: String
    public var target: String
    public var interpretation: String
    public var nextAction: String
    public var generatedAt: Date

    public init(
        id: UUID = UUID(),
        title: String,
        status: UtilityCentreEngine.Status = .info,
        output: String,
        command: String = "",
        target: String = "",
        interpretation: String = "",
        nextAction: String = "",
        generatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.status = status
        self.output = output
        self.command = command
        self.target = target
        self.interpretation = interpretation
        self.nextAction = nextAction
        self.generatedAt = generatedAt
    }

    /// Back-compat for callers using the old `isSuccess` flag.
    public var isSuccess: Bool {
        switch status {
        case .success, .info: true
        case .warning, .failure, .targetError, .timeout, .blocked: false
        }
    }
}

// MARK: - Backup

public struct BackupRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var filename: String
    public var createdAt: Date
    public var sizeBytes: Int64
    public var note: String

    public init(
        id: UUID = UUID(),
        filename: String,
        createdAt: Date = Date(),
        sizeBytes: Int64 = 0,
        note: String = ""
    ) {
        self.id = id
        self.filename = filename
        self.createdAt = createdAt
        self.sizeBytes = sizeBytes
        self.note = note
    }

    public var sizeDisplay: String {
        if sizeBytes < 1024 { return "\(sizeBytes) B" }
        if sizeBytes < 1024 * 1024 { return String(format: "%.1f KB", Double(sizeBytes) / 1024) }
        return String(format: "%.1f MB", Double(sizeBytes) / (1024 * 1024))
    }
}
