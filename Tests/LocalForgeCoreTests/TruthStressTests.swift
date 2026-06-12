import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth Centre stress regression tests")
struct TruthStressTests {
    @Test("fully unknown project cannot look healthy")
    func fullyUnknownProjectCannotLookHealthy() {
        let reality = RealityEngine().assess(
            identity: .unknown,
            mission: .unknown,
            applicability: [],
            git: .unknown,
            summary: RepoSummary(),
            findings: [],
            evidence: []
        )

        #expect(reality.score <= 30)
        #expect(reality.currentState == "Unrecognised")
        #expect(reality.verified.isEmpty)
        #expect(reality.chain.contains { $0.stage == .verified && $0.state == .notReached })
        #expect(reality.unknowns.contains { $0.localizedCaseInsensitiveContains("Build state is unknown") })
    }

    @Test("critical coverage lifts score but preserves lower priority caveats")
    func criticalCoveragePreservesCaveats() {
        let applicability = audioUnitApplicability()
        let unknownRecords = records(for: applicability, state: .unknown)
        let criticalRecords = records(for: applicability, state: .verified) {
            $0.status.inScope && $0.priority == .critical
        }

        let unknownReality = assess(applicability: applicability, verification: unknownRecords)
        let criticalReality = assess(applicability: applicability, verification: criticalRecords)
        let snapshot = snapshot(
            applicability: applicability,
            verification: criticalRecords,
            reality: criticalReality
        )
        let board = ReleaseReadinessEngine().board(for: snapshot)

        #expect(!criticalRecords.isEmpty)
        #expect(criticalReality.score > unknownReality.score)
        #expect(criticalReality.score >= 80)
        #expect(board.criticalRemaining == 0)
        #expect(board.highRemaining == 0)
        #expect(board.status == .readyWithCaveats)
        #expect(board.rows.contains { $0.priority != .critical && $0.state == .unknown })
        #expect(criticalReality.chain.contains { $0.stage == .verified && $0.state != .reached })
    }

    @Test("full fresh verification outranks critical-only verification")
    func fullFreshVerificationOutranksCriticalOnly() {
        let applicability = audioUnitApplicability()
        let criticalRecords = records(for: applicability, state: .verified) {
            $0.status.inScope && $0.priority == .critical
        }
        let allRecords = records(for: applicability, state: .verified)

        let criticalReality = assess(applicability: applicability, verification: criticalRecords)
        let fullReality = assess(applicability: applicability, verification: allRecords)
        let fullBoard = ReleaseReadinessEngine().board(for: snapshot(
            applicability: applicability,
            verification: allRecords,
            reality: fullReality
        ))

        #expect(fullReality.score > criticalReality.score)
        #expect(fullBoard.status == .ready)
        #expect(fullReality.chain.contains { $0.stage == .verified && $0.state == .reached })
    }

    @Test("critical failure sharply lowers trust and blocks release")
    func criticalFailureLowersTrustAndBlocksRelease() {
        let applicability = audioUnitApplicability()
        let allVerified = records(for: applicability, state: .verified)
        let failed = allVerified.map { record in
            record.area == "AU Validation"
                ? VerificationRecord(
                    area: record.area,
                    state: .failed,
                    note: "auval fails the current component",
                    updatedAt: Date()
                )
                : record
        }

        let baseline = assess(applicability: applicability, verification: allVerified)
        let withFailure = assess(applicability: applicability, verification: failed)
        let board = ReleaseReadinessEngine().board(for: snapshot(
            applicability: applicability,
            verification: failed,
            reality: withFailure
        ))

        #expect(withFailure.score <= baseline.score - 10)
        #expect(withFailure.topRisks.contains { $0.localizedCaseInsensitiveContains("AU Validation") })
        #expect(withFailure.nextAction.localizedCaseInsensitiveContains("AU Validation"))
        #expect(board.status == .blocked)
        #expect(board.blockers.contains("AU Validation"))
    }

