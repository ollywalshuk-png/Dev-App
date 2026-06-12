import Foundation

public struct ReportEngine: Sendable {
    public init() {}

    public func markdownReport(for snapshot: RepoSnapshot, note: String = "") -> String {
        let redactedNote = redact(note)
        let findings = snapshot.findings.map { finding in
            "- **\(finding.severity.rawValue)** \(finding.title) [\(finding.evidenceClassification.rawValue)]: \(finding.detail)"
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

            ## Evidence Provenance
            \(provenanceBlock(for: snapshot))

            ## Evidence
            \(evidenceTierBlock(snapshot.evidence))

            ## Assumptions / Inferences
            \(assumptionBlock(for: snapshot))

            ## Stale Records
            \(staleRecordsBlock(snapshot.verification))

            ## Contradictory Evidence
            \(contradictoryEvidenceBlock(snapshot.evidence))

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

    private func provenanceBlock(for snapshot: RepoSnapshot) -> String {
        var counts: [EvidenceClassification: Int] = [:]
        for evidence in snapshot.evidence {
            counts[evidence.classification, default: 0] += 1
        }

        let lines = evidenceClassificationOrder.map { classification in
            "- \(classification.rawValue): \(counts[classification, default: 0]) record(s) — \(explanation(for: classification))"
        }

        let staleCount = staleVerification(snapshot.verification).count
        let contradictionCount = reportConflicts(snapshot.evidence).count
        return (lines + [
            "- Stale verified records: \(staleCount)",
            "- Potential contradictions: \(contradictionCount)",
            "- Scope: local snapshot only; no remote services or private attachments are read for this report."
        ]).joined(separator: "\n")
    }

    private func evidenceTierBlock(_ evidence: [Evidence]) -> String {
        let groups: [(String, [EvidenceClassification])] = [
            ("### Verified Evidence", [.verified]),
            ("### Measured Evidence", [.measured]),
            ("### Observed Evidence", [.observed]),
            ("### Inferred Evidence", [.inferred]),
            ("### Unknown Evidence", [.unknown])
        ]

        let sections = groups.compactMap { title, classifications -> String? in
            let items = evidence.filter { classifications.contains($0.classification) }
            guard !items.isEmpty else { return nil }
            return "\(title)\n\(evidenceBullets(items))"
        }

        return sections.isEmpty ? "- Unknown" : sections.joined(separator: "\n\n")
    }

    private func assumptionBlock(for snapshot: RepoSnapshot) -> String {
        let assumedEvidence = snapshot.evidence.filter { $0.classification == .assumed }
        var lines = snapshot.reality.assumptions.map { "- Assumption: \($0)" }
        lines += assumedEvidence.map { "- Evidence assumption: \($0.title) — \($0.detail)" }
        return lines.isEmpty ? "- None recorded" : lines.joined(separator: "\n")
    }

    private func staleRecordsBlock(_ verification: [VerificationRecord]) -> String {
        let stale = staleVerification(verification)
        guard !stale.isEmpty else { return "- None detected" }

        return stale.map { record in
            let age = record.ageDescription.isEmpty ? record.age.rawValue : "\(record.age.rawValue) · \(record.ageDescription)"
            return "- \(record.area): \(age). Re-verify before treating this as release-grade evidence."
        }.joined(separator: "\n")
    }

    private func contradictoryEvidenceBlock(_ evidence: [Evidence]) -> String {
        let conflicts = reportConflicts(evidence)
        guard !conflicts.isEmpty else { return "- None detected" }

        return conflicts.map { conflict in
            let success = conflict.success.prefix(2).map(\.title).joined(separator: "; ")
            let failure = conflict.failure.prefix(2).map(\.title).joined(separator: "; ")
            return "- \(conflict.source): \(conflict.success.count) passing and \(conflict.failure.count) failing signal(s). Passing: \(success). Failing: \(failure). Resolve before trusting the score."
        }.joined(separator: "\n")
    }

    private func evidenceBullets(_ evidence: [Evidence]) -> String {
        evidence.map { item in
            let source = item.source.trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceSuffix = source.isEmpty ? "" : " · source: \(source)"
            return "- \(item.title) [\(item.classification.rawValue)\(sourceSuffix)]: \(item.detail)"
        }.joined(separator: "\n")
    }

    private var evidenceClassificationOrder: [EvidenceClassification] {
        [.verified, .measured, .observed, .inferred, .assumed, .unknown]
    }

    private func explanation(for classification: EvidenceClassification) -> String {
        switch classification {
        case .verified:
            "explicitly checked by a person or trusted local tool"
        case .measured:
            "numeric or command output captured from the local project"
        case .observed:
            "directly seen during the local scan or user workflow"
        case .inferred:
            "derived from available signals and should be confirmed"
        case .assumed:
            "not proven yet; treated as a trust debt"
        case .unknown:
            "not enough evidence to classify confidently"
        }
    }

    private func staleVerification(_ verification: [VerificationRecord]) -> [VerificationRecord] {
        verification.filter { record in
            record.state == .verified && (record.age == .stale || record.age == .expired)
        }
    }

    private func reportConflicts(_ evidence: [Evidence]) -> [(source: String, success: [Evidence], failure: [Evidence])] {
        let grouped = Dictionary(grouping: evidence) { item in
            let source = item.source.trimmingCharacters(in: .whitespacesAndNewlines)
            return source.isEmpty ? "snapshot" : source
        }

        return grouped.compactMap { source, records in
            let success = records.filter(isSuccessEvidence)
            let failure = records.filter(isFailureEvidence)
            guard !success.isEmpty && !failure.isEmpty else { return nil }
            return (source: source, success: success, failure: failure)
        }
        .sorted { lhs, rhs in
            if lhs.failure.count == rhs.failure.count {
                return lhs.source.localizedCaseInsensitiveCompare(rhs.source) == .orderedAscending
            }
            return lhs.failure.count > rhs.failure.count
        }
    }

    private func isSuccessEvidence(_ evidence: Evidence) -> Bool {
        guard isStrongEvidence(evidence.classification), !isFailureEvidence(evidence) else { return false }
        if evidence.classification == .verified { return true }
        return containsSuccessSignal(in: "\(evidence.title) \(evidence.detail)")
    }

    private func isFailureEvidence(_ evidence: Evidence) -> Bool {
        guard isStrongEvidence(evidence.classification) else { return false }
        return containsFailureSignal(in: "\(evidence.title) \(evidence.detail)")
    }

    private func isStrongEvidence(_ classification: EvidenceClassification) -> Bool {
        classification == .observed || classification == .measured || classification == .verified
    }

    private func containsSuccessSignal(in text: String) -> Bool {
        text.range(
            of: #"(?i)\b(pass(?:ed|es|ing)?|success(?:ful|fully)?|succeeded|works|working|green|clean|accepted|valid(?:ated)?|verified)\b"#,
            options: .regularExpression
        ) != nil
    }

    private func containsFailureSignal(in text: String) -> Bool {
        if text.range(
            of: #"(?i)\b(no|without|zero|0)\s+(fail(?:ed|ing|s|ure|ures)?|error(?:s)?|crash(?:es|ed)?)\b"#,
            options: .regularExpression
        ) != nil {
            return false
        }

        return text.range(
            of: #"(?i)\b(fail(?:ed|ing|s|ure|ures)?|error(?:s)?|broken|crash(?:ed|es)?|timeout|timed out|blocked|regression)\b"#,
            options: .regularExpression
        ) != nil
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
