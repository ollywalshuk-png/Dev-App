import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth score accuracy")
struct TruthScoreAccuracyTests {
    @Test("duplicate verified records do not inflate reality score")
    func duplicateVerifiedRecordsDoNotInflateScore() {
        let now = Date()
        let build = VerificationRecord(area: "Build", state: .verified, updatedAt: now)
        let tests = VerificationRecord(area: "Automated Tests", state: .unknown, updatedAt: now)

        let baseline = assess(verification: [build, tests])
        let duplicated = assess(verification: [build, build, tests])

        #expect(duplicated.score == baseline.score)
    }

    @Test("out-of-scope verification records cannot pad the score")
    func outOfScopeVerificationRecordsDoNotScore() {
        let now = Date()
        let baseline = assess(verification: [
            VerificationRecord(area: "Build", state: .unknown, updatedAt: now),
            VerificationRecord(area: "Automated Tests", state: .unknown, updatedAt: now)
        ])
        let padded = assess(verification: [
            VerificationRecord(area: "Build", state: .unknown, updatedAt: now),
            VerificationRecord(area: "Automated Tests", state: .unknown, updatedAt: now),
            VerificationRecord(area: "Marketing Site", state: .verified, updatedAt: now),
            VerificationRecord(area: "Launch Copy", state: .verified, updatedAt: now)
        ])

        #expect(padded.score == baseline.score)
    }

    @Test("contradictory critical verification fails closed")
    func contradictoryCriticalVerificationFailsClosed() {
        let now = Date()
        let failedBuild = VerificationRecord(area: "Build", state: .failed, updatedAt: now)
        let laterVerifiedBuild = VerificationRecord(area: "Build", state: .verified, updatedAt: now.addingTimeInterval(60))
        let tests = VerificationRecord(area: "Automated Tests", state: .verified, updatedAt: now)

        let failedOnly = assess(verification: [failedBuild, tests])
        let contradictory = assess(verification: [failedBuild, laterVerifiedBuild, tests])

        #expect(contradictory.score == failedOnly.score)
        #expect(contradictory.score <= 72)
    }

    @Test("open critical risk caps an otherwise verified score")
    func openCriticalRiskCapsVerifiedScore() {
        let now = Date()
        let verified = [
            VerificationRecord(area: "Build", state: .verified, updatedAt: now),
            VerificationRecord(area: "Automated Tests", state: .verified, updatedAt: now)
        ]

        let baseline = assess(verification: verified)
        let withCriticalRisk = assess(
            verification: verified,
            risks: [RiskRecord(title: "Release blocker", impact: .critical, status: .open)]
        )

        #expect(withCriticalRisk.score < baseline.score)
        #expect(withCriticalRisk.score <= 82)
    }

    @Test("active assumptions cap an otherwise verified score")
    func activeAssumptionsCapVerifiedScore() {
        let now = Date()
        let verified = [
            VerificationRecord(area: "Build", state: .verified, updatedAt: now),
            VerificationRecord(area: "Automated Tests", state: .verified, updatedAt: now)
        ]
        let assumptions = [
            AssumptionRecord(assumption: "Host restores state"),
            AssumptionRecord(assumption: "Toolchain is stable"),
            AssumptionRecord(assumption: "Test fixture covers release path")
        ]

        let withAssumptions = assess(verification: verified, assumptions: assumptions)

        #expect(withAssumptions.score <= 88)
    }

    private func assess(
        verification: [VerificationRecord],
        risks: [RiskRecord] = [],
        assumptions: [AssumptionRecord] = []
    ) -> RealityAssessment {
        RealityEngine().assess(
            identity: ProjectIdentity(kind: .swiftPackage, detail: "", confidence: .observed),
            mission: UserMissionProfile(statedMission: "Release-grade developer tool", category: .developerTool).asMissionProfile(),
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical),
                ApplicabilityItem(area: "Automated Tests", status: .required, priority: .high)
            ],
            git: GitStatus(isRepository: true, branch: "main"),
            summary: RepoSummary(totalFiles: 12, sourceFiles: 8),
            findings: [],
            evidence: [],
            verification: verification,
            riskRecords: risks,
            assumptionRecords: assumptions
        )
    }
}
