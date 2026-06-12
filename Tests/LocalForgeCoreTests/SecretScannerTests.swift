import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Local secret scan foundation")
struct SecretScannerTests {
    @Test("secret scanner detects assignments without storing the value")
    func detectsAssignmentsWithoutStoringValue() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let value = ["lf", "local", "credential", "value", "123456"].joined(separator: "_")
        let line = "let " + "API_" + "TOKEN = \"" + value + "\""
        try fixture.write("Sources/AppConfig.swift", contents: "let mode = \"debug\"\n\(line)\n")

        let finding = try #require(SecretScannerEngine().scan(repoRoot: fixture.root).first)

        #expect(finding.relativePath == "Sources/AppConfig.swift")
        #expect(finding.lineNumber == 2)
        #expect(finding.kind == .credentialAssignment)
        #expect(finding.redactedPreview.contains("<redacted>"))
        #expect(!finding.redactedPreview.contains(value))
    }

    @Test("secret scanner detects provider token shapes without committing examples")
    func detectsProviderTokenShapes() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let token = "AKIA" + String(repeating: "A", count: 16)
        try fixture.write("Config/.env.local", contents: "CLOUD_ACCESS_KEY=\(token)\n")

        let finding = try #require(SecretScannerEngine().scan(repoRoot: fixture.root).first)

        #expect(finding.kind == .providerToken)
        #expect(finding.severity == .high)
        #expect(finding.redactedPreview.contains("<redacted-provider-token>"))
        #expect(!finding.redactedPreview.contains(token))
    }

    @Test("secret scanner skips generated folders and redacted placeholders")
    func skipsGeneratedFoldersAndPlaceholders() throws {
        let fixture = try Fixture()
        defer { fixture.cleanup() }

        let value = ["lf", "generated", "credential", "value", "123456"].joined(separator: "_")
        try fixture.write(".build/Generated.swift", contents: "let " + "API_" + "TOKEN = \"\(value)\"\n")
        try fixture.write("Docs/Example.md", contents: "API_TOKEN=<redacted>\n")

        let findings = SecretScannerEngine().scan(repoRoot: fixture.root)

        #expect(findings.isEmpty)
    }

    @Test("secret scanner recommendations stay non-mutating and redacted")
    func recommendationsStayNonMutatingAndRedacted() throws {
        let finding = SecretScanFinding(
            path: "/tmp/App/Config.swift",
            relativePath: "Config.swift",
            lineNumber: 4,
            kind: .credentialAssignment,
            redactedPreview: "API_TOKEN=<redacted>",
            reason: "credential-like assignment"
        )

        let recommendation = try #require(SecretScannerEngine().recommendations(from: [finding]).first)

        #expect(recommendation.category == .safety)
        #expect(recommendation.sourceFilesAffected)
        #expect(recommendation.safetyWarning.contains("Do not paste"))
        #expect(recommendation.suggestedAdjustment.contains("Keychain"))
        #expect(recommendation.rollbackNote.contains("does not delete"))
        #expect(!recommendation.evidenceSummary.contains("credential_value"))
    }
}

private struct Fixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lf-secret-scan-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    func write(_ relativePath: String, contents: String) throws {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
    }

    func cleanup() {
        try? FileManager.default.removeItem(at: root)
    }
}
