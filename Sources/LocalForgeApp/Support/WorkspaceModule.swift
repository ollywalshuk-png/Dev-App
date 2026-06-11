import Foundation

enum WorkspaceModule: String, CaseIterable, Identifiable {
    // Implemented modules — what the user actually uses.
    case workspace = "Workspace"
    case search = "Search"
    case projects = "Projects"
    case mission = "Mission"
    case verification = "Verification"
    case releaseReadiness = "Release Readiness"
    case timeline = "Timeline"
    case journal = "Project Journal"
    case truthCentre = "Truth Centre"
    case registers = "Registers"
    case knowledgeVault = "Knowledge Vault"
    case reports = "Reports"
    case handoff = "Handoff"
    case cli = "CLI"
    case settings = "Settings"
    // Phase 8.5 modules.
    case workspaceHealth = "Workspace Health"
    case workspaceDoctor = "Workspace Doctor"
    case backupCentre = "Backup Centre"
    case utilityCentre = "Utility Centre"
    case buildHistory = "Build History"
    case devTools = "Dev Tools"
    case recommendations = "Recommendations"
    case testRegistry = "Test Registry"
    case environmentRegistry = "Environment Registry"
    case projectReview = "Project Review"
    case savedViews = "Saved Views"
    // Foundation stubs — surfaced honestly, deferred by design.
    case repoMonitor = "Repo Monitor"
    case buildIntelligence = "Build Intelligence"
    case testing = "Testing"
    case runtime = "Runtime"
    case security = "Security"
    case uiIntelligence = "UI Intelligence"
    case aiIntelligence = "AI Intelligence"

    var id: String { rawValue }

    var isImplemented: Bool {
        switch self {
        case .workspace, .search, .projects, .mission, .verification, .releaseReadiness, .timeline,
             .journal, .truthCentre, .registers, .knowledgeVault, .reports, .handoff, .cli, .settings,
             .workspaceHealth, .workspaceDoctor, .backupCentre, .utilityCentre, .buildHistory,
             .devTools, .recommendations, .testRegistry, .environmentRegistry, .projectReview, .savedViews:
            true
        case .repoMonitor, .buildIntelligence, .testing, .runtime,
             .security, .uiIntelligence, .aiIntelligence:
            false
        }
    }

    var symbolName: String {
        switch self {
        case .workspace: "rectangle.3.group"
        case .search: "magnifyingglass"
        case .projects: "folder"
        case .mission: "scope"
        case .verification: "checkmark.seal"
        case .releaseReadiness: "flag.checkered"
        case .timeline: "timeline.selection"
        case .journal: "book.pages"
        case .truthCentre: "checkmark.shield.fill"
        case .registers: "list.bullet.rectangle"
        case .knowledgeVault: "archivebox"
        case .reports: "doc.text"
        case .handoff: "paperplane"
        case .cli: "terminal"
        case .settings: "gearshape"
        case .workspaceHealth: "heart.text.square"
        case .workspaceDoctor: "stethoscope"
        case .backupCentre: "externaldrive"
        case .utilityCentre: "wrench.and.screwdriver"
        case .buildHistory: "hammer.circle"
        case .devTools: "terminal.fill"
        case .recommendations: "exclamationmark.bubble"
        case .testRegistry: "checklist.checked"
        case .environmentRegistry: "desktopcomputer.and.macbook"
        case .projectReview: "checklist"
        case .savedViews: "bookmark"
        case .repoMonitor: "dot.radiowaves.left.and.right"
        case .buildIntelligence: "hammer"
        case .testing: "testtube.2"
        case .runtime: "gauge.with.dots.needle.bottom.50percent"
        case .security: "lock.shield"
        case .uiIntelligence: "rectangle.on.rectangle"
        case .aiIntelligence: "brain"
        }
    }
}
