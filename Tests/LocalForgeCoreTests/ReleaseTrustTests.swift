import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Release readiness trust checks")
struct ReleaseTrustTests {
    @Test("critical failures block release readiness")
    func criticalFailuresBlockReleaseReadiness() {
        var snapshot = releaseSnapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical)
            ],
            verification: [
                VerificationRecord(area: "Build", state: .failed)
            ]
        )

        let board = ReleaseReadinessEngine().board(for: snapshot)

        #expect(board.status == .blocked)
        #expect(board.blockers == ["Build"])
        #expect(board.criticalRemaining == 1)
        #expect(ReleaseReadinessEngine.finalStatus(for: board) == .blocked)

        snapshot.verification = [VerificationRecord(area: "Build", state: .verified)]
        let recovered = ReleaseReadinessEngine().board(for: snapshot)
        #expect(recovered.status == .ready)
    }

    @Test("stale critical verification prevents a clean release")
    func staleCriticalVerificationPreventsCleanRelease() {
        let staleDate = Date(timeIntervalSinceNow: -120 * 86_400)
        let snapshot = releaseSnapshot(
            applicability: [
                ApplicabilityItem(area: "Signing", status: .required, priority: .critical)
            ],
            verification: [
                VerificationRecord(area: "Signing", state: .verified, updatedAt: staleDate)
            ]
        )

        let board = ReleaseReadinessEngine().board(for: snapshot)

        #expect(board.status == .notReady)
        #expect(board.criticalRemaining == 1)
        #expect(board.caveats.contains("Signing verification is stale."))
        #expect(board.headline.contains("fresh"))
    }

    @Test("blocked dependencies prevent dependent gates from looking release-ready")
    func blockedDependenciesPreventDependentGatesFromLookingReady() {
        let snapshot = releaseSnapshot(
            applicability: [
                ApplicabilityItem(area: "AU Validation", status: .required, priority: .critical)
            ],
            verification: [
                VerificationRecord(area: "Preset System", state: .failed),
                VerificationRecord(area: "AU Validation", state: .verified, dependsOn: ["Preset System"])
            ]
        )

        let board = ReleaseReadinessEngine().board(for: snapshot)
        let auRow = board.rows.first { $0.area == "AU Validation" }

        #expect(board.status == .blocked)
        #expect(board.blockers == ["AU Validation"])
        #expect(board.criticalRemaining == 1)
        #expect(auRow?.blockedBy == ["Preset System (Failed)"])
        #expect(board.caveats.contains("AU Validation blocked by Preset System (Failed)."))
    }

    @Test("open release-blocking risks block readiness even when verification is green")
    func openReleaseBlockingRisksBlockGreenVerification() {
        let snapshot = releaseSnapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical)
            ],
            verification: [
                VerificationRecord(area: "Build", state: .verified)
            ]
        )
        let risks = [
            RiskRecord(title: "Notarisation fails on clean machine", likelihood: .medium, impact: .critical, status: .open),
            RiskRecord(title: "Docs typo", likelihood: .low, impact: .low, status: .open)
        ]

        let board = ReleaseReadinessEngine().board(for: snapshot, risks: risks)

        #expect(board.status == .blocked)
        #expect(board.blockers.isEmpty)
        #expect(board.riskBlockers == ["Notarisation fails on clean machine"])
        #expect(board.headline.contains("release-blocking risk"))
        #expect(ReleaseReadinessEngine.finalStatus(for: board) == .blocked)
    }

    @Test("lower-priority gaps are caveats after critical and high gates are clear")
    func lowerPriorityGapsBecomeCaveats() {
        let snapshot = releaseSnapshot(
            applicability: [
                ApplicabilityItem(area: "Build", status: .required, priority: .critical),
                ApplicabilityItem(area: "Accessibility Notes", status: .expected, priority: .low)
            ],
            verification: [
                VerificationRecord(area: "Build", state: .verified),
                VerificationRecord(area: "Accessibility Notes", state: .unknown)
            ]
        )

        let board = ReleaseReadinessEngine().board(for: snapshot)

        #expect(board.status == .readyWithCaveats)
        #expect(board.criticalRemaining == 0)
        #expect(board.highRemaining == 0)
        #expect(board.caveats == ["Accessibility Notes is Unknown."])
    }

    private func releaseSnapshot(
        applicability: [ApplicabilityItem],
        verification: [VerificationRecord]
    ) -> RepoSnapshot {
        var snapshot = RepoSnapshot.fixture(identity: ProjectIdentity(kind: .swiftUIApp, detail: "release fixture", confidence: .observed))
        snapshot.applicability = applicability
        snapshot.verification = verification
        return snapshot
    }
}