    @Test("active assumptions and open critical risk lower green verification")
    func assumptionsAndOpenCriticalRiskLowerGreenVerification() {
        let applicability = audioUnitApplicability()
        let allVerified = records(for: applicability, state: .verified)
        let risk = RiskRecord(
            title: "Preset corruption can ship to users",
            likelihood: .medium,
            impact: .critical,
            status: .open
        )
        let assumptions = [
            AssumptionRecord(assumption: "Hosts always restore AU state", status: .active),
            AssumptionRecord(assumption: "Sample-rate changes are harmless", status: .active),
            AssumptionRecord(assumption: "No user has stale presets", status: .active),
        ]

        let baseline = assess(applicability: applicability, verification: allVerified)
        let stressed = assess(
            applicability: applicability,
            verification: allVerified,
            riskRecords: [risk],
            assumptionRecords: assumptions
        )
        let breakdown = TruthEngine().breakdown(
            snapshot: snapshot(applicability: applicability, verification: allVerified, reality: stressed),
            evidence: [],
            risks: [risk],
            assumptions: assumptions
        )

        #expect(stressed.score < baseline.score)
        #expect(stressed.topRisks.contains { $0.localizedCaseInsensitiveContains("Release risk") })
        #expect(stressed.assumptions.count >= assumptions.count)
        #expect(stressed.unknowns.contains { $0.localizedCaseInsensitiveContains("active assumption") })
        #expect(breakdown.negatives.contains { $0.label.localizedCaseInsensitiveContains("open critical risk") })
        #expect(breakdown.negatives.contains { $0.label.localizedCaseInsensitiveContains("active assumption") })
    }

    @Test("stale verification loses trust but evidence restores most of it")
    func staleVerificationTrustCanBeRestoredByEvidence() {
        let applicability = audioUnitApplicability()
        let freshRecords = records(for: applicability, state: .verified, updatedAt: Date())
        let expiredRecords = records(
            for: applicability,
            state: .verified,
            updatedAt: Date().addingTimeInterval(-220 * day)
        )
        let evidence = expiredRecords.map {
            EvidenceRecord(area: $0.area, summary: "\($0.area) observed passing", classification: .observed)
        }

        let fresh = assess(applicability: applicability, verification: freshRecords)
        let expired = assess(applicability: applicability, verification: expiredRecords)
        let evidenceBacked = assess(
            applicability: applicability,
            verification: expiredRecords,
            evidenceRecords: evidence
        )
        let breakdown = TruthEngine().breakdown(
            snapshot: snapshot(applicability: applicability, verification: expiredRecords, reality: expired),
            evidence: evidence,
            risks: [],
            assumptions: []
        )

        #expect(expired.score < fresh.score)
        #expect(evidenceBacked.score > expired.score)
        #expect(evidenceBacked.score < fresh.score)
        #expect(breakdown.negatives.contains { $0.label.localizedCaseInsensitiveContains("stale verified") })
    }

