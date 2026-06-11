import Foundation

/// A read-only snapshot of a repository's Git state. Every field comes from
/// allowed read-only Git commands (status, rev-parse, log, rev-list). LocalForge
/// never runs a mutating Git command in V1.
public struct GitStatus: Codable, Hashable, Sendable {
    public var isRepository: Bool
    public var branch: String?
    public var isDetached: Bool
    public var stagedCount: Int
    public var unstagedCount: Int
    public var untrackedCount: Int
    public var ahead: Int
    public var behind: Int
    public var hasUpstream: Bool
    public var lastCommitShortHash: String?
    public var lastCommitSubject: String?
    public var lastCommitAuthor: String?
    public var lastCommitRelative: String?
    public var note: String?

    public init(
        isRepository: Bool = false,
        branch: String? = nil,
        isDetached: Bool = false,
        stagedCount: Int = 0,
        unstagedCount: Int = 0,
        untrackedCount: Int = 0,
        ahead: Int = 0,
        behind: Int = 0,
        hasUpstream: Bool = false,
        lastCommitShortHash: String? = nil,
        lastCommitSubject: String? = nil,
        lastCommitAuthor: String? = nil,
        lastCommitRelative: String? = nil,
        note: String? = nil
    ) {
        self.isRepository = isRepository
        self.branch = branch
        self.isDetached = isDetached
        self.stagedCount = stagedCount
        self.unstagedCount = unstagedCount
        self.untrackedCount = untrackedCount
        self.ahead = ahead
        self.behind = behind
        self.hasUpstream = hasUpstream
        self.lastCommitShortHash = lastCommitShortHash
        self.lastCommitSubject = lastCommitSubject
        self.lastCommitAuthor = lastCommitAuthor
        self.lastCommitRelative = lastCommitRelative
        self.note = note
    }

    public static let unknown = GitStatus()

    public var totalChanges: Int { stagedCount + unstagedCount + untrackedCount }
    public var isClean: Bool { totalChanges == 0 }

    public var branchDisplay: String {
        if isDetached { return "detached HEAD" }
        return branch ?? "unknown"
    }

    public var workingTreeSummary: String {
        guard isRepository else { return "Not a Git repository" }
        if isClean { return "Clean working tree" }
        var parts: [String] = []
        if stagedCount > 0 { parts.append("\(stagedCount) staged") }
        if unstagedCount > 0 { parts.append("\(unstagedCount) modified") }
        if untrackedCount > 0 { parts.append("\(untrackedCount) untracked") }
        return parts.joined(separator: ", ")
    }
}
