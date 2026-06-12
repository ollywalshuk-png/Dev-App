import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Dev Tools evidence provenance")
struct DevToolsEvidenceProvenanceTests {
    @Test("swift test failure creates measured evidence plus linked build and test records")
    func swiftTestFailureCreatesReleaseRelevantRecords() throws {
        let started = Date(timeIntervalSince1970: 1_717_000_000)
        let ended = started.addingTimeInterval(12)
        let command = try preset(.swiftTest)
        let result = DevToolsCommandResult(
            command: command,
            status: .failure,
            output: """
            Test Suite 'LocalForgeCoreTests' failed.
            api_key=abcdef123
            Full log: /Users/chris/private/build.log
            """,
            startedAt: started,
            endedAt: ended,
            exitCode: 1
        )

        let records = DevCommandEngine().provenanceRecords(for: result, author: "Dev Tools")
        let build = try #require(records.build)
        let test = try #require(records.test)

        #expect(records.evidence.area == "Tests")
        #expect(records.evidence.kind == .logExcerpt)
        #expect(records.evidence.summary == "Swift Test: Failure")
        #expect(records.evidence.classification == .measured)
        #expect(records.evidence.author == "Dev Tools")
        #expect(records.evidence.createdAt == ended)

        #expect(build.buildType == .swiftTest)
        #expect(build.result == .failure)
        #expect(build.startTime == started)
        #expect(build.endTime == ended)
        #expect(build.linkedEvidenceIDs == [records.evidence.id])
        #expect(build.linkedVerificationAreas == ["Tests"])

        #expect(test.name == "swift test")
        #expect(test.kind == .automated)
        #expect(test.outcome == .failed)
        #expect(test.outcome.releaseReadinessImpact.contains("Blocks release"))
        #expect(test.linkedVerificationArea == "Tests")
        #expect(test.linkedEvidenceIDs == [records.evidence.id])
        #expect(test.author == "Dev Tools")
        #expect(test.testedAt == ended)

        assertRedacted(records.evidence.body)
        assertRedacted(build.notes)
        assertRedacted(test.notes)
    }

    @Test("codesign failure creates release-relevant evidence without build or test records")
    func codesignFailureCreatesEvidenceOnly() throws {
        let command = try preset(.codesignVerify)
        let result = DevToolsCommandResult(
            command: command,
            status: .failure,
            output: """
            /tmp/LocalForge.app: code object is not signed at all
            password = signingsecret123
            Signing log: /Users/chris/private/signing.log
            """,
            startedAt: Date(timeIntervalSince1970: 1_717_000_100),
            exitCode: 1
        )

        let records = DevCommandEngine().provenanceRecords(for: result)

        #expect(records.evidence.area == "Signing")
        #expect(records.evidence.kind == .logExcerpt)
        #expect(records.evidence.summary == "Codesign Verify: Failure")
        #expect(records.evidence.classification == .measured)
        #expect(records.evidence.body.contains("code object is not signed"))
        #expect(records.build == nil)
        #expect(records.test == nil)
        #expect(records.environment == nil)
        assertRedacted(records.evidence.body)
        #expect(!records.evidence.body.contains("signingsecret123"))
    }

    @Test("npm test failure creates linked build and test records")
    func npmTestFailureCreatesWorkflowTelemetry() throws {
        let started = Date(timeIntervalSince1970: 1_717_000_150)
        let command = try preset(.npmTest, projectMarkers: [.packageJSON])
        let result = DevToolsCommandResult(
            command: command,
            status: .failure,
            output: "npm test failed\napi_key=abcdef123",
            startedAt: started,
            endedAt: started.addingTimeInterval(8),
            exitCode: 1
        )

        let records = DevCommandEngine().provenanceRecords(for: result, author: "Dev Tools")
        let build = try #require(records.build)
        let test = try #require(records.test)

        #expect(records.evidence.area == "Tests")
        #expect(build.buildType == .npmTest)
        #expect(build.linkedEvidenceIDs == [records.evidence.id])
        #expect(test.name == "npm test")
        #expect(test.outcome == .failed)
        #expect(test.linkedEvidenceIDs == [records.evidence.id])
        assertRedacted(records.evidence.body)
    }

