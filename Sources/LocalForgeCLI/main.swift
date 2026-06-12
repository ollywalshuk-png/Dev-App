import Foundation
import LocalForgeCore

@main
struct LocalForgeCLI {
    static func main() async throws {
        var arguments = CommandLine.arguments.dropFirst()
        guard let command = arguments.first else {
            printUsage()
            return
        }
        arguments = arguments.dropFirst()

        switch command {
        case "scan":
            guard let path = arguments.first else {
                print("Missing path")
                printUsage()
                return
            }
            let context = context(for: String(path))
            let snapshot = try await ScannerEngine().scan(context)
            printScanSummary(for: snapshot)

        case "report":
            guard let path = arguments.first else {
                print("Missing path")
                printUsage()
                return
            }
            let context = context(for: String(path))
            let snapshot = try await ScannerEngine().scan(context)
            printMarkdownReport(for: snapshot)

        case "assess-command":
            let commandText = arguments.joined(separator: " ")
            let assessment = CommandSafetyEngine().assess(commandText)
            print("\(assessment.disposition.rawValue): \(assessment.reason)")

        default:
            print("Unknown command: \(command)")
            printUsage()
        }
    }

    private static func printUsage() {
        print(
            """
            LocalForge CLI

            Usage:
              localforge scan <path>
              localforge report <path>
              localforge assess-command <command>

            V1 is read-only and uses the same LocalForgeCore engines as the GUI.
            """
        )
    }

    private static func context(for path: String) -> ProjectContext {
        let url = URL(fileURLWithPath: path)
        return ProjectContext(
            name: url.lastPathComponent,
            rootURL: url,
            permission: .approved(scopeDescription: "CLI explicit path"),
            scanPolicy: .balanced
        )
    }

    private static func printScanSummary(for snapshot: RepoSnapshot) {
        let lines = trustSummaryLines(for: snapshot, includeRedactionBoundary: true)
        let redactor = ReportEngine()
        for line in lines {
            print(redactor.redact(line))
        }
    }

    private static func printMarkdownReport(for snapshot: RepoSnapshot) {
        let reportEngine = ReportEngine()
        let prelude = trustSummaryLines(for: snapshot, includeRedactionBoundary: true)
            .map(reportEngine.redact)
            .joined(separator: "\n")
        let report = reportEngine.markdownReport(for: snapshot)

        print("## CLI Trust Summary")
        print(prelude)
        print("")
        print(report)
    }

    private static func trustSummaryLines(
        for snapshot: RepoSnapshot,
        includeRedactionBoundary: Bool
    ) -> [String] {
        let release = ReleaseReadinessEngine().board(for: snapshot)
        let truthDebt = TruthDebtEngine().report(
            snapshot: snapshot,
            evidence: [],
            risks: [],
            assumptions: []
        )
        var lines = [
            "LocalForge Trust Scan",
            "Project: \(snapshot.project.name)",
            "Type: \(snapshot.identity.kind.rawValue) [\(snapshot.identity.confidence.rawValue)]",
            "Mission: \(snapshot.mission.statedMission) [\(snapshot.mission.confidence.rawValue)]",
            gitLine(snapshot.git),
            "Reality: \(snapshot.reality.score)% - \(snapshot.reality.currentState)",
            verificationLine(snapshot.verificationSummary),
            "Evidence provenance: \(evidenceProvenanceLine(snapshot.evidence))",
            "Release: \(release.status.rawValue) - \(tidyTerminalText(release.headline))",
            "Release gates needing evidence: \(releaseGateLine(release))",
            "Release blockers: \(listLine(release.blockers + release.riskBlockers))",
            "Release caveats: \(listLine(release.caveats))",
            "Truth Debt status: \(truthDebt.status.rawValue) - \(tidyTerminalText(truthDebt.headline))",
            "Truth Debt release claim: \(truthDebtReleaseClaimLine(truthDebt))",
            "Truth Debt blockers/caveats: \(truthDebt.blockers.count) blocker(s), \(truthDebt.caveats.count) caveat(s), \(truthDebt.gates.count) total gate(s)",
            "Truth Debt next action: \(truthDebtNextActionLine(truthDebt))",
            "Trust chain: \(verificationChainLine(snapshot.reality.chain))",
            "Top risk: \(snapshot.reality.topRisks.first ?? "None observed")",
            "Next action: \(snapshot.reality.nextAction)",
            "Files: \(snapshot.summary.totalFiles), Source: \(snapshot.summary.sourceFiles), Tests: \(snapshot.summary.testFiles), Docs: \(snapshot.summary.documentationFiles), Findings: \(snapshot.findings.count)",
            "Read-only: \(snapshot.isReadOnly ? "Yes" : "No")"
        ]

        if includeRedactionBoundary {
            lines.append("Boundary: CLI Truth Debt reflects this scan snapshot only; persisted workspace evidence, risk, and assumption registers are included only when supplied by the GUI.")
            lines.append("Boundary: scan/report run a local read-only scan only; markdown reports redact common credential-like values and private home paths before printing.")
        }

        return lines
    }

