import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth confidence accuracy")
struct TruthConfidenceAccuracyTests {
    @Test("out-of-scope strong evidence cannot raise confidence")
    func outOfScopeStrongEvidenceCannotRaiseConfidence() {
        let snapshot = releaseSnapshot()
        let baseline = TruthEngine().confidence(snapshot: snapshot, evidence: [], assumptions: [])
        let padded = TruthEngine().confidence(
            snapshot: snapshot,
            evidence: [
                EvidenceRecord(area: "Marketing Site", summary: "Launch page reviewed", classification: .verified),
                EvidenceRecord(area: "Launch Copy", summary: "Copy checked", classification: .observed),
            ],
            assumptions: []
        )

        #expect(padded.score == baseline.score)
        #expect(!padded.contributions.contains {
            $0.delta > 0 && $0.label.localizedCaseInsensitiveContains("strong evidence")
        })
        #expect(padded.contributions.contains { $0.label == "Evidence covers 0/2 in-scope area(s)" })
    }

    @Test("in-scope strong evidence raises confidence and coverage")
    func inScopeStrongEvidenceRaisesConfidenceAndCoverage() {
        let snapshot = releaseSnapshot()
        let baseline = TruthEngine().confidence(snapshot: snapshot, evidence: [], assumptions: [])
        let backed = TruthEngine().confidence(
            snapshot: snapshot,
            evidence: [
                EvidenceRecord(area: "Build", summary: "Build log captured", classification: .observed),
                EvidenceRecord(area: "Automated Tests", summary: "Test output measured", classification: .measured),
            ],
            assumptions: []
        )

        #expect(backed.score > baseline.score)
        #expect(backed.contributions.contains {
            $0.delta > 0 && $0.label == "2 in-scope strong evidence record(s)"
        })
        #expect(backed.contributions.contains { $0.label == "Evidence covers 2/2 in-scope area(s)" })
    }

    @Test("confidence evidence area matching ignores case and whitespace")
    func confidenceEvidenceAreaMatchingIgnoresCaseAndWhitespace() {
        let snapshot = releaseSnapshot()
        let baseline = TruthEngine().confidence(snapshot: snapshot, evidence: [], assumptions: [])
        let backed = TruthEngine().confidence(
            snapshot: snapshot,
            evidence: [
                EvidenceRecord(area: "  build  ", summary: "Build log captured", classification: .observed)
            ],
            assumptions: []
        )

        #expect(backed.score > baseline.score)
        #expect(backed.contributions.contains { $0.label == "Evidence covers 1/2 in-scope area(s)" })
    }

    @Test("evidence linked to in-scope verification counts for confidence")
    func linkedInScopeVerificationEvidenceCountsForConfidence() {
        let build = VerificationRecord(area: "Build", state: .unknown)
        let tests = VerificationRecord(area: "Automated Tests", state: .unknown)
        let snapshot = releaseSnapshot(verification: [build, tests])
        let baseline = TruthEngine().confidence(snapshot: snapshot, evidence: [], assumptions: [])
        let backed = TruthEngine().confidence(
            snapshot: snapshot,
            evidence: [
                EvidenceRecord(
                    area: "Release Evidence",
                    summary: "Build log captured",
                    classification: .observed,
                    linkedVerificationIDs: [build.id]
                )
            ],
            assumptions: []
        )

        #expect(backed.score > baseline.score)
        #expect(backed.contributions.contains { $0.label == "Evidence covers 1/2 in-scope area(s)" })
    }

    private func releaseSnapshot(verification: [VerificationRecord]? = nil) -> RepoSnapshot {
        let applicability = [
            ApplicabilityItem(area: "Build", status: .required, priority: .critical),
            ApplicabilityItem(area: "Automated Tests", status: .required, priority: .high),
        ]
        var snapshot = RepoSnapshot.fixture(
            identity: ProjectIdentity(kind: .swiftPackage, detail: "confidence fixture", confidence: .observed)
        )
        snapshot.applicability = applicability
        snapshot.verification = verification ?? applicability.map {
            VerificationRecord(area: $0.area, state: .unknown)
        }
        return snapshot
    }
}
