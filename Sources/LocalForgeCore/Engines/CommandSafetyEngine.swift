import Foundation

public struct CommandSafetyEngine: Sendable {
    public init() {}

    public func assess(_ command: String) -> CommandSafetyAssessment {
        let normalized = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = normalized.lowercased()

        if isDestructiveShell(lowered) {
            return CommandSafetyAssessment(
                command: command,
                disposition: .blocked,
                reason: "Destructive shell commands are blocked in V1. LocalForge can provide a preview only."
            )
        }

        if isMutatingGit(lowered) {
            return CommandSafetyAssessment(
                command: command,
                disposition: .blocked,
                reason: "This is a mutating Git command. V1 is read-only and must not modify repositories."
            )
        }

        if isReadOnlyGit(lowered) || isReadOnlyDiagnostic(lowered) {
            return CommandSafetyAssessment(
                command: command,
                disposition: .allowedReadOnly,
                reason: "Allowed read-only diagnostic command."
            )
        }

        return CommandSafetyAssessment(
            command: command,
            disposition: .previewOnly,
            reason: "Command is not classified as an approved read-only diagnostic. Show as a preview."
        )
    }

    private func isDestructiveShell(_ command: String) -> Bool {
        command.hasPrefix("rm ")
            || command.contains(" rm ")
            || command.contains("rm -rf")
            || command.hasPrefix("sudo rm")
            || command.contains(" sudo rm")
            || command.contains("| sh")
            || command.contains("| bash")
            || command.contains("; sh")
            || command.contains("; bash")
            || command.contains("mkfs")
            || command.contains(":(){")
    }

    private func isMutatingGit(_ command: String) -> Bool {
        let blocked = [
            "git reset", "git clean", "git checkout", "git switch", "git merge",
            "git rebase", "git pull", "git push", "git commit", "git add"
        ]
        return blocked.contains { command.hasPrefix($0) || command.contains(" \($0)") }
    }

    private func isReadOnlyGit(_ command: String) -> Bool {
        let allowed = [
            "git status", "git diff", "git log", "git branch",
            "git rev-parse", "git ls-files"
        ]
        return allowed.contains { command.hasPrefix($0) || command.contains(" \($0)") }
    }

    private func isReadOnlyDiagnostic(_ command: String) -> Bool {
        let allowedPrefixes = [
            "xcodebuild -list",
            "xcodebuild -showbuildsettings",
            "plutil -lint",
            "codesign --verify",
            "codesign -dv",
            "spctl --assess",
            "xcrun stapler validate",
            "auval",
            "du -sh"
        ]
        return allowedPrefixes.contains { command.hasPrefix($0) }
    }
}