    @Test("environment capture creates environment evidence and a redacted snapshot")
    func environmentCaptureCreatesEnvironmentRecord() throws {
        let started = Date(timeIntervalSince1970: 1_717_000_200)
        let command = try preset(.environmentCapture)
        let result = DevToolsCommandResult(
            command: command,
            status: .success,
            output: """
            macOS: 15.5
            Xcode: 16.4
            Swift: 6.1
            SDK: macosx15.5
            auval: 1.10
            Notes: copied from /Users/chris/private/env.txt
            """,
            startedAt: started
        )

        let records = DevCommandEngine().provenanceRecords(for: result)
        let environment = try #require(records.environment)

        #expect(records.evidence.area == "Environment")
        #expect(records.evidence.kind == .environment)
        #expect(records.evidence.summary == "Environment Capture: Success")
        #expect(records.evidence.classification == .observed)
        #expect(records.build == nil)
        #expect(records.test == nil)

        #expect(environment.macOSVersion == "15.5")
        #expect(environment.xcodeVersion == "16.4")
        #expect(environment.swiftVersion == "6.1")
        #expect(environment.sdkVersion == "macosx15.5")
        #expect(environment.auValVersion == "1.10")
        #expect(environment.capturedAt == started)
        assertRedacted(environment.notes)
        assertRedacted(records.evidence.body)
    }

    @Test("oversized output truncates after redaction without splitting a UTF-8 boundary")
    func oversizedOutputTruncatesAfterRedaction() throws {
        let command = try preset(.swiftBuild)
        let marker = "[output truncated at \(DevCommandEngine.maxOutputBytes) bytes]"
        let redactedSecretLine = "[REDACTED_SECRET]\n"
        let fillCount = DevCommandEngine.maxOutputBytes - redactedSecretLine.utf8.count - 1
        let boundaryCharacter = "\u{00E9}"
        let output = "api_key=abcdef123\n"
            + String(repeating: "x", count: fillCount)
            + boundaryCharacter
            + "tail"
        let result = DevToolsCommandResult(
            command: command,
            status: .failure,
            output: output,
            startedAt: Date(timeIntervalSince1970: 1_717_000_300),
            exitCode: 1
        )

        let records = DevCommandEngine().provenanceRecords(for: result)
        let build = try #require(records.build)
        let prefix = String(records.evidence.body.dropLast(marker.count + 2))

        #expect(records.evidence.body.hasSuffix("\n\n\(marker)"))
        #expect(records.evidence.body.contains("[REDACTED_SECRET]"))
        #expect(prefix.utf8.count == DevCommandEngine.maxOutputBytes - 1)
        #expect(!records.evidence.body.contains("api_key=abcdef123"))
        #expect(!records.evidence.body.contains(boundaryCharacter))
        #expect(!records.evidence.body.contains("tail"))
        #expect(build.notes == records.evidence.body)
    }

    private func preset(
        _ kind: DevToolsCommandKind,
        root: String? = nil,
        projectMarkers: Set<ProjectMarker> = []
    ) throws -> DevToolsCommand {
        let fm = FileManager.default
        let root = root ?? fm.temporaryDirectory.appendingPathComponent("lf-devtools-provenance-\(UUID().uuidString)").path
        let rootURL = URL(fileURLWithPath: root)
        try? fm.removeItem(at: rootURL)
        try fm.createDirectory(at: rootURL, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: rootURL) }
        if projectMarkers.contains(.packageJSON) {
            try Data("{}".utf8).write(to: rootURL.appendingPathComponent("package.json"))
        }
        if projectMarkers.contains(.xcodeProject) {
            try fm.createDirectory(at: rootURL.appendingPathComponent("App.xcodeproj"), withIntermediateDirectories: true)
        }

        let commands = DevCommandEngine().presets(
            projectRoot: root,
            appBundlePath: "\(root)/Build/LocalForge.app"
        )
        return try #require(commands.first { $0.kind == kind })
    }

    private func assertRedacted(_ text: String) {
        #expect(text.contains("[REDACTED_SECRET]") || text.contains("[REDACTED_PRIVATE_PATH]"))
        #expect(!text.contains("api_key=abcdef123"))
        #expect(!text.contains("/Users/chris/private"))
    }

    private enum ProjectMarker: Hashable {
        case packageJSON
        case xcodeProject
    }
}