    private static func truthDebtReleaseClaimLine(_ report: TruthDebtReport) -> String {
        switch report.status {
        case .blocked:
            return "Blocked by Truth Debt"
        case .caveated:
            return "Defensible with caveats"
        case .defensible:
            return "Defensible"
        }
    }

    private static func truthDebtNextActionLine(_ report: TruthDebtReport) -> String {
        report.nextActions.first ?? "No truth debt action is required; keep release evidence current."
    }

    private static func gitLine(_ git: GitStatus) -> String {
        guard git.isRepository else { return "Git: not a repository" }

        var line = "Git: branch \(git.branchDisplay), \(git.workingTreeSummary)"
        if git.hasUpstream {
            line += ", \(git.ahead) ahead / \(git.behind) behind"
        }
        if let hash = git.lastCommitShortHash {
            line += ", last commit \(hash)"
        }
        return line
    }

    private static func verificationLine(_ summary: VerificationSummary) -> String {
        guard summary.total > 0 else {
            return "Verification gates: 0 tracked - release state is based on in-scope areas with no recorded verification yet"
        }

        let coverage = Int((summary.coverage * 100).rounded())
        return "Verification gates: \(summary.verified)/\(summary.total) verified (\(coverage)%), \(summary.failed) failed, \(summary.inProgress) in progress, \(summary.unknown) unknown"
    }

    private static func evidenceProvenanceLine(_ evidence: [Evidence]) -> String {
        let counts = Dictionary(grouping: evidence, by: \.classification)
        return evidenceClassificationOrder.map { classification in
            "\(classification.rawValue) \(counts[classification, default: []].count)"
        }.joined(separator: ", ")
    }

    private static func releaseGateLine(_ board: ReleaseReadinessBoard) -> String {
        let unresolved = board.rows.filter { row in
            guard row.priority == .critical || row.priority == .high else { return false }
            return row.state != .verified || !row.blockedBy.isEmpty
        }

        guard !unresolved.isEmpty else {
            if board.criticalRemaining > 0 || board.highRemaining > 0 {
                return "\(board.criticalRemaining) critical / \(board.highRemaining) high remaining; see caveats"
            }
            return "None"
        }

        let labels = unresolved.map { row in
            var label = "\(row.area) (\(row.priority.rawValue), \(row.state.rawValue)"
            if !row.blockedBy.isEmpty {
                label += ", blocked by \(row.blockedBy.joined(separator: ", "))"
            }
            return label + ")"
        }
        return listLine(labels, limit: 4)
    }

    private static func verificationChainLine(_ chain: [VerificationStageStatus]) -> String {
        guard !chain.isEmpty else { return "No verification chain recorded" }

        let reached = chain.filter { $0.state == .reached }.map(\.stage.rawValue)
        let blocked = chain.first { $0.state == .notReached }?.stage.rawValue
        let reachedText = reached.isEmpty ? "none reached" : "reached \(reached.joined(separator: ", "))"

        if let blocked {
            return "\(reachedText); next not reached: \(blocked)"
        }
        return reachedText
    }

    private static func listLine(_ items: [String], limit: Int = 3) -> String {
        guard !items.isEmpty else { return "None" }
        let visible = items.prefix(limit)
        let suffix = items.count > visible.count ? " +\(items.count - visible.count) more" : ""
        return visible.joined(separator: "; ") + suffix
    }

    private static func tidyTerminalText(_ text: String) -> String {
        var output = text
        while output.contains("..") {
            output = output.replacingOccurrences(of: "..", with: ".")
        }
        return output
    }

    private static var evidenceClassificationOrder: [EvidenceClassification] {
        [.verified, .measured, .observed, .inferred, .assumed, .unknown]
    }
}
