import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Reality calibration edge tests")
struct RealityCalibrationEdgeTests {
    @Test("unknown critical and high areas cannot look healthy beside low-priority wins")
    func unknownCriticalAndHighAreasCannotLookHealthyBesideLowPriorityWins() {
        let verification = [
            verificationRecord("Build", .unknown),
            verificationRecord("Automated Tests", .unknown),
            verificationRecord("Documentation", .verified),
            verificationRecord("Changelog", .verified),
        ]

        let reality = assess(verification: verification)

        #expect(reality.score < 55)
        #expect(reality.unverified.contains { $0.localizedCaseInsensitiveContains("Build") })
        #expect(reality.unverified.contains { $0.localizedCaseInsensitiveContains("Automated Tests") })
        #expect(reality.topRisks.contains { $0.localizedCaseInsensitiveContains("build") })
        #expect(reality.nextAction.localizedCaseInsensitiveContains("Build"))
        #expect(reality.chain.contains { $0.stage == .verified && $0.state != .reached })
    }

    @Test("verified area matching normalizes reality risks and next action")
    func verifiedAreaMatchingNormalizesRealityRisksAndNextAction() {
        let verification = [
            verificationRecord(" build ", .verified),
            verificationRecord("AUTOMATED TESTS", .verified),
            verificationRecord("Documentation", .verified),
            verificationRecord("Changelog", .verified),
        ]

        let reality = assess(verification: verification)

        #expect(!reality.topRisks.contains {
            $0.localizedCaseInsensitiveContains("No verified evidence that build")
        })
        #expect(!reality.topRisks.contains {
            $0.localizedCaseInsensitiveContains("No verified evidence that automated tests")
        })
        #expect(reality.nextAction.localizedCaseInsensitiveContains("All in-scope areas"))
    }

    @Test("weak evidence does not lift confidence like strong evidence")
    func weakEvidenceDoesNotLiftConfidenceLikeStrongEvidence() {
        let verification = releaseApplicability().map { verificationRecord($0.area, .unknown) }
        let reality = assess(verification: verification)
        let truthSnapshot = snapshot(verification: verification, reality: reality)
        let weakEvidence = [
            evidence("Build", "Build green by assumption", .assumed),
            evidence("Automated Tests", "No current test output", .unknown),
            evidence("Documentation", "Docs presumed current", .assumed),
            evidence("Changelog", "Release notes not checked", .unknown),
        ]
        let strongEvidence = [
            evidence("Build", "Build log captured", .observed),
            evidence("Automated Tests", "Test run measured", .measured),
            evidence("Documentation", "Docs reviewed", .verified),
            evidence("Changelog", "Release notes observed", .observed),
        ]

        let weakConfidence = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: weakEvidence,
            assumptions: []
        )
        let strongConfidence = TruthEngine().confidence(
            snapshot: truthSnapshot,
            evidence: strongEvidence,
            assumptions: []
        )

        #expect(weakConfidence.score <= 30)
        #expect(strongConfidence.score >= 70)
        #expect(strongConfidence.score > weakConfidence.score + 40)
        #expect(weakConfidence.contributions.contains {
            $0.delta < 0 && $0.label.localizedCaseInsensitiveContains("weak evidence")
        })
        #expect(strongConfidence.contributions.contains {
            $0.delta > 0 && $0.label.localizedCaseInsensitiveContains("strong evidence")
        })
    }

    @Test("expired verified records stay visible as negative provenance")
    func expiredVerifiedRecordsStayVisibleAsNegativeProvenance() {
        let applicability = [
            ApplicabilityItem(area: "Build", status: .required, priority: .critical)
        ]
        let fresh = verificationRecord("Build", .verified, updatedAt: Date().addingTimeInterval(-day))
        let expired = verificationRecord("Build", .verified, updatedAt: Date().addingTimeInterval(-220 * day))

        let freshReality = assess(applicability: applicability, verification: [fresh])
        let expiredReality = assess(applicability: applicability, verification: [expired])
        let provenance = TruthEngine().contributionProvenance(
            snapshot: snapshot(applicability: applicability, verification: [expired], reality: expiredReality),
            evidence: [],
            risks: [],
            assumptions: []
        )

        #expect(expiredReality.score < freshReality.score)
        #expect(provenance.contains {
            $0.sourceKind == .verification
                && $0.sourceArea == "Build"
                && $0.direction == .negative
                && $0.freshness == .expired
                && $0.releaseRelevant
        })
    }

    @Test("release-blocking risks and active assumptions constrain optimistic claims")
    func releaseBlockingRisksAndActiveAssumptionsConstrainOptimisticClaims() {
        let applicability = [
            ApplicabilityItem(area: "Build", status: .required, priority: .critical),
            ApplicabilityItem(area: "Automated Tests", status: .required, priority: .high),
        ]
        let verification = applicability.map { verificationRecord($0.area, .verified) }
        let releaseRisk = RiskRecord(
            title: "Flaky tests can ship a broken release",
            likelihood: .high,
            impact: .high,
            status: .open,
            linkedVerificationAreas: ["Automated Tests"]
        )
        let assumptions = [
            AssumptionRecord(assumption: "Signing profile is installed", linkedVerificationArea: "Build"),
            AssumptionRecord(assumption: "CI uses the same Swift version", linkedVerificationArea: "Automated Tests"),
            AssumptionRecord(assumption: "Release fixture matches production", linkedVerificationArea: "Build"),
        ]

        let baseline = assess(applicability: applicability, verification: verification)
        let constrained = assess(
            applicability: applicability,
            verification: verification,
            risks: [releaseRisk],
            assumptions: assumptions
        )
        let provenance = TruthEngine().contributionProvenance(
            snapshot: snapshot(applicability: applicability, verification: verification, reality: constrained),
            evidence: [],
            risks: [releaseRisk],
            assumptions: assumptions
        )

        #expect(constrained.score < baseline.score)
        #expect(constrained.score <= 88)
        #expect(constrained.topRisks.contains { $0.localizedCaseInsensitiveContains("Release risk") })
        #expect(constrained.unknowns.contains { $0.localizedCaseInsensitiveContains("active assumption") })
        let hasReleaseRiskProvenance = provenance.contains { row in
            row.sourceKind == TruthContributionSourceKind.risk
                && row.direction == TruthContributionDirection.negative
                && row.releaseRelevant
        }
        let releaseRelevantAssumptionCount = provenance.filter { row in
            row.sourceKind == TruthContributionSourceKind.assumption
                && row.direction == TruthContributionDirection.negative
                && row.releaseRelevant
        }.count

        #expect(hasReleaseRiskProvenance)
        #expect(releaseRelevantAssumptionCount == assumptions.count)
    }

    @Test("out-of-scope records and evidence cannot pad the reality score")
    func outOfScopeRecordsAndEvidenceCannotPadRealityScore() {
        let applicability = [
            ApplicabilityItem(area: "Build", status: .required, priority: .critical),
            ApplicabilityItem(area: "Automated Tests", status: .required, priority: .high),
            ApplicabilityItem(area: "Marketing Site", status: .notApplicable, priority: .low),
            ApplicabilityItem(area: "Launch Copy", status: .optional, priority: .low),
        ]
        let baselineVerification = [
            verificationRecord("Build", .unknown),
            verificationRecord("Automated Tests", .unknown),
        ]
        let paddedVerification = baselineVerification + [
            verificationRecord("Marketing Site", .verified),
            verificationRecord("Launch Copy", .verified),
        ]
        let outOfScopeEvidence = [
            evidence("Marketing Site", "Landing page checked", .verified),
            evidence("Launch Copy", "Announcement copy reviewed", .observed),
        ]

        let baseline = assess(applicability: applicability, verification: baselineVerification)
        let padded = assess(
            applicability: applicability,
            verification: paddedVerification,
            evidenceRecords: outOfScopeEvidence
        )
        let provenance = TruthEngine().contributionProvenance(
            snapshot: snapshot(applicability: applicability, verification: paddedVerification, reality: padded),
            evidence: outOfScopeEvidence,
            risks: [],
            assumptions: []
        )

        #expect(padded.score == baseline.score)
        #expect(padded.verified.contains { $0.localizedCaseInsensitiveContains("Marketing Site") })
        #expect(provenance.filter { $0.sourceKind == .evidence }.allSatisfy { !$0.releaseRelevant })
        #expect(provenance.filter { $0.sourceKind == .verification && $0.direction == .positive }.allSatisfy {
            !$0.releaseRelevant
        })
    }

    private var day: TimeInterval { 86_400 }

    private func assess(
        applicability: [ApplicabilityItem]? = nil,
        verification: [VerificationRecord],
        evidenceRecords: [EvidenceRecord] = [],
        risks: [RiskRecord] = [],
        assumptions: [AssumptionRecord] = []
    ) -> RealityAssessment {
        let applicability = applicability ?? releaseApplicability()
        return RealityEngine().assess(
            identity: ProjectIdentity(kind: .swiftPackage, detail: "Release fixture", confidence: .observed),
            mission: releaseMission(),
            applicability: applicability,
            git: GitStatus(isRepository: true, branch: "main", hasUpstream: true),
            summary: RepoSummary(totalFiles: 40, sourceFiles: 18, testFiles: 8, documentationFiles: 5),
            findings: [],
            evidence: [
                Evidence(
                    title: "Approved release fixture",
                    detail: "/tmp/localforge-release-fixture",
                    classification: .observed,
                    source: "RealityCalibrationEdgeTests"
                )
            ],
            verification: verification,
            evidenceRecords: evidenceRecords,
            riskRecords: risks,
            assumptionRecords: assumptions
        )
    }

    private func snapshot(
        applicability: [ApplicabilityItem]? = nil,
        verification: [VerificationRecord],
        reality: RealityAssessment
    ) -> RepoSnapshot {
        let applicability = applicability ?? releaseApplicability()
        var snapshot = RepoSnapshot.fixture(
            identity: ProjectIdentity(kind: .swiftPackage, detail: "Release fixture", confidence: .observed),
            git: GitStatus(isRepository: true, branch: "main", hasUpstream: true)
        )
        snapshot.project = ProjectContext(
            name: "Release Fixture",
            rootURL: URL(fileURLWithPath: "/tmp/localforge-release-fixture"),
            permission: .approved(scopeDescription: "Reality calibration fixture")
        )
        snapshot.summary = RepoSummary(totalFiles: 40, sourceFiles: 18, testFiles: 8, documentationFiles: 5)
        snapshot.mission = releaseMission()
        snapshot.userMission = UserMissionProfile(
            statedMission: "Ship a release-grade developer tool",
            category: .developerTool,
            currentPhase: "Release calibration"
        )
        snapshot.applicability = applicability
        snapshot.verification = verification
        snapshot.reality = reality
        return snapshot
    }

    private func releaseApplicability() -> [ApplicabilityItem] {
        [
            ApplicabilityItem(area: "Build", status: .required, priority: .critical),
            ApplicabilityItem(area: "Automated Tests", status: .required, priority: .high),
            ApplicabilityItem(area: "Documentation", status: .expected, priority: .low),
            ApplicabilityItem(area: "Changelog", status: .expected, priority: .low),
        ]
    }

    private func releaseMission() -> MissionProfile {
        UserMissionProfile(
            statedMission: "Ship a release-grade developer tool",
            category: .developerTool,
            currentPhase: "Release calibration"
        ).asMissionProfile()
    }

    private func verificationRecord(
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
}
