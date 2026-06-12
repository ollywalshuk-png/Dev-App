import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Workspace health trust checks")
struct WorkspaceHealthTrustTests {
    @Test("environment evidence without a snapshot is reported")
    func environmentEvidenceWithoutSnapshotIsReported() throws {
        let pid = UUID()
        let record = PersistedProjectRecord(
            id: pid,
            name: "Env App",
            fallbackPath: "/tmp/env-app",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .saved,
            evidence: [
                EvidenceRecord(
                    area: "Environment",
                    kind: .environment,
                    summary: "Environment Capture: Success"
                ),
            ]
        )

        let report = WorkspaceHealthEngine().report(projects: [record], projectNames: [pid: "Env App"])
        let issue = try #require(report.issues(for: .evidenceDecay).first {
            $0.title == "Environment evidence has no snapshot"
        })

        #expect(issue.severity == .medium)
        #expect(issue.detail.contains("no environment snapshot"))
    }

    @Test("stale or incomplete environment snapshot is reported")
    func staleOrIncompleteEnvironmentSnapshotIsReported() throws {
        let pid = UUID()
        let record = PersistedProjectRecord(
            id: pid,
            name: "Release App",
            fallbackPath: "/tmp/release-app",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .saved,
            environments: [
                EnvironmentSnapshot(
                    macOSVersion: "",
                    xcodeVersion: "16.4",
                    swiftVersion: "",
                    sdkVersion: "macosx15.5",
                    capturedAt: Date().addingTimeInterval(-TimeInterval(120 * 86_400))
                ),
            ]
        )

        let report = WorkspaceHealthEngine().report(projects: [record], projectNames: [pid: "Release App"])
        let incomplete = try #require(report.issues(for: .evidenceDecay).first {
            $0.title == "Latest environment snapshot is incomplete"
        })
        let stale = try #require(report.issues(for: .evidenceDecay).first {
            $0.title == "Environment snapshot is stale"
        })

        #expect(incomplete.detail.contains("macOS"))
        #expect(incomplete.detail.contains("Swift"))
        #expect(stale.detail.contains("90"))
    }

    @Test("fresh complete environment snapshot does not create a trust issue")
    func freshCompleteEnvironmentSnapshotDoesNotCreateTrustIssue() {
        let pid = UUID()
        let record = PersistedProjectRecord(
            id: pid,
            name: "Clean Env App",
            fallbackPath: "/tmp/clean-env-app",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .saved,
            environments: [
                EnvironmentSnapshot(
                    macOSVersion: "15.5",
                    xcodeVersion: "16.4",
                    swiftVersion: "6.1",
                    sdkVersion: "macosx15.5",
                    capturedAt: Date()
                ),
            ]
        )

        let report = WorkspaceHealthEngine().report(projects: [record], projectNames: [pid: "Clean Env App"])

        #expect(!report.issues(for: .evidenceDecay).contains {
            $0.title.localizedCaseInsensitiveContains("environment")
        })
    }
}
