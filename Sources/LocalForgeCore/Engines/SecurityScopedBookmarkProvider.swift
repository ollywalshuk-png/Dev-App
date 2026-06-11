import Foundation

public enum BookmarkAccessError: Error, LocalizedError, Hashable, Sendable {
    case creationFailed(String)
    case resolutionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .creationFailed(let detail):
            "Bookmark creation failed: \(detail)"
        case .resolutionFailed(let detail):
            "Bookmark resolve failed: \(detail)"
        }
    }
}

public struct SecurityScopedBookmarkResolution: Hashable, Sendable {
    public var url: URL
    public var isStale: Bool
    public var didStartSecurityScope: Bool

    public init(url: URL, isStale: Bool, didStartSecurityScope: Bool) {
        self.url = url
        self.isStale = isStale
        self.didStartSecurityScope = didStartSecurityScope
    }
}

public protocol SecurityScopedBookmarkProviding {
    func makeBookmarkData(for url: URL) throws -> Data
    func resolveBookmarkData(_ data: Data) throws -> SecurityScopedBookmarkResolution
    func stopAccessing(_ url: URL)
}

public struct SecurityScopedBookmarkProvider: SecurityScopedBookmarkProviding, Sendable {
    public init() {}

    public func makeBookmarkData(for url: URL) throws -> Data {
        do {
            return try url.bookmarkData(
                options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess],
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } catch {
            throw BookmarkAccessError.creationFailed(error.localizedDescription)
        }
    }

    public func resolveBookmarkData(_ data: Data) throws -> SecurityScopedBookmarkResolution {
        var isStale = false
        do {
            let url = try URL(
                resolvingBookmarkData: data,
                options: [.withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            )
            let didStart = url.startAccessingSecurityScopedResource()
            return SecurityScopedBookmarkResolution(
                url: url,
                isStale: isStale,
                didStartSecurityScope: didStart
            )
        } catch {
            throw BookmarkAccessError.resolutionFailed(error.localizedDescription)
        }
    }

    public func stopAccessing(_ url: URL) {
        url.stopAccessingSecurityScopedResource()
    }
}
