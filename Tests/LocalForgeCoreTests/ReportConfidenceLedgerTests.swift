import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Report confidence ledger")
struct ReportConfidenceLedgerTests {
    @Test("report caveats missing evidence")
    func reportCaveatsMissingEvidence() {
        var snapshot = RepoSnapshot.fixture()
        snapshot.evidence = []
        snapshot.reality = RealityAssessment(
            score: 15,
            currentState: "Evidence missing",
            knownFacts: [],
            verified: [],
            unverified: ["Build"],
            assumptions: [],
            unknowns: ["Release readiness"],
            topRisks: [],
            nextAction: "Capture local verification evidence.",
            chain: []
        )

        let report = ReportEngine().markdownReport(for: snapshot)

        #expect(report.contains("## Confidence Limits"))
        #expect(report.contains("no evidence records were captured"))
        #expect(report.contains("treat this report as a scan scaffold"))
        #expect(report.contains("- Unverified scope: Build."))
        #expect(report.contains("- Unknowns: Release readiness."))
    }

    @Test("report caveats weak-only evidence")
    func reportCaveatsWeakOnlyEvidence() {
        var snapshot = RepoSnapshot.fixture()
        snapshot.evidence = [
            Evidence(
                title: "Release state inferred",
                detail: "Package shape suggests it may be releasable",
                classification: .inferred,
                source: "classifier"
            ),
            Evidence(
                title: "Signing identity assumed",
                detail: "Assumed Developer ID profile exists",
                classification: .assumed,
                source: "release"
            ),
            Evidence(
                title: "Notarisation status unknown",
                detail: "No notarisation check has been run",
                classification: .unknown,
                source: "release"
            ),
        ]
        snapshot.reality = RealityAssessment(
            score: 28,
            currentState: "Weak evidence only",
            knownFacts: [],
            verified: [],
            unverified: ["Signing"],
            assumptions: ["Developer ID profile exists"],
            unknowns: ["Notarisation status"],
            topRisks: [],
            nextAction: "Run signing and notarisation verification.",
            chain: []
        )

        let report = ReportEngine().markdownReport(for: snapshot)

        #expect(report.contains("## Confidence Limits"))
        #expect(report.contains("no verified, measured, or observed evidence backs this report"))
        #expect(report.contains("conclusions are based on inferred, assumed, or unknown signals"))
        #expect(report.contains("- Assumptions: Developer ID profile exists."))
        #expect(report.contains("- Unknowns: Notarisation status."))
    }
}
