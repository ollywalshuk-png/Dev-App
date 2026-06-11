import Foundation

public enum WorkspacePersistenceError: Error, LocalizedError, Sendable {
    case encodingFailed(String)
    case decodingFailed(String)

    public var errorDescription: String? {
        switch self {
        case .encodingFailed(let detail):
            "Workspace persistence encoding failed: \(detail)"
        case .decodingFailed(let detail):
            "Workspace persistence decoding failed: \(detail)"
        }
    }
}

/// Phase 8: the persistence seam. UserDefaults and SQLite backends both
/// implement this; `WorkspaceStore` only ever sees the protocol.
public protocol WorkspacePersisting: AnyObject {
    func load() throws -> WorkspacePersistenceState
    func save(_ state: WorkspacePersistenceState) throws
    /// Human-readable note from the last load (migration performed, corruption
    /// recovered, fallback used). Nil when the load was uneventful.
    var lastLoadNote: String? { get }
}

public extension WorkspacePersisting {
    var lastLoadNote: String? { nil }
}

public final class WorkspacePersistenceStore: WorkspacePersisting {
    private let defaults: UserDefaults
    private let key: String

    public init(
        defaults: UserDefaults = .standard,
        key: String = "LocalForge.WorkspaceState"
    ) {
        self.defaults = defaults
        self.key = key
    }

    public func load() throws -> WorkspacePersistenceState {
        guard let data = defaults.data(forKey: key) else {
            return .empty
        }

        do {
            return try JSONDecoder().decode(WorkspacePersistenceState.self, from: data)
        } catch {
            throw WorkspacePersistenceError.decodingFailed(error.localizedDescription)
        }
    }

    public func save(_ state: WorkspacePersistenceState) throws {
        do {
            let data = try JSONEncoder().encode(state)
            defaults.set(data, forKey: key)
        } catch {
            throw WorkspacePersistenceError.encodingFailed(error.localizedDescription)
        }
    }
}
