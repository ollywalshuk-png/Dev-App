import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth Centre adversarial stress tests")
struct TruthAdversarialStressTests {
    @Test("irrelevant and duplicate evidence cannot pad the Reality percentage")
    func irrelevantAndDuplicateEvidenceCannotPadRealityPercentage() {
        let verification = [
            record("Build", .verified),
            record("Automated Tests", .unknown),
            record("Signing", .unknown),
        ]
        let baselineEvidence = [
            evidence("Build", "Build log captured", .measured),
        ]
        let baseline = assess(verification: verification, evidenceRecords: baselineEvidence)

        let noisyEvidence = baselineEvidence
            + duplicateEvidence(baselineEvidence[0], count: 50)
            + (0..<120).map { index in
                evidence("Marketing Site \(index)", "Launch page checked \(index)", .verified)
            }
            + (0..<120).map { index in
                evidence("Launch Copy \(index)", "Release copy presumed fine \(index)", .assumed)
            }
        let noisyVerification = verification
            + duplicateRecords(verification[0], count: 50)
            + (0..<120).map { index in
                record("Marketing Site \(index)", .verified)
            }

        let noisy = assess(verification: noisyVerification, evidenceRecords: noisyEvidence)

        #expect(noisy.score == baseline.score)
        #expect(noisy.verified.contains { $0.localizedCaseInsensitiveContains("Marketing Site") })
    }

    @Test("stale verified records stay below fresh release evidence")
    func staleVerifiedRecordsStayBelowFreshReleaseEvidence() {
        let freshVerification = releaseApplicability().map { record($0.area, .verified) }
        let staleVerification = releaseApplicability().map {
            record($0.area, .verified, updatedAt: Date().addingTimeInterval(-120 * day))
        }
        let staleNoise = staleVerification
            + duplicateRecords(staleVerification[0], count: 40)
            + (0..<80).map { index in
                record("Old Marketing Approval \(index)", .verified, updatedAt: Date().addingTimeInterval(-120 * day))
            }

        let fresh = assess(verification: freshVerification)
        let stale = assess(verification: staleVerification)
        let staleWithNoise = assess(
            verification: staleNoise,
            evidenceRecords: (0..<80).map { index in
                evidence("Old Marketing Approval \(index)", "Historical approval \(index)", .verified)
            }
        )
        let breakdown = TruthEngine().breakdown(
            snapshot: snapshot(verification: staleVerification, reality: stale),
            evidence: [],
            risks: [],
            assumptions: []
        )

        #expect(stale.score < fresh.score)
        #expect(staleWithNoise.score == stale.score)
        #expect(breakdown.negatives.contains { $0.label.localizedCaseInsensitiveContains("stale verified") })
    }

    @Test("conflicting verification fails closed despite later positive records")
    func conflictingVerificationFailsClosedDespiteLaterPositiveRecords() {
        let failedBuild = record("Build", .failed, updatedAt: Date().addingTimeInterval(-2 * day))
        let laterVerifiedBuild = record("Build", .verified, updatedAt: Date().addingTimeInterval(-day))
        let verifiedTests = record("Automated Tests", .verified)
        let evidenceRecords = [
            evidence("Build", "Build failed during release rehearsal", .observed),
            evidence("Build", "Build passed on a different machine", .observed),
            evidence("Automated Tests", "Tests passed", .measured),
        ]

        let failedOnly = assess(
            verification: [failedBuild, verifiedTests],
            evidenceRecords: evidenceRecords
        )
        let contradictory = assess(
            verification: [failedBuild, laterVerifiedBuild, verifiedTests],
            evidenceRecords: evidenceRecords + duplicateEvidence(evidenceRecords[1], count: 30)
        )
        let verifiedOnly = assess(
            verification: [laterVerifiedBuild, verifiedTests],
            evidenceRecords: evidenceRecords
        )

        #expect(contradictory.score == failedOnly.score)
        #expect(contradictory.score < verifiedOnly.score)
        #expect(contradictory.topRisks.contains { $0.localizedCaseInsensitiveContains("Build") })
    }

    @Test("confidence percentage is not inflated by adversarial evidence noise")
    func confidencePercentageIsNotInflatedByAdversarialEvidenceNoise() {
        let verification = [
            record("Build", .verified),
            record("Automated Tests", .verified),
            record("Signing", .unknown),
            record("Documentation", .unknown),
        ]
        let reality = assess(verification: verification)
        let truthSnapshot = snapshot(verification: verification, reality: reality)
        let baselineEvidence = [
            evidence("Build", "Build log captured", .measured),
            evidence("Automated Tests", "Test output captured", .measured),
        ]
        let baseline = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: baselineEvidence,
            assumptions: []
        )

