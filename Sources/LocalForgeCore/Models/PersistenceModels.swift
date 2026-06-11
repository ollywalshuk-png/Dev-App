import Foundation

public enum ThemeAppearance: String, Codable, CaseIterable, Hashable, Sendable {
    case system = "System"
    case dark = "Dark"
    case light = "Light"
}

public enum DiagnosticBackgroundIntensity: String, Codable, CaseIterable, Hashable, Sendable {
    case off = "Off"
    case low = "Low"
    case medium = "Medium"
    case high = "High"
}

public enum DiagnosticBackgroundDensity: String, Codable, CaseIterable, Hashable, Sendable {
    case sparse = "Sparse"
    case balanced = "Balanced"
    case dense = "Dense"
}

public enum DiagnosticBackgroundMotion: String, Codable, CaseIterable, Hashable, Sendable {
    case still = "Still"
    case slow = "Slow"
    case medium = "Medium"
}

public struct ThemePreferences: Codable, Hashable, Sendable {
    public var appearance: ThemeAppearance
    public var accentName: String
    public var brightnessAdjustment: Double
    public var animatedDiagnosticBackground: Bool
    public var diagnosticBackgroundIntensity: DiagnosticBackgroundIntensity
    public var diagnosticBackgroundDensity: DiagnosticBackgroundDensity
    public var diagnosticBackgroundMotion: DiagnosticBackgroundMotion
    public var reduceDiagnosticBackgroundWhenInactive: Bool

    public init(
        appearance: ThemeAppearance = .dark,
        accentName: String = "Blue",
        brightnessAdjustment: Double = 0,
        animatedDiagnosticBackground: Bool = true,
        diagnosticBackgroundIntensity: DiagnosticBackgroundIntensity = .medium,
        diagnosticBackgroundDensity: DiagnosticBackgroundDensity = .balanced,
        diagnosticBackgroundMotion: DiagnosticBackgroundMotion = .slow,
        reduceDiagnosticBackgroundWhenInactive: Bool = true
    ) {
        self.appearance = appearance
        self.accentName = accentName
        self.brightnessAdjustment = brightnessAdjustment
        self.animatedDiagnosticBackground = animatedDiagnosticBackground
        self.diagnosticBackgroundIntensity = diagnosticBackgroundIntensity
        self.diagnosticBackgroundDensity = diagnosticBackgroundDensity
        self.diagnosticBackgroundMotion = diagnosticBackgroundMotion
        self.reduceDiagnosticBackgroundWhenInactive = reduceDiagnosticBackgroundWhenInactive
    }

    public static let `default` = ThemePreferences()

    private enum CodingKeys: String, CodingKey {
        case appearance
        case accentName
        case brightnessAdjustment
        case animatedDiagnosticBackground
        case diagnosticBackgroundIntensity
        case diagnosticBackgroundDensity
        case diagnosticBackgroundMotion
        case reduceDiagnosticBackgroundWhenInactive
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        appearance = try c.decodeIfPresent(ThemeAppearance.self, forKey: .appearance) ?? .dark
        accentName = try c.decodeIfPresent(String.self, forKey: .accentName) ?? "Blue"
        brightnessAdjustment = try c.decodeIfPresent(Double.self, forKey: .brightnessAdjustment) ?? 0
        animatedDiagnosticBackground = try c.decodeIfPresent(Bool.self, forKey: .animatedDiagnosticBackground) ?? true
        diagnosticBackgroundIntensity = try c.decodeIfPresent(DiagnosticBackgroundIntensity.self, forKey: .diagnosticBackgroundIntensity) ?? .medium
        diagnosticBackgroundDensity = try c.decodeIfPresent(DiagnosticBackgroundDensity.self, forKey: .diagnosticBackgroundDensity) ?? .balanced
        diagnosticBackgroundMotion = try c.decodeIfPresent(DiagnosticBackgroundMotion.self, forKey: .diagnosticBackgroundMotion) ?? .slow
        reduceDiagnosticBackgroundWhenInactive = try c.decodeIfPresent(Bool.self, forKey: .reduceDiagnosticBackgroundWhenInactive) ?? true
    }
}

public struct WorkspacePersistenceState: Codable, Hashable, Sendable {
    public var projects: [PersistedProjectRecord]
    public var scanMode: ScanMode
    public var theme: ThemePreferences
    public var lastActiveProjectID: UUID?
    // Phase 8.5: workspace-level saved views, pinned items, favourites.
    public var savedViews: [SavedView]
    public var pinnedItems: [PinnedItem]
    public var favoritedProjectIDs: [UUID]

    public init(
        projects: [PersistedProjectRecord] = [],
        scanMode: ScanMode = .balanced,
        theme: ThemePreferences = .default,
        lastActiveProjectID: UUID? = nil,
        savedViews: [SavedView] = [],
        pinnedItems: [PinnedItem] = [],
        favoritedProjectIDs: [UUID] = []
    ) {
        self.projects = projects
        self.scanMode = scanMode
        self.theme = theme
        self.lastActiveProjectID = lastActiveProjectID
        self.savedViews = savedViews
        self.pinnedItems = pinnedItems
        self.favoritedProjectIDs = favoritedProjectIDs
    }

    public static let empty = WorkspacePersistenceState()
}