    @Test("contradictory evidence is detected for a single area")
    func contradictoryEvidenceIsDetected() throws {
        let pass = EvidenceRecord(
            area: "AU Validation",
            summary: "auval passes locally",
            classification: .observed
        )
        let fail = EvidenceRecord(
            area: "AU Validation",
            summary: "host smoke test fails on reopen",
            body: "Failed twice during manual release rehearsal.",
            classification: .observed
        )

        let conflict = try #require(WhyEngine().detectConflicts(
            evidence: [pass, fail],
            projectID: UUID(),
            projectName: "Truth Harness"
        ).first)

        #expect(conflict.area == "AU Validation")
        #expect(conflict.successEvidence.contains(pass))
        #expect(conflict.failureEvidence.contains(fail))
    }

    @Test("dependency blocker surfaces on the release board")
    func dependencyBlockerSurfacesOnReleaseBoard() {
        let applicability = audioUnitApplicability()
        let verification = [
            VerificationRecord(area: "Preset System", state: .failed, note: "preset restore fails"),
            VerificationRecord(area: "AU Validation", state: .unknown, dependsOn: ["Preset System"]),
        ]
        let reality = assess(applicability: applicability, verification: verification)
        let board = ReleaseReadinessEngine().board(for: snapshot(
            applicability: applicability,
            verification: verification,
            reality: reality
        ))
        let auRow = board.rows.first { $0.area == "AU Validation" }

        #expect(board.status == .blocked)
        #expect(board.blockers.contains("Preset System"))
        #expect(auRow?.blockedBy.contains("Preset System (Failed)") == true)
    }

    @Test("workspace truth summary counts truth debt across records and snapshots")
    func workspaceTruthSummaryCountsTruthDebt() {
        let applicability = audioUnitApplicability()
        let verification = [
            VerificationRecord(
                area: "Build",
                state: .verified,
                updatedAt: Date().addingTimeInterval(-220 * day)
            ),
            VerificationRecord(area: "AU Validation", state: .failed),
        ]
        let recordID = UUID()
        let record = PersistedProjectRecord(
            id: recordID,
            name: "Truth Harness",
            fallbackPath: "/tmp/truth-harness",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .saved,
            verification: verification,
            journal: [JournalEntry(kind: .verification, summary: "AU Validation failed")],
            evidence: [EvidenceRecord(area: "AU Validation", summary: "auval failed", classification: .observed)],
            decisions: [DecisionRecord(title: "Require auval before release")],
            architecture: [ArchitectureItem(name: "Validation Harness", subsystemType: .buildSystem)],
            risks: [
                RiskRecord(title: "Release crash", impact: .critical, status: .open),
                RiskRecord(title: "Host compatibility watch", impact: .high, status: .monitoring),
            ],
            assumptions: [
                AssumptionRecord(assumption: "Host restore is stable", status: .active),
                AssumptionRecord(assumption: "Old preset format is irrelevant", status: .superseded),
            ]
        )
        let reality = assess(applicability: applicability, verification: verification)
        let summary = TruthEngine().workspaceTruth(
            records: [record],
            snapshots: [snapshot(applicability: applicability, verification: verification, reality: reality)]
        )

        #expect(summary.totalProjects == 1)
        #expect(summary.verifiedRecords == 1)
        #expect(summary.evidenceRecords == 1)
        #expect(summary.openRisks == 2)
        #expect(summary.activeAssumptions == 1)
        #expect(summary.criticalFailures == 1)
        #expect(summary.decisionRecords == 1)
        #expect(summary.architectureItems == 1)
        #expect(summary.staleVerifications == 1)
        #expect(summary.criticalOpenRisks == 1)
        #expect(summary.journalEntries == 1)
    }

    private var day: TimeInterval { 86_400 }

    private func audioUnitIdentity() -> ProjectIdentity {
        ProjectIdentity(kind: .audioUnitInstrument, detail: "Synthetic AUv3 instrument", confidence: .observed)
    }

    private func audioUnitMission() -> MissionProfile {
        UserMissionProfile(
            statedMission: "Ship a trustworthy AUv3 instrument",
            category: .instrument,
            currentPhase: "Release hardening"
        ).asMissionProfile()
    }

    private func audioUnitApplicability() -> [ApplicabilityItem] {
        ApplicabilityEngine().items(for: audioUnitIdentity(), mission: audioUnitMission())
    }

    private func records(
        for applicability: [ApplicabilityItem],
        state: VerificationState,
        updatedAt: Date = Date(),
        including predicate: (ApplicabilityItem) -> Bool = { $0.status.inScope }
    ) -> [VerificationRecord] {
        applicability
            .filter(predicate)
            .map { VerificationRecord(area: $0.area, state: state, updatedAt: updatedAt) }
    }

    private func assess(
        applicability: [ApplicabilityItem],
        verification: [VerificationRecord],
        evidenceRecords: [EvidenceRecord] = [],
        riskRecords: [RiskRecord] = [],
        assumptionRecords: [AssumptionRecord] = []
    ) -> RealityAssessment {
        RealityEngine().assess(
            identity: audioUnitIdentity(),
            mission: audioUnitMission(),
            applicability: applicability,
            git: GitStatus(isRepository: true, branch: "main", hasUpstream: true),
            summary: RepoSummary(totalFiles: 80, sourceFiles: 48, testFiles: 16, documentationFiles: 6),
            findings: [],
            evidence: [
                Evidence(
                    title: "Approved test repository",
                    detail: "/tmp/truth-harness",
                    classification: .observed,
                    source: "truth stress fixture"
                )
            ],
            verification: verification,
            evidenceRecords: evidenceRecords,
            riskRecords: riskRecords,
            assumptionRecords: assumptionRecords
        )
    }

    private func snapshot(
        applicability: [ApplicabilityItem],
        verification: [VerificationRecord],
        reality: RealityAssessment
    ) -> RepoSnapshot {
        var snapshot = RepoSnapshot.fixture(identity: audioUnitIdentity(), git: GitStatus(isRepository: true, branch: "main"))
        snapshot.project = ProjectContext(
            name: "Truth Harness",
            rootURL: URL(fileURLWithPath: "/tmp/truth-harness"),
            permission: .approved(scopeDescription: "truth stress fixture")
        )
        snapshot.summary = RepoSummary(totalFiles: 80, sourceFiles: 48, testFiles: 16, documentationFiles: 6)
        snapshot.mission = audioUnitMission()
        snapshot.userMission = UserMissionProfile(
            statedMission: "Ship a trustworthy AUv3 instrument",
            category: .instrument,
            currentPhase: "Release hardening"
        )
        snapshot.applicability = applicability
        snapshot.verification = verification
        snapshot.evidence = verification
            .filter { $0.state == .verified }
            .map {
                Evidence(
                    title: "\($0.area) release evidence",
                    detail: "\($0.area) observed passing in the truth stress fixture",
                    classification: .observed,
                    source: "truth stress fixture"
                )
            }
        snapshot.reality = reality
        return snapshot
    }
}
