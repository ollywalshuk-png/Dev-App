import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth contribution provenance")
struct TruthContributionProvenanceTests {
    @Test("material score contributors return structured provenance rows")
    func materialScoreContributorsReturnStructuredRows() {
        let now = Date()
        let staleDate = now.addingTimeInterval(-120.0 * 86_400.0)
        let verified = VerificationRecord(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            area: "Build",
            state: .verified,
            updatedAt: now
        )
        let failed = VerificationRecord(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            area: "Preset System",
            state: .failed,
            note: "Host restore fails",
            updatedAt: now
        )
        let stale = VerificationRecord(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            area: "DSP",
            state: .verified,
            updatedAt: staleDate
        )
        let risk = RiskRecord(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            title: "Preset corruption",
            likelihood: .medium,
            impact: .critical,
            status: .open,
            linkedVerificationAreas: ["Preset System"]
        )
        let evidence = EvidenceRecord(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            area: "Build",
            kind: .logExcerpt,
            summary: "Release build passes",
            classification: .measured
        )
        let assumption = AssumptionRecord(
            id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            assumption: "Host restores AUState correctly",
            status: .active,
            linkedVerificationArea: "Preset System",
            linkedRiskIDs: [risk.id]
        )

        var snapshot = RepoSnapshot.fixture()
        snapshot.applicability = [
            ApplicabilityItem(area: "Build", status: .required, priority: .critical),
            ApplicabilityItem(area: "Preset System", status: .required, priority: .high),
            ApplicabilityItem(area: "DSP", status: .expected, priority: .high)
        ]
        snapshot.verification = [verified, failed, stale]

        let rows = TruthEngine().contributionProvenance(
            snapshot: snapshot,
            evidence: [evidence],
            risks: [risk],
            assumptions: [assumption]
        )

        #expect(rows.allSatisfy { !$0.sourceIdentifier.isEmpty || !$0.sourceArea.isEmpty })
        #expect(rows.allSatisfy { !$0.status.isEmpty })
        #expect(rows.allSatisfy { !$0.reason.isEmpty })
        #expect(rows.filter { $0.sourceKind == .verification }.allSatisfy { $0.freshness != nil })

        #expect(rows.contains {
            $0.sourceKind == .verification
                && $0.sourceIdentifier == verified.id.uuidString
                && $0.status == VerificationState.verified.rawValue
                && $0.freshness == .fresh
                && $0.direction == .positive
                && $0.releaseRelevant
        })
        #expect(rows.contains {
            $0.sourceKind == .verification
                && $0.sourceIdentifier == failed.id.uuidString
                && $0.status == VerificationState.failed.rawValue
                && $0.direction == .negative
                && $0.releaseRelevant
        })
        #expect(rows.contains {
            $0.sourceKind == .evidence
                && $0.sourceIdentifier == evidence.id.uuidString
                && $0.status == EvidenceClassification.measured.rawValue
                && $0.direction == .positive
        })
        #expect(rows.contains {
            $0.sourceKind == .verification
                && $0.sourceIdentifier == stale.id.uuidString
                && $0.freshness == .stale
                && $0.direction == .negative
                && $0.reason.contains("stale")
        })
        #expect(rows.contains {
            $0.sourceKind == .assumption
                && $0.sourceIdentifier == assumption.id.uuidString
                && $0.status == AssumptionStatus.active.rawValue
                && $0.direction == .negative
                && $0.releaseRelevant
        })
        #expect(rows.contains {
            $0.sourceKind == .risk
                && $0.sourceIdentifier == risk.id.uuidString
                && $0.status == RiskStatus.open.rawValue
                && $0.direction == .negative
                && $0.releaseRelevant
        })
    }
}