public struct PersistedProjectRecord: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var fallbackPath: String
    public var bookmarkData: Data?
    public var scanPolicy: ScanPolicy
    public var bookmarkStatus: BookmarkAccessState
    public var createdAt: Date
    public var lastOpenedAt: Date
    // Phase 3: user-entered project understanding. Optional so older saved state
    // (without these keys) still decodes cleanly.
    public var mission: UserMissionProfile?
    public var verification: [VerificationRecord]?
    public var knowledgeNotes: [KnowledgeNote]?
    // Phase 6: append-only project journal — institutional memory.
    public var journal: [JournalEntry]?
    /// Phase 7: evidence records attached to verification areas.
    public var evidence: [EvidenceRecord]?
    // Phase 7 registers — all optional & backward-compatible.
    public var decisions: [DecisionRecord]?
    public var architecture: [ArchitectureItem]?
    public var risks: [RiskRecord]?
    public var assumptions: [AssumptionRecord]?
    // Phase 8.5 / Phase 9 foundations — optional & backward-compatible.
    public var buildHistory: [BuildRecord]?
    public var environments: [EnvironmentSnapshot]?
    public var testRecords: [TestRecord]?
    public var recommendations: [RecommendationRecord]?

    public init(
        id: UUID = UUID(),
        name: String,
        fallbackPath: String,
        bookmarkData: Data?,
        scanPolicy: ScanPolicy,
        bookmarkStatus: BookmarkAccessState,
        createdAt: Date = Date(),
        lastOpenedAt: Date = Date(),
        mission: UserMissionProfile? = nil,
        verification: [VerificationRecord]? = nil,
        knowledgeNotes: [KnowledgeNote]? = nil,
        journal: [JournalEntry]? = nil,
        evidence: [EvidenceRecord]? = nil,
        decisions: [DecisionRecord]? = nil,
        architecture: [ArchitectureItem]? = nil,
        risks: [RiskRecord]? = nil,
        assumptions: [AssumptionRecord]? = nil,
        buildHistory: [BuildRecord]? = nil,
        environments: [EnvironmentSnapshot]? = nil,
        testRecords: [TestRecord]? = nil,
        recommendations: [RecommendationRecord]? = nil
    ) {
        self.id = id
        self.name = name
        self.fallbackPath = fallbackPath
        self.bookmarkData = bookmarkData
        self.scanPolicy = scanPolicy
        self.bookmarkStatus = bookmarkStatus
        self.createdAt = createdAt
        self.lastOpenedAt = lastOpenedAt
        self.mission = mission
        self.verification = verification
        self.knowledgeNotes = knowledgeNotes
        self.journal = journal
        self.evidence = evidence
        self.decisions = decisions
        self.architecture = architecture
        self.risks = risks
        self.assumptions = assumptions
        self.buildHistory = buildHistory
        self.environments = environments
        self.testRecords = testRecords
        self.recommendations = recommendations
    }

    public static func approvedProject(
        id: UUID = UUID(),
        url: URL,
        scanPolicy: ScanPolicy,
        bookmarkProvider: any SecurityScopedBookmarkProviding
    ) throws -> PersistedProjectRecord {
        let bookmarkData = try bookmarkProvider.makeBookmarkData(for: url)
        return PersistedProjectRecord(
            id: id,
            name: url.lastPathComponent.isEmpty ? "Untitled Project" : url.lastPathComponent,
            fallbackPath: url.path,
            bookmarkData: bookmarkData,
            scanPolicy: scanPolicy,
            bookmarkStatus: .saved
        )
    }

    public func resolve(using provider: any SecurityScopedBookmarkProviding) -> ResolvedProjectAccess {
        guard let bookmarkData else {
            let project = ProjectContext(
                id: id,
                name: name,
                rootURL: URL(fileURLWithPath: fallbackPath),
                permission: .missing,
                scanPolicy: scanPolicy,
                bookmarkStatus: .missing
            )
            return ResolvedProjectAccess(
                project: project,
                message: "Saved access is missing. Reopen the repository to restore permission.",
                securityScopeURL: nil
            )
        }

        do {
            let resolution = try provider.resolveBookmarkData(bookmarkData)
            if resolution.isStale {
                if resolution.didStartSecurityScope {
                    provider.stopAccessing(resolution.url)
                }
                let project = ProjectContext(
                    id: id,
                    name: name,
                    rootURL: resolution.url,
                    permission: .unavailable(reason: "Security-scoped bookmark is stale. Reopen the repository."),
                    scanPolicy: scanPolicy,
                    bookmarkStatus: .stale
                )
                return ResolvedProjectAccess(
                    project: project,
                    message: "Saved bookmark for \(name) is stale. Reopen the repository to refresh access.",
                    securityScopeURL: nil
                )
            }

            let status: BookmarkAccessState = resolution.didStartSecurityScope ? .active : .saved
            let project = ProjectContext(
                id: id,
                name: name,
                rootURL: resolution.url,
                permission: .approved(scopeDescription: resolution.didStartSecurityScope ? "Security-scoped bookmark active" : "Saved bookmark resolved"),
                scanPolicy: scanPolicy,
                bookmarkStatus: status
            )
            return ResolvedProjectAccess(
                project: project,
                message: "\(name) access restored from saved bookmark.",
                securityScopeURL: resolution.didStartSecurityScope ? resolution.url : nil
            )
        } catch {
            let project = ProjectContext(
                id: id,
                name: name,
                rootURL: URL(fileURLWithPath: fallbackPath),
                permission: .unavailable(reason: "Saved bookmark could not be resolved. Reopen the repository."),
                scanPolicy: scanPolicy,
                bookmarkStatus: .failed(reason: error.localizedDescription)
            )
            return ResolvedProjectAccess(
                project: project,
                message: "Could not resolve saved bookmark for \(name): \(error.localizedDescription)",
                securityScopeURL: nil
            )
        }
    }
}

public struct ResolvedProjectAccess: Hashable, Sendable {
    public var project: ProjectContext
    public var message: String
    public var securityScopeURL: URL?

    public init(project: ProjectContext, message: String, securityScopeURL: URL?) {
        self.project = project
        self.message = message
        self.securityScopeURL = securityScopeURL
    }
}
