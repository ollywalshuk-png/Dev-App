import Foundation
import Testing
@testable import LocalForgeCore

@Suite("PromptForge truth debt handoffs")
struct PromptForgeTruthDebtTests {
    @Test("comprehensive handoff includes compact Truth Debt status and redacts record text")
    func comprehensiveHandoffIncludesTruthDebtAndRedactsRecords() {
        let fixture = blockedFixture()

        let text = PromptForgeEngine().generate(
            .comprehensiveHandoff,
            snapshot: fixture.snapshot,
            evidence: fixture.evidence,
            risks: fixture.risks,
            assumptions: fixture.assumptions
        )

        #expect(text.contains("## Truth Debt"))
        #expect(text.contains("TruthDebtEngine status: Blocked"))
        #expect(text.contains("Headline:"))
        #expect(text.contains("Blockers:"))
        #expect(text.contains("Caveats:"))
        #expect(text.contains("Release-claim boundary: Do not make a release claim until blockers are resolved."))
        #expect(text.contains("Top next actions:"))
        #expect(text.contains("[REDACTED_SECRET]"))
        #expect(text.contains("[REDACTED_PRIVATE_PATH]"))
        #expect(!text.contains(Self.secretToken))
        #expect(!text.contains(Self.privateAttachmentPath))
        #expect(!text.contains("password=supersecret"))
    }

    @Test("handoff sections expose compact Truth Debt section")
    func handoffSectionsExposeTruthDebtSection() throws {
        let fixture = blockedFixture()

        let sections = PromptForgeEngine().handoffSections(
            snapshot: fixture.snapshot,
            evidence: fixture.evidence,
            risks: fixture.risks,
            assumptions: fixture.assumptions
        )
        let truthDebt = try #require(sections.first { $0.title == "Truth Debt" })

        #expect(truthDebt.body.contains("TruthDebtEngine status: Blocked"))
        #expect(truthDebt.body.contains("Headline:"))
        #expect(truthDebt.body.contains("Blockers:"))
        #expect(truthDebt.body.contains("Caveats:"))
        #expect(truthDebt.body.contains("Top next actions:"))
    }

    @Test("blocked and caveated prompt boundaries avoid release-ready claims")
    func promptBoundariesAvoidReleaseReadyWhenNotDefensible() {
        let promptArtefacts: [PromptForgeEngine.Artefact] = [.codexPrompt, .claudePrompt, .reviewerBrief]
        let engine = PromptForgeEngine()
        let blocked = blockedFixture()

        for artefact in promptArtefacts {
            let text = engine.generate(
                artefact,
                snapshot: blocked.snapshot,
                evidence: blocked.evidence,
                risks: blocked.risks,
                assumptions: blocked.assumptions
            )

            #expect(text.contains("Truth Debt / release claim boundary"))
            #expect(text.contains("TruthDebtEngine status: Blocked"))
            #expect(text.contains("Do not make a release claim until blockers are resolved."))
            #expect(!text.lowercased().contains("release-ready"))
        }

        let caveated = caveatedFixture()
        for artefact in promptArtefacts {
            let text = engine.generate(
                artefact,
                snapshot: caveated.snapshot,
                evidence: caveated.evidence,
                risks: caveated.risks,
                assumptions: caveated.assumptions
            )

            #expect(text.contains("TruthDebtEngine status: Caveated"))
            #expect(text.contains("Only make qualified release claims while caveats remain."))
            #expect(!text.lowercased().contains("release-ready"))
        }
    }

    private func blockedFixture() -> PromptForgeDebtFixture {
        let buildID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let build = VerificationRecord(id: buildID, area: "Build", state: .verified)
        let docs = VerificationRecord(area: "Docs", state: .unknown)
        let evidence = [
            EvidenceRecord(
                area: "Build",
                summary: "Build passed with \(Self.secretToken)",
                body: "Captured output includes password=supersecret and no compiler errors.",
                attachmentPath: Self.privateAttachmentPath,
                classification: .observed,
                linkedVerificationIDs: [buildID]
            )
        ]
        let risk = RiskRecord(
            title: "Distribution leak \(Self.secretToken)",
            likelihood: .high,
            impact: .critical,
            status: .open,
            mitigation: "Rotate password=supersecret before sign-off.",
            linkedVerificationAreas: ["Build"]
        )
        let assumption = AssumptionRecord(
            assumption: "Release signing uses api_key=abcdef123456",
            verificationNeeded: "Verify signing locally",
            status: .active,
            linkedVerificationArea: "Build"
        )
        let snapshot = snapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical),
                ApplicabilityItem(area: "Docs", status: .expected, priority: .low)
            ],
            verification: [build, docs]
        )

        return PromptForgeDebtFixture(
            snapshot: snapshot,
            evidence: evidence,
            risks: [risk],
            assumptions: [assumption]
        )
    }

    private func caveatedFixture() -> PromptForgeDebtFixture {
        let buildID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let build = VerificationRecord(id: buildID, area: "Build", state: .verified)
        let docs = VerificationRecord(area: "Docs", state: .unknown)
        let evidence = [
            EvidenceRecord(
                area: "Build",
                summary: "Build passed locally",
                classification: .measured,
                linkedVerificationIDs: [buildID]
            )
        ]
        let snapshot = snapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical),
                ApplicabilityItem(area: "Docs", status: .expected, priority: .low)
            ],
            verification: [build, docs]
        )

        return PromptForgeDebtFixture(
            snapshot: snapshot,
            evidence: evidence,
            risks: [],
            assumptions: []
        )
    }

    private func snapshot(
        applicability: [ApplicabilityItem],
        verification: [VerificationRecord]
    ) -> RepoSnapshot {
        let mission = UserMissionProfile(
            statedMission: "Ship a local-first developer trust tool",
            category: .developerTool,
            goals: ["evidence-led handoffs"],
            currentPhase: "release hardening"
        )
        let identity = ProjectIdentity(kind: .swiftPackage, detail: "Fixture", confidence: .observed)
        var snapshot = RepoSnapshot.fixture(
            identity: identity,
            git: GitStatus(isRepository: true, branch: "main")
        )
        snapshot.project = ProjectContext(
            name: "LocalForge",
            rootURL: URL(fileURLWithPath: "/tmp/localforge"),
            permission: .approved(scopeDescription: "fixture")
        )
        snapshot.userMission = mission
        snapshot.mission = mission.asMissionProfile()
        snapshot.applicability = applicability
        snapshot.verification = verification
        snapshot.reality = RealityEngine().assess(
            identity: identity,
            mission: snapshot.mission,
            applicability: applicability,
            git: snapshot.git,
            summary: snapshot.summary,
            findings: [],
            evidence: [],
            verification: verification
        )
        return snapshot
    }

    private static let secretToken = "LOCAL_SECRET_VALUE_123456"
    private static let privateAttachmentPath = "/Users/chrisizatt/Secrets/build.log"
}

private struct PromptForgeDebtFixture {
    var snapshot: RepoSnapshot
    var evidence: [EvidenceRecord]
    var risks: [RiskRecord]
    var assumptions: [AssumptionRecord]
}
