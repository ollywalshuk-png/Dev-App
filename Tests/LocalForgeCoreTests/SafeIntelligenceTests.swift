import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Phase 10C — Safe intelligence and approval framework")
struct SafeIntelligenceTests {
    @Test("code-size scanner flags files over 1750 lines")
    func scannerFlagsFilesOverThreshold() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lf-bloat-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let large = root.appendingPathComponent("LargeView.swift")
        try makeFile(large, lines: 1_751)

        let findings = CodeBloatScannerEngine().scan(repoRoot: root)

        #expect(findings.count == 1)
        #expect(findings[0].relativePath == "LargeView.swift")
        #expect(findings[0].lineCount == 1_751)
        #expect(findings[0].threshold == 1_750)
    }

    @Test("code-size scanner ignores files under threshold and excluded folders")
    func scannerIgnoresBelowThresholdAndExcludedFolders() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lf-bloat-skip-\(UUID().uuidString)")
        let build = root.appendingPathComponent(".build")
        try fm.createDirectory(at: build, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try makeFile(root.appendingPathComponent("Small.swift"), lines: 1_750)
        try makeFile(build.appendingPathComponent("Generated.swift"), lines: 4_000)

        let findings = CodeBloatScannerEngine().scan(repoRoot: root)

        #expect(findings.isEmpty)
    }

    @Test("code-size findings become non-mutating recommendations")
    func findingsBecomeRecommendations() throws {
        let finding = CodeSizeFinding(
            path: "/tmp/App/LargeView.swift",
            relativePath: "LargeView.swift",
            lineCount: 2_100,
            threshold: 1_750,
            language: "Swift"
        )

        let recommendation = try #require(CodeBloatScannerEngine().recommendations(from: [finding]).first)

        #expect(recommendation.category == .codeSize)
        #expect(recommendation.sourceFilesAffected)
        #expect(recommendation.approvalState == .open)
        #expect(recommendation.safetyWarning.contains("must be approved separately"))
        #expect(recommendation.suggestedAdjustment.contains("Review"))
    }

    @Test("recommendation records decode safely from older JSON")
    func recommendationRecordDecodesDefaults() throws {
        let json = #"{"category":"Code Size","title":"Large file","summary":"Review","targetPath":"/tmp/Large.swift","sourceFilesAffected":true,"severity":"Warning","evidenceSummary":"2100 lines","impact":"Hard to review","suggestedAdjustment":"Split manually","safetyWarning":"Approve first","rollbackNote":"Use Git"}"#
        let data = try #require(json.data(using: .utf8))
        let record = try JSONDecoder().decode(RecommendationRecord.self, from: data)

        #expect(record.approvalState == .open)
        #expect(record.relatedEvidenceIDs.isEmpty)
        #expect(!record.id.uuidString.isEmpty)
    }

    @Test("approval state transition is explicit metadata only")
    func approvalTransitionIsExplicitMetadata() {
        let record = RecommendationRecord(
            category: .codeSize,
            title: "Large file",
            summary: "Review",
            targetPath: "/tmp/Large.swift",
            sourceFilesAffected: true,
            severity: .warning,
            evidenceSummary: "2100 lines",
            impact: "Hard to review",
            suggestedAdjustment: "Split manually",
            safetyWarning: "Approve first",
            rollbackNote: "Use Git"
        )

        let approved = record.withApprovalState(.approved, by: "Tester", note: "Do this later")

        #expect(approved.approvalState == .approved)
        #expect(approved.approvedBy == "Tester")
        #expect(approved.approvalNote == "Do this later")
        #expect(approved.targetPath == record.targetPath)
        #expect(approved.suggestedAdjustment == record.suggestedAdjustment)
    }

    private func makeFile(_ url: URL, lines: Int) throws {
        let body = (0..<lines).map { "let value\($0) = \($0)" }.joined(separator: "\n")
        try body.write(to: url, atomically: true, encoding: .utf8)
    }
}
