import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Secret scanner accuracy")
struct SecretScannerAccuracyTests {
    @Test("npmrc auth token lines are detected and redacted")
    func detectsNpmrcAuthTokenLinesWithoutLeakingValues() throws {
        let fixture = try SecretScannerAccuracyFixture()
        defer { fixture.cleanup() }

        let token = fakeSecretValue(label: "npm")
        try fixture.write(".npmrc", contents: "//registry.npmjs.org/:_authToken=\(token)\n")

        let finding = try #require(SecretScannerEngine().scan(repoRoot: fixture.root).first)

        #expect(finding.kind == .credentialAssignment)
        #expect(finding.reason == "npmrc auth token")
        #expect(finding.redactedPreview.contains("_authToken=<redacted>"))
        try expectNoRawValue(token, in: finding)
    }

    @Test("bearer authorization assignments are detected and redacted")
    func detectsBearerAuthorizationAssignmentsWithoutLeakingValues() throws {
        let fixture = try SecretScannerAccuracyFixture()
        defer { fixture.cleanup() }

        let token = fakeSecretValue(label: "bearer")
        try fixture.write("Config/headers.env", contents: "Authorization: Bearer \(token)\n")

        let finding = try #require(SecretScannerEngine().scan(repoRoot: fixture.root).first)

        #expect(finding.kind == .credentialAssignment)
        #expect(finding.reason == "bearer token assignment")
        #expect(finding.redactedPreview.contains("Authorization: Bearer <redacted>"))
        try expectNoRawValue(token, in: finding)
    }

    @Test("private key headers and footers are detected with boundary type redacted")
    func detectsPrivateKeyBoundaries() throws {
        let fixture = try SecretScannerAccuracyFixture()
        defer { fixture.cleanup() }

        let keyType = ["OPEN", "SSH"].joined()
        try fixture.write(
            "Keys/local.pem",
            contents: """
            -----BEGIN \(keyType) PRIVATE KEY-----
            localforge-test-key-body
            -----END \(keyType) PRIVATE KEY-----
            """
        )

        let findings = SecretScannerEngine().scan(repoRoot: fixture.root)

        #expect(findings.count == 2)
        #expect(findings.map(\.lineNumber) == [1, 3])
        #expect(findings.allSatisfy { $0.kind == .privateKeyMaterial })
        #expect(findings.allSatisfy { $0.reason == "private-key boundary" })
        #expect(findings.allSatisfy { $0.redactedPreview.contains("<redacted> PRIVATE KEY-----") })
        #expect(findings.allSatisfy { !$0.redactedPreview.contains(keyType) })
    }

    @Test("URL credentials redact both username and password")
    func redactsUrlCredentialsWithoutLeakingValues() throws {
        let fixture = try SecretScannerAccuracyFixture()
        defer { fixture.cleanup() }

        let username = fakeSecretValue(label: "user")
        let password = fakeSecretValue(label: "url")
        try fixture.write(
            "Config/remotes.env",
            contents: "REMOTE_URL=https://\(username):\(password)@dev.localforge.test/repo.git\n"
        )

        let finding = try #require(SecretScannerEngine().scan(repoRoot: fixture.root).first)

        #expect(finding.kind == .embeddedCredential)
        #expect(finding.reason == "URL with embedded credentials")
        #expect(finding.redactedPreview.contains("https://<redacted>@dev.localforge.test"))
        try expectNoRawValue(username, in: finding)
        try expectNoRawValue(password, in: finding)
    }

    @Test("placeholder and low-signal token examples are not reported")
    func skipsPlaceholdersAndLowSignalExamples() throws {
        let fixture = try SecretScannerAccuracyFixture()
        defer { fixture.cleanup() }

        try fixture.write(".npmrc", contents: "//registry.npmjs.org/:_authToken=${NPM_TOKEN}\n")
        try fixture.write(
            "Docs/Auth.md",
            contents: """
            Authorization: Bearer token
            token=production
            REMOTE_URL=https://builder:${REMOTE_TOKEN}@dev.localforge.test/repo.git
            """
        )

        let findings = SecretScannerEngine().scan(repoRoot: fixture.root)

        #expect(findings.isEmpty)
    }
}

private func fakeSecretValue(label: String) -> String {
    let suffix = UUID().uuidString.replacingOccurrences(of: "-", with: "")
    return ["lf", label, String(suffix.prefix(24)), "9"].joined(separator: "_")
}

private func expectNoRawValue(_ value: String, in finding: SecretScanFinding) throws {
    #expect(!finding.redactedPreview.contains(value))

    let recommendation = try #require(SecretScannerEngine().recommendations(from: [finding]).first)
    let recommendationText = [
        recommendation.title,
        recommendation.summary,
        recommendation.evidenceSummary,
        recommendation.impact,
        recommendation.suggestedAdjustment,
        recommendation.safetyWarning,
        recommendation.rollbackNote
    ].joined(separator: "\n")

    #expect(!recommendationText.contains(value))
}

private struct SecretScannerAccuracyFixture {
    let root: URL

    init() throws {
        root = FileManager.default.temporaryDirectory
            .appendingPathComponent("lf-secret-scan-accuracy-\(UUID().uuidString)")
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
