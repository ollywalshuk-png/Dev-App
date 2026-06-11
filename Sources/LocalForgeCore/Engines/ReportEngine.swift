import Foundation

public struct ReportEngine: Sendable {
    public init() {}

    public func markdownReport(for snapshot: RepoSnapshot, note: String = "") -> String {
        let redactedNote = redact(note)
        let findings = snapshot.findings.map { finding in
            "- **\(finding.severity.rawValue)** \(finding.title) [\(finding.evidenceClassification.rawValue)]: \(finding.detail)"
        }.joined(separator: "\n")

        let evidence = snapshot.evidence.map { item in
            "- \(item.title) [\(item.classification.rawValue)]: \(item.detail)"
        }.joined(separator: "\n")

        return redact(
            """
            # LocalForge Project Report

            Project: \(snapshot.project.name)
            Root: \(snapshot.project.rootURL.path)
            Detected Type: \(snapshot.identity.kind.rawValue) [\(snapshot.identity.confidence.rawValue)]
            Mission: \(snapshot.mission.statedMission) [\(snapshot.mission.confidence.rawValue)]
            Git: \(gitLine(snapshot.git))
            Scan Mode: \(snapshot.scanPolicy.mode.rawValue)
            Permission: \(snapshot.permissionState.rawValue)
            Read-only: \(snapshot.isReadOnly ? "Yes" : "No")

            ## Reality (\(snapshot.reality.score)% — \(snapshot.reality.currentState))
            Next action: \(snapshot.reality.nextAction)
            Top risks:
            \(bullets(snapshot.reality.topRisks))
            Unverified (in scope):
            \(bullets(snapshot.reality.unverified))
            Assumptions:
            \(bullets(snapshot.reality.assumptions))
            Unknowns:
            \(bullets(snapshot.reality.unknowns))

            ## Applicability
            \(snapshot.applicability.map { "- \($0.area): \($0.status.rawValue)" }.joined(separator: "\n"))

            ## Summary
            Files: \(snapshot.summary.totalFiles)
            Source Files: \(snapshot.summary.sourceFiles)
            Test Files: \(snapshot.summary.testFiles)
            Documentation Files: \(snapshot.summary.documentationFiles)
            Large Files: \(snapshot.summary.largeFiles)

            ## Findings
            \(findings.isEmpty ? "- None observed" : findings)

            ## Evidence
            \(evidence.isEmpty ? "- Unknown" : evidence)

            ## Note
            \(redactedNote.isEmpty ? "No note provided." : redactedNote)
            """
        )
    }

    private func bullets(_ items: [String]) -> String {
        items.isEmpty ? "- None" : items.map { "- \($0)" }.joined(separator: "\n")
    }

    private func gitLine(_ git: GitStatus) -> String {
        guard git.isRepository else { return "Not a Git repository" }
        var line = "branch \(git.branchDisplay), \(git.workingTreeSummary)"
        if git.hasUpstream {
            line += ", \(git.ahead) ahead / \(git.behind) behind"
        }
        return line
    }

    public func redact(_ text: String) -> String {
        var output = text
        let patterns: [(String, String)] = [
            (#"-----BEGIN [A-Z ]*PRIVATE KEY-----[\s\S]*?-----END [A-Z ]*PRIVATE KEY-----"#, "[REDACTED_SECRET]"),
            (#"\bgh[pousr]_[A-Za-z0-9_]{20,}\b"#, "[REDACTED_SECRET]"),
            (#"(?i)\b[A-Z0-9._%+-]*SECRET[A-Z0-9._%+-]*\b"#, "[REDACTED_SECRET]"),
            (#"(?i)\b(token|api[_-]?key|password|secret)\s*[:=]\s*[A-Za-z0-9_\-./+=]{6,}\b"#, "[REDACTED_SECRET]"),
            (#"/Users/[^/\s]+/[^\s)]+"#, "[REDACTED_PRIVATE_PATH]")
        ]

        for (pattern, replacement) in patterns {
            output = output.replacingOccurrences(
                of: pattern,
                with: replacement,
                options: .regularExpression
            )
        }
        return output
    }
}
