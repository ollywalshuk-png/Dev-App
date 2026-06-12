import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Evidence provenance")
struct EvidenceProvenanceTests {
    @Test("why verification separates provenance, stale records, and contradictions")
    func whyVerificationShowsTrustProvenance() {
        let old = Date().addingTimeInterval(-120.0 * 86_400.0)
        let record = VerificationRecord(area: "Release Build", state: .verified, updatedAt: old)
        let evidence = [
            EvidenceRecord(
                area: "Release Build",
                kind: .reproduction,
                summary: "Release build passes smoke test",
                classification: .verified,
                createdAt: old.addingTimeInterval(60)
            ),
            EvidenceRecord(
                area: "Release Build",
                kind: .logExcerpt,
                summary: "Release build fails during signing",
                body: "codesign error",
                classification: .measured
            ),
            EvidenceRecord(
                area: "Release Build",
                kind: .observation,
                summary: "Signing profile is assumed present",
                classification: .assumed
            ),
        ]

        let why = WhyEngine().whyVerification(record: record, evidence: evidence, journal: [])

        let provenance = why.sections.first { $0.title == "Evidence Provenance" }
        #expect(provenance?.items.contains { $0.label == "Verified evidence" && $0.value == "1 record(s)" } == true)
        #expect(provenance?.items.contains { $0.label == "Measured evidence" && $0.value == "1 record(s)" } == true)
        #expect(provenance?.items.contains { $0.label == "Assumed evidence" && $0.isNegative } == true)

        let stale = why.sections.first { $0.title == "Stale Records" }
        #expect(stale?.items.contains { $0.label == "Release Build" && $0.value.contains("Stale") } == true)

        let contradictions = why.sections.first { $0.title == "Contradictory Evidence" }
        #expect(contradictions?.items.contains { $0.label == "Release Build" && $0.value == "1 passing / 1 failing" } == true)
    }

    @Test("confidence provenance keeps assumptions distinct from inferences")
    func confidenceProvenanceSeparatesAssumptions() {
        let assessment = ConfidenceAssessment(score: 64, label: "Medium", summary: "", contributions: [])
        let provenance = WhyEngine().confidenceProvenance(
            assessment: assessment,
            evidence: [
                EvidenceRecord(area: "A", summary: "Observed file layout", classification: .observed),
                EvidenceRecord(area: "A", summary: "Inferred app type", classification: .inferred),
                EvidenceRecord(area: "A", summary: "Assumed release owner", classification: .assumed),
            ]
        )

        #expect(provenance.items.contains { $0.label == "1 observed record(s)" })
        #expect(provenance.items.contains { $0.label == "1 inferred record(s)" })
        #expect(provenance.items.contains { $0.label == "1 assumed record(s)" })
    }

    @Test("conflict detection separates passing and failing evidence")
    func conflictDetectionDoesNotCountFailuresAsSuccesses() {
        let conflicts = WhyEngine().detectConflicts(
            evidence: [
                EvidenceRecord(area: "Build", summary: "Build passes locally", classification: .observed),
                EvidenceRecord(area: "Build", summary: "Build fails on archive", classification: .measured),
                EvidenceRecord(area: "Build", summary: "No failures observed in lint", classification: .observed),
            ],
            projectID: UUID(),
            projectName: "LocalForge"
        )

        #expect(conflicts.count == 1)
        #expect(conflicts.first?.successEvidence.count == 1)
        #expect(conflicts.first?.failureEvidence.count == 1)
    }

    @Test("markdown report groups provenance and remains redaction safe")
    func reportGroupsEvidenceProvenance() {
        let old = Date().addingTimeInterval(-130.0 * 86_400.0)
        var snapshot = RepoSnapshot.fixture()
        snapshot.verification = [
            VerificationRecord(area: "Release Build", state: .verified, updatedAt: old)
        ]
        snapshot.reality = RealityAssessment(
            score: 52,
            currentState: "Needs verification",
            knownFacts: ["Local scan completed"],
            verified: [],
            unverified: ["Signing"],
            assumptions: ["Developer ID profile exists at /Users/chris/private"],
            unknowns: [],
            topRisks: [],
            nextAction: "Resolve contradictory build evidence.",
            chain: []
        )
        snapshot.evidence = [
            Evidence(
                title: "Release build verified",
                detail: "Build passes on local machine",
                classification: .verified,
                source: "build"
            ),
            Evidence(
                title: "Release build failure",
                detail: "Build fails with api_key=abcdef123 at /Users/chris/private/log.txt",
                classification: .measured,
                source: "build"
            ),
            Evidence(
                title: "Package files observed",
                detail: "Package.swift and Sources directory found",
                classification: .observed,
                source: "scanner"
            ),
            Evidence(
                title: "App category inferred",
                detail: "Swift package shape suggests a developer tool",
                classification: .inferred,
                source: "classifier"
            ),
            Evidence(
                title: "Signing identity assumed",
                detail: "Assumed profile will be available in Keychain",
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

        let report = ReportEngine().markdownReport(for: snapshot)

        #expect(report.contains("## Evidence Provenance"))
        #expect(report.contains("- Verified: 1 record(s)"))
        #expect(report.contains("- Measured: 1 record(s)"))
        #expect(report.contains("- Observed: 1 record(s)"))
        #expect(report.contains("- Inferred: 1 record(s)"))
        #expect(report.contains("- Assumed: 1 record(s)"))
        #expect(report.contains("- Unknown: 1 record(s)"))
        #expect(report.contains("### Verified Evidence"))
        #expect(report.contains("## Assumptions / Inferences"))
        #expect(report.contains("## Stale Records"))
        #expect(report.contains("## Contradictory Evidence"))
        #expect(report.contains("1 passing and 1 failing signal(s)"))
        #expect(report.contains("[REDACTED_SECRET]"))
        #expect(report.contains("[REDACTED_PRIVATE_PATH]"))
        #expect(!report.contains("api_key=abcdef123"))
        #expect(!report.contains("/Users/chris/private"))
    }
}
