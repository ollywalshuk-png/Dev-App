import Foundation

public struct ProjectContext: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var rootURL: URL
    public var permission: PermissionGrant
    public var scanPolicy: ScanPolicy
    public var bookmarkStatus: BookmarkAccessState

    public init(
        id: UUID = UUID(),
        name: String,
        rootURL: URL,
        permission: PermissionGrant,
        scanPolicy: ScanPolicy = .balanced,
        bookmarkStatus: BookmarkAccessState = .notPersisted
    ) {
        self.id = id
        self.name = name
        self.rootURL = rootURL
        self.permission = permission
        self.scanPolicy = scanPolicy
        self.bookmarkStatus = bookmarkStatus
    }
}

public enum PermissionState: String, Codable, Sendable {
    case approved = "Approved"
    case missing = "Missing"
    case revoked = "Revoked"
    case unavailable = "Unavailable"
}

public enum PermissionGrant: Codable, Hashable, Sendable {
    case approved(scopeDescription: String)
    case missing
    case revoked
    case unavailable(reason: String)

    public var state: PermissionState {
        switch self {
        case .approved: .approved
        case .missing: .missing
        case .revoked: .revoked
        case .unavailable: .unavailable
        }
    }

    public var description: String {
        switch self {
        case .approved(let scope): "Approved: \(scope)"
        case .missing: "No folder approved"
        case .revoked: "Access revoked"
        case .unavailable(let reason): "Unavailable: \(reason)"
        }
    }
}

public enum BookmarkAccessState: Codable, Hashable, Sendable {
    case notPersisted
    case saved
    case active
    case stale
    case missing
    case failed(reason: String)

    public var displayName: String {
        switch self {
        case .notPersisted: "Session Only"
        case .saved: "Bookmark Saved"
        case .active: "Bookmark Active"
        case .stale: "Bookmark Stale"
        case .missing: "Bookmark Missing"
        case .failed: "Bookmark Failed"
        }
    }

    public var requiresAttention: Bool {
        switch self {
        case .notPersisted, .stale, .missing, .failed:
            true
        case .saved, .active:
            false
        }
    }

    public var isFailure: Bool {
        if case .failed = self { return true }
        return false
    }
}

public enum ScanMode: String, Codable, CaseIterable, Sendable {
    case eco = "Eco"
    case balanced = "Balanced"
    case activeDebug = "Active Debug"
    case release = "Release"
    case aggressive = "Aggressive"
}

public struct ScanPolicy: Codable, Hashable, Sendable {
    public var mode: ScanMode
    public var debounceSeconds: Int
    public var heavyAuditRequiresManualStart: Bool

    public init(
        mode: ScanMode,
        debounceSeconds: Int,
        heavyAuditRequiresManualStart: Bool
    ) {
        self.mode = mode
        self.debounceSeconds = debounceSeconds
        self.heavyAuditRequiresManualStart = heavyAuditRequiresManualStart
    }

    public static let balanced = ScanPolicy(
        mode: .balanced,
        debounceSeconds: 3,
        heavyAuditRequiresManualStart: true
    )

    public static let `default` = balanced

    public static func defaults(for mode: ScanMode) -> ScanPolicy {
        switch mode {
        case .eco:
            ScanPolicy(mode: .eco, debounceSeconds: 6, heavyAuditRequiresManualStart: true)
        case .balanced:
            .balanced
        case .activeDebug:
            ScanPolicy(mode: .activeDebug, debounceSeconds: 2, heavyAuditRequiresManualStart: true)
        case .release:
            ScanPolicy(mode: .release, debounceSeconds: 3, heavyAuditRequiresManualStart: true)
        case .aggressive:
            ScanPolicy(mode: .aggressive, debounceSeconds: 1, heavyAuditRequiresManualStart: true)
        }
    }

    public var isAggressive: Bool {
        mode == .aggressive
    }

    public var requiresExplicitOptIn: Bool {
        mode == .aggressive
    }
}

public struct WorkspaceGroup: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var projectIDs: [UUID]

    public init(id: UUID = UUID(), name: String, projectIDs: [UUID] = []) {
        self.id = id
        self.name = name
        self.projectIDs = projectIDs
    }
}
