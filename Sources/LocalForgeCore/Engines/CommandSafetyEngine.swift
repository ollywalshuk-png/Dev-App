import Foundation

public struct CommandSafetyEngine: Sendable {
    public init() {}

    public func assess(_ command: String) -> CommandSafetyAssessment {
        let normalized = command.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = normalized.lowercased()

        if isExfiltrationPattern(lowered) {
            return CommandSafetyAssessment(
                command: command,
                disposition: .blocked,
                reason: "Commands that expose local command output, environment variables, or credential stores to shell pipelines or network sinks are blocked in V1. LocalForge can provide a preview only."
            )
        }

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

        if isChainedShell(lowered) {
            let segments = shellControlSegments(in: lowered)

            if segments.contains(where: { isDestructiveShell($0) || isMutatingGit($0) || isExfiltrationPattern($0) }) {
                return CommandSafetyAssessment(
                    command: command,
                    disposition: .blocked,
                    reason: "Chained command includes a destructive shell, credential exposure, or mutating Git operation. V1 is read-only and must not execute it."
                )
            }

            if segments.allSatisfy({ isReadOnlyGit($0) || isReadOnlyDiagnostic($0) }) {
                return CommandSafetyAssessment(
                    command: command,
                    disposition: .allowedReadOnly,
                    reason: "Allowed read-only diagnostic command."
                )
            }

            return CommandSafetyAssessment(
                command: command,
                disposition: .previewOnly,
                reason: "Chained shell commands need manual review before LocalForge can classify them as read-only. Show as a preview."
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

    private func isExfiltrationPattern(_ command: String) -> Bool {
        if isDirectCredentialDisclosure(command) {
            return true
        }

        if isPipedToNetworkSink(command) {
            return true
        }

        return containsCredentialSource(command) && containsNetworkSink(command)
    }

    private func isDirectCredentialDisclosure(_ command: String) -> Bool {
        if command.contains("security find-generic-password") && command.contains(" -w") {
            return true
        }

        if command.contains("security find-internet-password") && command.contains(" -w") {
            return true
        }

        guard containsCredentialPath(command) else {
            return false
        }

        return ["cat", "less", "more", "head", "tail", "sed", "awk", "grep", "rg"].contains {
            containsShellCommand($0, in: command)
        }
    }

    private func containsCredentialSource(_ command: String) -> Bool {
        containsShellCommand("env", in: command)
            || containsShellCommand("printenv", in: command)
            || containsShellCommand("set", in: command)
            || command.contains("export -p")
            || command.contains("security find-generic-password")
            || command.contains("security find-internet-password")
            || containsCredentialPath(command)
    }

    private func containsNetworkSink(_ command: String) -> Bool {
        ["curl", "wget", "nc", "netcat", "scp", "rsync", "ftp", "sftp"].contains {
            containsShellCommand($0, in: command)
        }
    }

    private func isPipedToNetworkSink(_ command: String) -> Bool {
        ["curl", "wget", "nc", "netcat", "scp", "rsync", "ftp", "sftp"].contains {
            command.contains("| \($0) ")
                || command.hasSuffix("| \($0)")
                || command.contains("|\($0) ")
                || command.hasSuffix("|\($0)")
                || command.contains("| sudo \($0) ")
                || command.hasSuffix("| sudo \($0)")
        }
    }

    private func containsCredentialPath(_ command: String) -> Bool {
        [
            "~/.ssh/",
            "/.ssh/",
            "~/.aws/credentials",
            "/.aws/credentials",
            "~/.gnupg/",
            "/.gnupg/",
            "~/.netrc",
            "/.netrc",
            "~/.npmrc",
            "/.npmrc",
            "~/.pypirc",
            "/.pypirc"
        ].contains { command.contains($0) }
    }

    private func containsShellCommand(_ executable: String, in command: String) -> Bool {
        command == executable
            || command.hasPrefix("\(executable) ")
            || command.hasPrefix("sudo \(executable) ")
            || [" ", ";", "|", "&&", "||", "\n"].contains { separator in
                command.contains("\(separator)\(executable) ")
                    || command.contains("\(separator) sudo \(executable) ")
                    || command.hasSuffix("\(separator)\(executable)")
                    || command.hasSuffix("\(separator)sudo \(executable)")
            }
    }

    private func isChainedShell(_ command: String) -> Bool {
        command.contains("&&")
            || command.contains("||")
            || command.contains(";")
            || command.contains("\n")
    }

    private func shellControlSegments(in command: String) -> [String] {
        var segments: [String] = []
        var current = ""
        var index = command.startIndex

        while index < command.endIndex {
            let character = command[index]

            if character == ";" || character == "\n" {
                appendSegment(current, to: &segments)
                current = ""
                index = command.index(after: index)
                continue
            }

            let next = command.index(after: index)
            if next < command.endIndex {
                let pair = String(command[index...next])
                if pair == "&&" || pair == "||" {
                    appendSegment(current, to: &segments)
                    current = ""
                    index = command.index(after: next)
                    continue
                }
            }

            current.append(character)
            index = command.index(after: index)
        }

        appendSegment(current, to: &segments)
        return segments
    }

    private func appendSegment(_ segment: String, to segments: inout [String]) {
        let trimmed = segment.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            segments.append(trimmed)
        }
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
