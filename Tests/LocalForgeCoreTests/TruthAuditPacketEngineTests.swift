import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth audit packet engine")
struct TruthAuditPacketEngineTests {
    @Test("packet combines reality confidence register health provenance and truth debt")
    func packetCombinesTruthSections() {
        let build = VerificationRecord(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            area: "Build",
            state: .verified,
            updatedAt: freshDate
        )
        let runtime = VerificationRecord(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            area: "Runtime",
            state: .failed,
            updatedAt: freshDate
        )
        let docs = VerificationRecord(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            area: "Docs",
            state: .unknown
        )
        let evidence = EvidenceRecord(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            area: "Build",
            kind: .logExcerpt,
            summary: "Build passed",
            classification: .measured,
            linkedVerificationIDs: [build.id]
        )
        let risk = RiskRecord(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "Runtime exits early",
            likelihood: .medium,
            impact: .critical,
            status: .open,
            linkedVerificationAreas: ["Runtime"]
        )
        let assumption = AssumptionRecord(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            assumption: "Runtime mode remains enabled",
            status: .active,
            linkedVerificationArea: "Runtime",
            linkedRiskIDs: [risk.id]
        )
        let decision = DecisionRecord(title: "Ship only after runtime verification")
        let architecture = ArchitectureItem(
            name: "Runtime Core",
            linkedVerificationAreas: ["Runtime"]
        )
        let snapshot = snapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical),
                ApplicabilityItem(area: "Runtime", status: .required, priority: .high),
                ApplicabilityItem(area: "Docs", status: .expected, priority: .low)
            ],
            verification: [build, runtime, docs],
            reality: RealityAssessment(
                score: 62,
                currentState: "Runtime needs verification",
                knownFacts: [],
                verified: ["Build"],
                unverified: ["Runtime", "Docs"],
                assumptions: [],
                unknowns: [],
                topRisks: ["Runtime exits early"],
                nextAction: "Resolve Runtime and attach evidence.",
                chain: []
            )
        )

        let markdown = TruthAuditPacketEngine().markdownPacket(
            for: snapshot,
            evidence: [evidence],
            decisions: [decision],
            risks: [risk],
            architecture: [architecture],
            assumptions: [assumption],
            positiveContributionLimit: 2,
            negativeContributionLimit: 2,
            actionLimit: 3
        )
        let confidence = TruthEngine().confidence(
            snapshot: snapshot,
            evidence: [evidence],
            assumptions: [assumption]
        )
        let debtReport = TruthDebtEngine().report(
            snapshot: snapshot,
            evidence: [evidence],
            risks: [risk],
            assumptions: [assumption]
        )

        #expect(markdown.contains("# Truth Audit Packet"))
        #expect(markdown.contains("- Project: Fixture"))
        #expect(markdown.contains("- Reality: 62% - Runtime needs verification"))
        #expect(markdown.contains("- Next action: Resolve Runtime and attach evidence."))
        #expect(markdown.contains("- Score: \(confidence.score)% (\(confidence.label))"))
        #expect(markdown.contains("- Summary: \(confidence.summary)"))
        #expect(markdown.contains("## Confidence Warnings"))
        #expect(markdown.contains("- Weak confidence: \(confidence.score)% (\(confidence.label)) - \(confidence.summary) Drivers: 1 active assumption(s) (-4)"))
        #expect(markdown.contains("- Assumptions: 1 active assumption gate(s); 1 block release claims. Top: Runtime mode remains enabled"))
        #expect(markdown.contains("- Coverage: Evidence 33%, Risks 33%, Decisions 33%, Architecture 33%, Assumptions 50%"))
        #expect(markdown.contains("## Positive Provenance"))
        #expect(markdown.contains("| Verification 11111111 | Build | Verified | Fresh | Yes |"))
        #expect(markdown.contains("| Evidence 55555555 | Build | Measured | - | Yes |"))
        #expect(markdown.contains("## Negative Provenance"))
        #expect(markdown.contains("| Verification 22222222 | Runtime | Failed | Fresh | Yes |"))
        #expect(markdown.contains("| Risk 44444444 | Runtime | Open | - | Yes |"))
        #expect(markdown.contains("- Status: \(debtReport.status.rawValue)"))
        #expect(markdown.contains("- Headline: \(debtReport.headline)"))
        #expect(markdown.contains("- Blockers: \(debtReport.blockers.count)"))
        #expect(markdown.contains("- Caveats: \(debtReport.caveats.count)"))
        #expect(markdown.contains("## Next Actions"))
        #expect(markdown.contains("1. Mitigate, accept with explicit release rationale, or close this risk before claiming release-ready."))
    }

    @Test("packet ordering and limits are deterministic")
    func packetOrderingAndLimitsAreDeterministic() {
        let alpha = VerificationRecord(
            id: UUID(uuidString: "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa")!,
            area: "Alpha",
            state: .verified,
            updatedAt: freshDate
        )
        let beta = VerificationRecord(
            id: UUID(uuidString: "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb")!,
            area: "Beta",
            state: .verified,
            updatedAt: freshDate
        )
        let gamma = VerificationRecord(
            id: UUID(uuidString: "cccccccc-cccc-cccc-cccc-cccccccccccc")!,
            area: "Gamma",
            state: .failed,
            updatedAt: freshDate
        )
        let alphaEvidence = EvidenceRecord(
            id: UUID(uuidString: "dddddddd-dddd-dddd-dddd-dddddddddddd")!,
            area: "Alpha",
            summary: "Alpha observed",
            classification: .observed
        )
        let betaEvidence = EvidenceRecord(
            id: UUID(uuidString: "eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee")!,
            area: "Beta",
            summary: "Beta observed",
            classification: .observed
        )
        let risk = RiskRecord(
            id: UUID(uuidString: "ffffffff-ffff-ffff-ffff-ffffffffffff")!,
            title: "Gamma check failed",
            likelihood: .medium,
            impact: .high,
            status: .open,
            linkedVerificationAreas: ["Gamma"]
        )
        let assumption = AssumptionRecord(
            id: UUID(uuidString: "77777777-7777-7777-7777-777777777777")!,
            assumption: "Gamma can be recovered",
            status: .active,
            linkedVerificationArea: "Gamma",
            linkedRiskIDs: [risk.id]
        )
        let applicability = [
            ApplicabilityItem(area: "Beta", status: .required, priority: .critical),
            ApplicabilityItem(area: "Gamma", status: .required, priority: .high),
            ApplicabilityItem(area: "Alpha", status: .required, priority: .critical)
        ]
        let verification = [beta, gamma, alpha]
        let engine = TruthAuditPacketEngine()

        let forward = engine.markdownPacket(
            for: snapshot(applicability: applicability, verification: verification),
            evidence: [betaEvidence, alphaEvidence],
            risks: [risk],
            assumptions: [assumption],
            positiveContributionLimit: 1,
            negativeContributionLimit: 2,
            actionLimit: 2
        )
        let reversed = engine.markdownPacket(
            for: snapshot(applicability: Array(applicability.reversed()), verification: Array(verification.reversed())),
            evidence: [alphaEvidence, betaEvidence],
            risks: [risk],
            assumptions: [assumption],
            positiveContributionLimit: 1,
            negativeContributionLimit: 2,
            actionLimit: 2
        )

        #expect(forward == reversed)
        #expect(forward.contains("| Verification AAAAAAAA | Alpha | Verified | Fresh | Yes |"))
        #expect(!forward.contains("| Verification BBBBBBBB | Beta | Verified | Fresh | Yes |"))
        #expect(forward.contains("| Verification CCCCCCCC | Gamma | Failed | Fresh | Yes |"))
        #expect(forward.contains("| Risk FFFFFFFF | Gamma | Open | - | Yes |"))
    }

    @Test("packet warnings surface contradictions and stale evidence")
    func packetWarningsSurfaceContradictionsAndStaleEvidence() {
        let verification = VerificationRecord(
            id: UUID(uuidString: "13131313-1313-1313-1313-131313131313")!,
            area: "Build",
            state: .verified,
            updatedAt: expiredDate
        )
        let pass = EvidenceRecord(
            id: UUID(uuidString: "14141414-1414-1414-1414-141414141414")!,
            area: " build ",
            summary: "Build passes locally",
            classification: .observed
        )
        let fail = EvidenceRecord(
            id: UUID(uuidString: "15151515-1515-1515-1515-151515151515")!,
            area: "BUILD",
            summary: "Archive fails reproducibly",
            classification: .measured
        )
        let markdown = TruthAuditPacketEngine().markdownPacket(
            for: snapshot(
                applicability: [ApplicabilityItem(area: "Build", status: .required, priority: .critical)],
                verification: [verification]
            ),
            evidence: [pass, fail]
        )

        #expect(markdown.contains("## Confidence Warnings"))
        #expect(markdown.contains("- Contradictions: 1 contradictory evidence gate(s). Top: Contradictory evidence for build"))
        #expect(markdown.contains("- Stale evidence: 1 stale/expired verification gate(s). Top: Build verification is expired"))
        #expect(!markdown.contains("- None"))
    }

    @Test("packet redacts arbitrary text and paths")
    func packetRedactsArbitraryTextAndPaths() {
        let privateArea = "/Users/example/private/runtime.txt"
        let verification = VerificationRecord(
            id: UUID(uuidString: "12121212-1212-1212-1212-121212121212")!,
            area: privateArea,
            state: .failed,
            updatedAt: freshDate
        )
        var fixture = snapshot(
            projectName: "Audit api_key=abcdef123",
            applicability: [ApplicabilityItem(area: privateArea, status: .required, priority: .critical)],
            verification: [verification],
            reality: RealityAssessment(
                score: 12,
                currentState: "Token token=abcdef123 was captured",
                knownFacts: [],
                verified: [],
                unverified: [privateArea],
                assumptions: [],
                unknowns: [],
                topRisks: [],
                nextAction: "Rotate password=supersecret and review /Users/example/private/note.md",
                chain: []
            )
        )
        fixture.userMission = UserMissionProfile(statedMission: "Keep audit output safe")

        let markdown = TruthAuditPacketEngine().markdownPacket(
            for: fixture,
            negativeContributionLimit: 1,
            actionLimit: 1
        )

        #expect(markdown.contains("[REDACTED_SECRET]"))
        #expect(markdown.contains("[REDACTED_PRIVATE_PATH]"))
        #expect(!markdown.contains("api_key=abcdef123"))
        #expect(!markdown.contains("token=abcdef123"))
        #expect(!markdown.contains("supersecret"))
        #expect(!markdown.contains("/Users/example/private"))
    }

    private func snapshot(
        projectName: String = "Fixture",
        applicability: [ApplicabilityItem],
        verification: [VerificationRecord],
        reality: RealityAssessment = RealityAssessment(
            score: 70,
            currentState: "Checks are partly verified",
            knownFacts: [],
            verified: [],
            unverified: [],
            assumptions: [],
            unknowns: [],
            topRisks: [],
            nextAction: "Continue verification.",
            chain: []
        )
    ) -> RepoSnapshot {
        var snapshot = RepoSnapshot.fixture(
            identity: ProjectIdentity(kind: .swiftPackage, detail: "Fixture", confidence: .observed),
            git: GitStatus(isRepository: true, branch: "main")
        )
        snapshot.project = ProjectContext(
            name: projectName,
            rootURL: URL(fileURLWithPath: "/tmp/fixture"),
            permission: .approved(scopeDescription: "fixture")
        )
        snapshot.userMission = UserMissionProfile(statedMission: "Ship a verified developer tool")
        snapshot.mission = snapshot.userMission?.asMissionProfile() ?? .unknown
        snapshot.applicability = Array(applicability)
        snapshot.verification = Array(verification)
        snapshot.reality = reality
        return snapshot
    }
}

private let freshDate = Date(timeIntervalSince1970: 4_102_444_800)
private let expiredDate = Date(timeIntervalSince1970: 0)
