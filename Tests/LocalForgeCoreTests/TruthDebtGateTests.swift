import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth debt gates")
struct TruthDebtGateTests {
    @Test("critical and high truth debt blocks release-ready claims")
    func criticalAndHighTruthDebtBlocksReleaseClaims() {
        let build = VerificationRecord(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            area: "Build",
            state: .verified,
            updatedAt: Date().addingTimeInterval(-220 * day)
        )
        let signing = VerificationRecord(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            area: "Signing",
            state: .unknown
        )
        var snapshot = snapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical),
                ApplicabilityItem(area: "Signing", status: .required, priority: .high)
            ],
            verification: [build, signing],
            mission: nil
        )
        snapshot.reality = RealityAssessment.unknown

        let risk = RiskRecord(
            title: "Notarisation fails on clean machine",
            likelihood: .medium,
            impact: .critical,
            status: .open,
            linkedVerificationAreas: ["Signing"]
        )
        let assumption = AssumptionRecord(
            assumption: "Signing profile is installed",
            status: .active,
            linkedVerificationArea: "Signing",
            linkedRiskIDs: [risk.id]
        )

        let report = TruthDebtEngine().report(
            snapshot: snapshot,
            evidence: [],
            risks: [risk],
            assumptions: [assumption]
        )

        #expect(report.status == .blocked)
        #expect(!report.isReleaseClaimDefensible)
        #expect(report.blockers.count >= 5)
        #expect(report.gates.contains { $0.kind == .missingMission })
        #expect(report.gates.contains { $0.kind == .staleVerification && $0.area == "Build" })
        #expect(report.gates.contains { $0.kind == .missingEvidence && $0.area == "Build" })
        #expect(report.gates.contains { $0.kind == .unverifiedArea && $0.area == "Signing" })
        #expect(report.gates.contains { $0.kind == .releaseBlockingRisk && $0.title == risk.title })
        #expect(report.gates.contains { $0.kind == .activeAssumption && $0.blocksReleaseClaim })
        #expect(report.headline.contains("block"))
        #expect(!report.nextActions.isEmpty)
    }

    @Test("low priority truth debt is caveated without blocking release claim")
    func lowPriorityDebtIsCaveated() {
        let build = VerificationRecord(area: "Build", state: .verified)
        let docs = VerificationRecord(area: "Docs", state: .unknown)
        let buildEvidence = EvidenceRecord(area: "Build", summary: "Build passed", classification: .measured)
        let snapshot = snapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical),
                ApplicabilityItem(area: "Docs", status: .expected, priority: .low)
            ],
            verification: [build, docs],
            mission: UserMissionProfile(statedMission: "Ship a developer trust tool", category: .developerTool)
        )

        let report = TruthDebtEngine().report(
            snapshot: snapshot,
            evidence: [buildEvidence],
            risks: [],
            assumptions: []
        )

        #expect(report.status == .caveated)
        #expect(report.isReleaseClaimDefensible)
        #expect(report.blockers.isEmpty)
        #expect(report.caveats.count == 1)
        #expect(report.caveats.first?.kind == .unverifiedArea)
        #expect(report.caveats.first?.area == "Docs")
    }

    @Test("contradictory evidence blocks critical release claims")
    func contradictoryEvidenceBlocksCriticalClaims() {
        let verification = VerificationRecord(area: "Build", state: .verified)
        let pass = EvidenceRecord(
            area: "Build",
            summary: "Build passes locally",
            classification: .observed
        )
        let fail = EvidenceRecord(
            area: "Build",
            summary: "Build fails during archive",
            classification: .measured
        )
        let snapshot = snapshot(
            applicability: [ApplicabilityItem(area: "Build", status: .required, priority: .critical)],
            verification: [verification],
            mission: UserMissionProfile(statedMission: "Ship a developer trust tool", category: .developerTool)
        )

        let report = TruthDebtEngine().report(
            snapshot: snapshot,
            evidence: [pass, fail],
            risks: [],
            assumptions: []
        )

        #expect(report.status == .blocked)
        #expect(report.gates.contains {
            $0.kind == .contradictoryEvidence
                && $0.area == "Build"
                && $0.blocksReleaseClaim
                && $0.sourceIdentifiers.contains(pass.id.uuidString)
                && $0.sourceIdentifiers.contains(fail.id.uuidString)
        })
    }

    @Test("dependency failures are surfaced as claim blockers")
    func dependencyFailuresAreClaimBlockers() {
        let preset = VerificationRecord(area: "Preset System", state: .failed)
        let auValidation = VerificationRecord(
            area: "AU Validation",
            state: .unknown,
            dependsOn: ["Preset System"]
        )
        let snapshot = snapshot(
            applicability: [
                ApplicabilityItem(area: "Preset System", status: .required, priority: .high),
                ApplicabilityItem(area: "AU Validation", status: .required, priority: .critical)
            ],
            verification: [preset, auValidation],
            mission: UserMissionProfile(statedMission: "Ship a verified AUv3 instrument", category: .instrument)
        )

        let report = TruthDebtEngine().report(
            snapshot: snapshot,
            evidence: [],
            risks: [],
            assumptions: []
        )

        #expect(report.status == .blocked)
        #expect(report.gates.contains {
            $0.kind == .blockedDependency
                && $0.area == "AU Validation"
                && $0.detail.contains("Preset System")
                && $0.detail.contains("Failed")
                && $0.blocksReleaseClaim
        })
    }

    private func snapshot(
        applicability: [ApplicabilityItem],
        verification: [VerificationRecord],
        mission: UserMissionProfile?
    ) -> RepoSnapshot {
        var snapshot = RepoSnapshot.fixture(
            identity: ProjectIdentity(kind: .swiftPackage, detail: "Fixture", confidence: .observed),
            git: GitStatus(isRepository: true, branch: "main")
        )
        snapshot.userMission = mission
        snapshot.mission = mission?.asMissionProfile() ?? .unknown
        snapshot.applicability = applicability
        snapshot.verification = verification
        return snapshot
    }
}

private let day: TimeInterval = 86_400
