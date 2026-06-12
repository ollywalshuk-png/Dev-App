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
            $0.delta > 0 && $0.label == "2 unique in-scope strong evidence signal(s)"
        })
        #expect(backed.contributions.contains { $0.label == "Evidence covers 2/2 in-scope area(s)" })
    }

    @Test("duplicate strong evidence cannot inflate confidence")
    func duplicateStrongEvidenceCannotInflateConfidence() {
        let snapshot = releaseSnapshot()
        let baselineEvidence = [
            EvidenceRecord(area: "Build", summary: "Build log captured", classification: .observed),
            EvidenceRecord(area: "Automated Tests", summary: "Test output measured", classification: .measured),
        ]
        let baseline = TruthEngine().confidence(snapshot: snapshot, evidence: baselineEvidence, assumptions: [])
        let padded = TruthEngine().confidence(
            snapshot: snapshot,
            evidence: baselineEvidence + Array(repeating: baselineEvidence[0], count: 20),
            assumptions: []
        )

        #expect(padded.score == baseline.score)
        #expect(padded.contributions.contains {
            $0.delta > 0 && $0.label == "2 unique in-scope strong evidence signal(s)"
        })
    }

    @Test("conflicting strong evidence cannot raise confidence")
    func conflictingStrongEvidenceCannotRaiseConfidence() {
        let snapshot = releaseSnapshot(verification: [
            VerificationRecord(area: "Build", state: .verified),
            VerificationRecord(area: "Automated Tests", state: .verified),
        ])
        let baselineEvidence = [
            EvidenceRecord(area: "Build", summary: "Build log captured", classification: .observed),
            EvidenceRecord(area: "Automated Tests", summary: "Test output measured", classification: .measured),
        ]
        let baseline = TruthEngine().confidence(snapshot: snapshot, evidence: baselineEvidence, assumptions: [])
        let contradictory = TruthEngine().confidence(
            snapshot: snapshot,
            evidence: baselineEvidence + [
                EvidenceRecord(area: "Build", summary: "Build failed during release rehearsal", classification: .observed),
            ],
            assumptions: []
        )

        #expect(contradictory.score <= baseline.score)
        #expect(contradictory.contributions.contains {
            $0.delta < 0 && $0.label == "1 contradictory confidence area(s)"
        })
    }

    @Test("failed evidence without failed state cannot raise confidence")
    func failedEvidenceWithoutFailedStateCannotRaiseConfidence() {
        let snapshot = releaseSnapshot()
        let baseline = TruthEngine().confidence(snapshot: snapshot, evidence: [], assumptions: [])
        let failedEvidence = TruthEngine().confidence(
            snapshot: snapshot,
            evidence: [
                EvidenceRecord(area: "Build", summary: "Release build fails during signing", classification: .measured)
            ],
            assumptions: []
        )

        #expect(failedEvidence.score <= baseline.score)
        #expect(!failedEvidence.contributions.contains {
            $0.delta > 0 && $0.label.localizedCaseInsensitiveContains("strong evidence")
        })
        #expect(failedEvidence.contributions.contains {
            $0.delta < 0 && $0.label == "1 failed evidence signal(s)"
        })
        #expect(failedEvidence.contributions.contains { $0.label == "Evidence covers 0/2 in-scope area(s)" })
    }

    @Test("failure evidence can support an explicitly failed state")
    func failureEvidenceCanSupportExplicitlyFailedState() {
        let snapshot = releaseSnapshot(verification: [
            VerificationRecord(area: "Build", state: .failed),
            VerificationRecord(area: "Automated Tests", state: .unknown),
        ])
        let baseline = TruthEngine().confidence(snapshot: snapshot, evidence: [], assumptions: [])
        let failureEvidence = TruthEngine().confidence(
            snapshot: snapshot,
            evidence: [
                EvidenceRecord(area: "Build", summary: "Release build fails during signing", classification: .measured)
            ],
            assumptions: []
        )

        #expect(failureEvidence.score > baseline.score)
        #expect(failureEvidence.contributions.contains {
            $0.delta > 0 && $0.label == "1 unique in-scope strong evidence signal(s)"
        })
        #expect(!failureEvidence.contributions.contains {
            $0.delta < 0 && $0.label.localizedCaseInsensitiveContains("failed evidence")
        })
        #expect(failureEvidence.contributions.contains { $0.label == "Evidence covers 1/2 in-scope area(s)" })
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
