import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Dev command evidence signals")
struct DevCommandEvidenceSignalTests {
    @Test("swift test failure evidence names the failed command signal")
    func swiftTestFailureEvidenceNamesFailedCommandSignal() throws {
        let command = try preset(.swiftTest)
        let result = DevToolsCommandResult(
            command: command,
            status: .failure,
            output: "Test Suite 'LocalForgeCoreTests' failed.",
            startedAt: Date(timeIntervalSince1970: 1_717_100_000),
            exitCode: 1
        )

        let records = DevCommandEngine().provenanceRecords(for: result)
        let build = try #require(records.build)
        let test = try #require(records.test)

        #expect(records.evidence.summary == "Swift Test: Failure")
        #expect(records.evidence.classification == .measured)
        #expect(records.evidence.body.contains("Dev Tools evidence signal: Swift Test failed (exit code 1)."))
        #expect(records.evidence.body.contains("failed command"))
        #expect(records.evidence.body.contains("fix and rerun"))
        #expect(records.evidence.body.contains("Tests as release-supporting evidence"))
        #expect(records.evidence.body.contains("Test Suite 'LocalForgeCoreTests' failed."))
        #expect(!records.evidence.body.localizedCaseInsensitiveContains("release-ready"))
        #expect(build.notes == records.evidence.body)
        #expect(test.notes == records.evidence.body)
    }

    @Test("swift build success caveats release readiness")
    func swiftBuildSuccessCaveatsReleaseReadiness() throws {
        let command = try preset(.swiftBuild)
        let result = DevToolsCommandResult(
            command: command,
            status: .success,
            output: "Build complete!",
            startedAt: Date(timeIntervalSince1970: 1_717_100_100),
            exitCode: 0
        )

        let records = DevCommandEngine().provenanceRecords(for: result)
        let build = try #require(records.build)

        #expect(records.evidence.summary == "Swift Build: Success")
        #expect(records.evidence.classification == .observed)
        #expect(records.evidence.body.contains("Dev Tools evidence signal: Swift Build succeeded (exit code 0)."))
        #expect(records.evidence.body.contains("does not by itself mark verification or release readiness as passed"))
        #expect(records.evidence.body.contains("Build complete!"))
        #expect(!records.evidence.body.localizedCaseInsensitiveContains("release-ready"))
        #expect(build.notes == records.evidence.body)
    }

    private func preset(
        _ kind: DevToolsCommandKind,
        root: String = "/tmp/localforge-devtools-evidence-signals"
    ) throws -> DevToolsCommand {
        let commands = DevCommandEngine().presets(
            projectRoot: root,
            appBundlePath: "\(root)/Build/LocalForge.app"
        )
        return try #require(commands.first { $0.kind == kind })
    }
}
