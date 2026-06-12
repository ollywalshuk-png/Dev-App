import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Release blocking chain audit checks")
struct ReleaseBlockingChainTests {
    @Test("dependency blocker nodes are unique deterministic and unambiguous")
    func dependencyBlockerNodesAreUniqueDeterministicAndUnambiguous() {
        let snapshot = releaseSnapshot(
            applicability: [
                ApplicabilityItem(area: "AU Validation", status: .required, priority: .critical),
                ApplicabilityItem(area: "Preset System", status: .required, priority: .critical),
                ApplicabilityItem(area: "Signing", status: .required, priority: .critical),
                ApplicabilityItem(area: "Build", status: .required, priority: .critical),
            ],
            verification: [
                VerificationRecord(area: "Preset System", state: .failed),
                VerificationRecord(area: "Build", state: .failed),
                VerificationRecord(area: "Signing", state: .failed, dependsOn: ["Build", "Build"]),
                VerificationRecord(area: "AU Validation", state: .verified, dependsOn: ["Preset System", "Build", "Preset System"]),
            ]
        )

        let board = ReleaseReadinessEngine().board(for: snapshot, evidence: [strongEvidence(area: "AU Validation")])
        let auRow = board.rows.first { $0.area == "AU Validation" }
        let signingRow = board.rows.first { $0.area == "Signing" }

        #expect(board.status == .blocked)
        #expect(board.blockers == ["Build", "Preset System", "Signing"])
        #expect(Set(board.blockers).count == board.blockers.count)
        #expect(board.blockers.contains("AU Validation") == false)
        #expect(auRow?.blockedBy == ["Build (Failed)", "Preset System (Failed)"])
        #expect(signingRow?.blockedBy == ["Build (Failed)"])
    }

    private func releaseSnapshot(
        applicability: [ApplicabilityItem],
        verification: [VerificationRecord]
    ) -> RepoSnapshot {
        var snapshot = RepoSnapshot.fixture(identity: ProjectIdentity(kind: .swiftUIApp, detail: "release chain fixture", confidence: .observed))
        snapshot.applicability = applicability
        snapshot.verification = verification
        return snapshot
    }

    private func strongEvidence(area: String) -> EvidenceRecord {
        EvidenceRecord(area: area, summary: "\(area) passed release validation", classification: .observed)
    }
}
