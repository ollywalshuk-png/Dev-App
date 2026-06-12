import Foundation
import Testing
@testable import LocalForgeCore

@Suite("PromptForge release readiness handoff")
struct PromptForgeReleaseReadinessHandoffTests {
    @Test("comprehensive handoff calls out blocked release claims and redacts register text")
    func comprehensiveHandoffCallsOutBlockedReleaseClaims() {
        let buildID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let signingID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let riskID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let verification = [
            VerificationRecord(id: buildID, area: "Build", state: .failed, note: "Archive failed"),
            VerificationRecord(id: signingID, area: "Signing", state: .unknown)
        ]
        let snapshot = releaseSnapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical),
                ApplicabilityItem(area: "Signing", status: .required, priority: .high)
            ],
            verification: verification,
            mission: nil
        )
        let risk = RiskRecord(
            id: riskID,
            title: "Notarisation uses password=supersecret",
            likelihood: .medium,
            impact: .critical,
            status: .open,
            linkedVerificationAreas: ["Signing"]
        )

        let text = PromptForgeEngine().generate(
            .comprehensiveHandoff,
            snapshot: snapshot,
            risks: [risk]
        )

        #expect(text.contains("## Release Claim Guard"))
        #expect(text.contains("Release claim: Blocked"))
        #expect(text.contains("Do not describe this handoff as release-ready"))
        #expect(text.contains("Truth debt:"))
        #expect(text.contains("Top blockers:"))
        #expect(text.contains("Build is failed"))
        #expect(text.contains("[REDACTED_SECRET]"))
        #expect(!text.contains("supersecret"))
        #expect(!text.contains(riskID.uuidString))
        #expect(!text.contains(buildID.uuidString))
    }

    @Test("defensible handoff avoids overclaiming release approval")
    func defensibleHandoffAvoidsOverclaimingReleaseApproval() {
        let buildID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let build = VerificationRecord(id: buildID, area: "Build", state: .verified)
        let evidence = EvidenceRecord(
            area: "Build",
            summary: "Release build passed locally",
            classification: .measured,
            linkedVerificationIDs: [buildID]
        )
        let snapshot = releaseSnapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical)
            ],
            verification: [build],
            mission: UserMissionProfile(
                statedMission: "Ship a local developer trust tool",
                category: .developerTool
            )
        )

        let text = PromptForgeEngine().generate(
            .comprehensiveHandoff,
            snapshot: snapshot,
            evidence: [evidence]
        )

        #expect(text.contains("## Release Claim Guard"))
        #expect(text.contains("Release claim: Defensible"))
        #expect(text.contains("No truth debt gates were detected"))
        #expect(text.contains("This is not a release approval"))
        #expect(text.contains("Top blockers:\n- None"))
        #expect(text.contains("Top caveats:\n- None"))
    }

    private func releaseSnapshot(
        applicability: [ApplicabilityItem],
        verification: [VerificationRecord],
        mission: UserMissionProfile?
    ) -> RepoSnapshot {
        var snapshot = RepoSnapshot.fixture(
            identity: ProjectIdentity(kind: .swiftUIApp, detail: "release handoff fixture", confidence: .observed),
            git: GitStatus(isRepository: true, branch: "main")
        )
        snapshot.project = ProjectContext(
            name: "LocalForge",
            rootURL: URL(fileURLWithPath: "/tmp/localforge-release-handoff"),
            permission: .approved(scopeDescription: "test")
        )
        snapshot.applicability = applicability
        snapshot.verification = verification
        snapshot.userMission = mission
        snapshot.mission = mission?.asMissionProfile() ?? .unknown
        snapshot.reality = RealityEngine().assess(
            identity: snapshot.identity,
            mission: snapshot.mission,
            applicability: applicability,
            git: snapshot.git,
            summary: snapshot.summary,
            findings: [],
            evidence: snapshot.evidence,
            verification: verification
        )
        return snapshot
    }
}
