import Foundation

/// Runs allowed read-only Git commands against an approved repository and
/// returns a structured snapshot. No mutating command is ever invoked.
///
/// Note: this launches the `git` subprocess. The unsandboxed V1 build allows
/// this. A future App Store (sandboxed) build would need an alternative path;
/// callers degrade gracefully when `git` is unavailable.
public struct GitEngine: Sendable {
    public init() {}

    private static let candidateExecutables = [
        "/usr/bin/git",
        "/opt/homebrew/bin/git",
        "/usr/local/bin/git"
    ]

    public func status(at rootURL: URL) -> GitStatus {
        guard let gitPath = Self.candidateExecutables.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else {
            return GitStatus(isRepository: false, note: "git executable was not found on this system.")
        }

        guard let insideWorkTree = run(gitPath, ["-C", rootURL.path, "rev-parse", "--is-inside-work-tree"]),
              insideWorkTree.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
            return GitStatus(isRepository: false)
        }

        var status = GitStatus(isRepository: true)

        // Branch / detached HEAD.
        if let branch = run(gitPath, ["-C", rootURL.path, "rev-parse", "--abbrev-ref", "HEAD"])?
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            if branch == "HEAD" {
                status.isDetached = true
            } else {
                status.branch = branch
            }
        } else if let unborn = run(gitPath, ["-C", rootURL.path, "symbolic-ref", "--short", "HEAD"])?
            .trimmingCharacters(in: .whitespacesAndNewlines), !unborn.isEmpty {
            // Repository exists but has no commits yet (unborn branch).
            status.branch = unborn
            status.note = "Branch has no commits yet."
        }

        // Working tree state.
        if let porcelain = run(gitPath, ["-C", rootURL.path, "status", "--porcelain=v1"]) {
            for line in porcelain.split(separator: "\n", omittingEmptySubsequences: true) {
                let entry = String(line)
                guard entry.count >= 2 else { continue }
                let indexState = entry[entry.startIndex]
                let workTreeState = entry[entry.index(after: entry.startIndex)]
                if indexState == "?" && workTreeState == "?" {
                    status.untrackedCount += 1
                    continue
                }
                if indexState != " " { status.stagedCount += 1 }
                if workTreeState != " " { status.unstagedCount += 1 }
            }
        }

        // Ahead / behind versus upstream.
        if let counts = run(gitPath, ["-C", rootURL.path, "rev-list", "--left-right", "--count", "HEAD...@{upstream}"]) {
            let parts = counts.split(whereSeparator: { $0 == "\t" || $0 == " " }).compactMap { Int($0) }
            if parts.count == 2 {
                status.hasUpstream = true
                status.ahead = parts[0]
                status.behind = parts[1]
            }
        }

        // Last commit.
        if let log = run(gitPath, ["-C", rootURL.path, "log", "-1", "--format=%h%x1f%an%x1f%ar%x1f%s"]) {
            let fields = log.trimmingCharacters(in: .whitespacesAndNewlines).components(separatedBy: "\u{1f}")
            if fields.count == 4 {
                status.lastCommitShortHash = fields[0]
                status.lastCommitAuthor = fields[1]
                status.lastCommitRelative = fields[2]
                status.lastCommitSubject = fields[3]
            }
        }

        return status
    }

    /// Executes git with explicit arguments (no shell). Returns stdout, or nil on
    /// failure. Both pipes are drained on background queues to avoid a pipe-buffer
    /// deadlock, and a watchdog terminates any command that runs too long so a
    /// scan can never hang on Git.
    private func run(_ executable: String, _ arguments: [String], timeout: TimeInterval = 8) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        // Keep Git non-interactive: never prompt for credentials or open a pager.
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_PAGER"] = "cat"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        // Drain both pipes concurrently; a full stderr buffer must never block stdout.
        let group = DispatchGroup()
        let stdoutBuffer = LockedGitOutput()
        let queue = DispatchQueue(label: "GitEngine.read", attributes: .concurrent)

        do {
            try process.run()
        } catch {
            return nil
        }

        group.enter()
        queue.async {
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            stdoutBuffer.store(data)
            group.leave()
        }
        group.enter()
        queue.async {
            _ = stderr.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        if group.wait(timeout: .now() + timeout) == .timedOut {
            process.terminate()
            return nil
        }
        process.waitUntilExit()

        guard process.terminationStatus == 0 else { return nil }
        return String(data: stdoutBuffer.load(), encoding: .utf8)
    }
}

private final class LockedGitOutput: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func store(_ newValue: Data) {
        lock.lock()
        data = newValue
        lock.unlock()
    }

    func load() -> Data {
        lock.lock()
        defer { lock.unlock() }
        return data
    }
}
