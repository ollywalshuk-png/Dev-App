import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth contradiction guard")
struct TruthContradictionGuardTests {
    @Test("failed evidence does not lift confidence as positive proof")
    func failedEvidenceDoesNotLiftConfidenceAsPositiveProof() {
        let truthSnapshot = snapshot()
        let noEvidence = TruthEngine().confidence(snapshot: truthSnapshot, evidence: [], assumptions: [])
        let failedEvidence = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: [
                evidence("Build", "Release build fails during signing", .measured)
            ],
            assumptions: []
        )

        #expect(failedEvidence.score <= noEvidence.score)
        #expect(!failedEvidence.contributions.contains {
            $0.delta > 0 && $0.label.localizedCaseInsensitiveContains("strong evidence")
        })
        #expect(failedEvidence.contributions.contains {
            $0.delta < 0 && $0.label.localizedCaseInsensitiveContains("failed evidence")
        })
        #expect(failedEvidence.contributions.contains {
            $0.label.localizedCaseInsensitiveContains("covers 0/3")
        })
    }

    @Test("contradictory evidence withholds conflicted area credit")
    func contradictoryEvidenceWithholdsConflictedAreaCredit() {
        let truthSnapshot = snapshot()
        let cleanEvidence = [
            evidence("Build", "Release build passes locally", .observed),
            evidence("Automated Tests", "Test suite passes", .measured),
            evidence("Documentation", "Release notes verified", .verified),
        ]
        let conflictedEvidence = cleanEvidence + [
            evidence("Build", "Release build fails on archive", .measured)
        ]

        let cleanConfidence = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: cleanEvidence,
            assumptions: []
        )
        let conflictedConfidence = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: conflictedEvidence,
            assumptions: []
        )

        #expect(conflictedConfidence.score < cleanConfidence.score)
        #expect(conflictedConfidence.contributions.contains {
            $0.delta < 0 && $0.label.localizedCaseInsensitiveContains("contradictory evidence")
        })
        #expect(conflictedConfidence.contributions.contains {
            $0.label.localizedCaseInsensitiveContains("covers 2/3")
        })
    }

    @Test("failure evidence can support an explicitly failed state")
    func failureEvidenceCanSupportExplicitlyFailedState() {
        let failedBuild = VerificationRecord(area: "Build", state: .failed)
        let truthSnapshot = snapshot(verification: [
            failedBuild,
            VerificationRecord(area: "Automated Tests", state: .unknown),
            VerificationRecord(area: "Documentation", state: .unknown),
        ])
        let noEvidence = TruthEngine().confidence(snapshot: truthSnapshot, evidence: [], assumptions: [])
        let failureEvidence = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: [
                evidence("Build", "Release build fails during signing", .measured)
            ],
            assumptions: []
        )

        #expect(failureEvidence.score > noEvidence.score)
        #expect(failureEvidence.contributions.contains {
            $0.delta > 0 && $0.label.localizedCaseInsensitiveContains("strong evidence")
        })
        #expect(!failureEvidence.contributions.contains {
            $0.delta < 0 && $0.label.localizedCaseInsensitiveContains("failed evidence")
        })
    }

    private func snapshot(verification: [VerificationRecord]? = nil) -> RepoSnapshot {
        let applicability = releaseApplicability()
        var snapshot = RepoSnapshot.fixture(
            identity: ProjectIdentity(kind: .swiftPackage, detail: "Truth guard fixture", confidence: .observed),
            git: GitStatus(isRepository: true, branch: "main", hasUpstream: true)
        )
        snapshot.applicability = applicability
        snapshot.verification = verification ?? applicability.map {
            VerificationRecord(area: $0.area, state: .unknown)
        }
        return snapshot
    }

    private func releaseApplicability() -> [ApplicabilityItem] {
        [
            ApplicabilityItem(area: "Build", status: .required, priority: .critical),
            ApplicabilityItem(area: "Automated Tests", status: .required, priority: .high),
            ApplicabilityItem(area: "Documentation", status: .expected, priority: .medium),
        ]
    }

    private func evidence(
        _ area: String,
        _ summary: String,
        _ classification: EvidenceClassification
    ) -> EvidenceRecord {
        EvidenceRecord(area: area, summary: summary, classification: classification)
    }
}