        let duplicateNoise = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: baselineEvidence + duplicateEvidence(baselineEvidence[0], count: 20),
            assumptions: []
        )
        let outOfScopeNoise = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: baselineEvidence + (0..<20).map { index in
                evidence("Marketing Site \(index)", "Launch page checked \(index)", .verified)
            },
            assumptions: []
        )
        let conflictingNoise = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: baselineEvidence + [
                evidence("Build", "Build failed during release rehearsal", .observed),
            ],
            assumptions: []
        )

        #expect(
            duplicateNoise.score <= baseline.score,
            "Duplicate copies of the same strong evidence must not raise confidence from \(baseline.score) to \(duplicateNoise.score)."
        )
        #expect(
            outOfScopeNoise.score <= baseline.score,
            "Out-of-scope strong evidence must not raise confidence from \(baseline.score) to \(outOfScopeNoise.score)."
        )
        #expect(
            conflictingNoise.score <= baseline.score,
            "Contradictory strong evidence must not raise confidence from \(baseline.score) to \(conflictingNoise.score)."
        )
    }

    private var day: TimeInterval { 86_400 }

    private func assess(
        verification: [VerificationRecord],
        evidenceRecords: [EvidenceRecord] = []
    ) -> RealityAssessment {
        RealityEngine().assess(
            identity: identity(),
            mission: mission(),
            applicability: releaseApplicability(),
            git: GitStatus(isRepository: true, branch: "main", hasUpstream: true),
            summary: RepoSummary(totalFiles: 64, sourceFiles: 34, testFiles: 12, documentationFiles: 8),
            findings: [],
            evidence: [
                Evidence(
                    title: "Approved release fixture",
                    detail: "/tmp/localforge-truth-adversarial",
                    classification: .observed,
                    source: "TruthAdversarialStressTests"
                )
            ],
            verification: verification,
            evidenceRecords: evidenceRecords
        )
    }

    private func snapshot(
        verification: [VerificationRecord],
        reality: RealityAssessment
    ) -> RepoSnapshot {
        var snapshot = RepoSnapshot.fixture(
            identity: identity(),
            git: GitStatus(isRepository: true, branch: "main", hasUpstream: true)
        )
        snapshot.project = ProjectContext(
            name: "Truth Adversarial Fixture",
            rootURL: URL(fileURLWithPath: "/tmp/localforge-truth-adversarial"),
            permission: .approved(scopeDescription: "Truth adversarial stress fixture")
        )
        snapshot.summary = RepoSummary(totalFiles: 64, sourceFiles: 34, testFiles: 12, documentationFiles: 8)
        snapshot.mission = mission()
        snapshot.userMission = UserMissionProfile(
            statedMission: "Ship a release-grade developer tool",
            category: .developerTool,
            currentPhase: "Release hardening"
        )
        snapshot.applicability = releaseApplicability()
        snapshot.verification = verification
        snapshot.reality = reality
        return snapshot
    }

    private func releaseApplicability() -> [ApplicabilityItem] {
        [
            ApplicabilityItem(area: "Build", status: .required, priority: .critical),
            ApplicabilityItem(area: "Automated Tests", status: .required, priority: .high),
            ApplicabilityItem(area: "Signing", status: .expected, priority: .high),
            ApplicabilityItem(area: "Documentation", status: .expected, priority: .low),
            ApplicabilityItem(area: "Marketing Site", status: .notApplicable, priority: .low),
        ]
    }

    private func identity() -> ProjectIdentity {
        ProjectIdentity(
            kind: .swiftPackage,
            detail: "Synthetic release fixture",
            ecosystems: ["SwiftPM"],
            markers: ["Package.swift"],
            confidence: .observed
        )
    }

    private func mission() -> MissionProfile {
        UserMissionProfile(
            statedMission: "Ship a release-grade developer tool",
            category: .developerTool,
            currentPhase: "Release hardening"
        ).asMissionProfile()
    }

    private func record(
        _ area: String,
        _ state: VerificationState,
        updatedAt: Date = Date().addingTimeInterval(-86_400)
    ) -> VerificationRecord {
        VerificationRecord(area: area, state: state, updatedAt: updatedAt)
    }

    private func evidence(
        _ area: String,
        _ summary: String,
        _ classification: EvidenceClassification
    ) -> EvidenceRecord {
        EvidenceRecord(area: area, summary: summary, classification: classification)
    }

    private func duplicateRecords(_ record: VerificationRecord, count: Int) -> [VerificationRecord] {
        Array(repeating: record, count: count)
    }

    private func duplicateEvidence(_ record: EvidenceRecord, count: Int) -> [EvidenceRecord] {
        Array(repeating: record, count: count)
    }
}
