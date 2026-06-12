import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Search engine")
struct SearchEngineTests {
    @Test("evidence audit fields are searchable")
    func evidenceAuditFieldsAreSearchable() {
        let evidence = EvidenceRecord(
            area: "Release Build",
            kind: .logExcerpt,
            summary: "Archive transcript captured",
            body: "Clean local archive output.",
            classification: .measured,
            author: "Priya Singh"
        )
        let record = projectRecord(evidence: [evidence])
        let engine = SearchEngine()

        let measuredHit = engine.search("Measured", in: [record]).first { $0.recordID == evidence.id }
        #expect(measuredHit?.kind == .evidence)
        #expect(measuredHit?.snippet == "Measured")
        #expect(measuredHit?.area == "Release Build")

        let kindHit = engine.search("Log Excerpt", in: [record]).first { $0.recordID == evidence.id }
        #expect(kindHit?.kind == .evidence)
        #expect(kindHit?.snippet == "Log Excerpt")

        let areaHit = engine.search("Release Build", in: [record]).first { $0.recordID == evidence.id }
        #expect(areaHit?.kind == .evidence)

        let authorHit = engine.search("Priya Singh", in: [record]).first { $0.recordID == evidence.id }
        #expect(authorHit?.kind == .evidence)
    }

    @Test("evidence linked to release-blocking risks carries blocking state")
    func evidenceLinkedToReleaseBlockingRisksCarriesBlockingState() {
        let directRiskID = UUID()
        let reverseLinkedEvidenceID = UUID()
        let directEvidence = EvidenceRecord(
            area: "State Restore",
            summary: "Direct blocker transcript",
            linkedRiskIDs: [directRiskID]
        )
        let reverseEvidence = EvidenceRecord(
            id: reverseLinkedEvidenceID,
            area: "Preset System",
            summary: "Reverse blocker transcript"
        )
        let informationalRiskID = UUID()
        let nonBlockingEvidence = EvidenceRecord(
            area: "Telemetry",
            summary: "Informational transcript",
            linkedRiskIDs: [informationalRiskID]
        )
        let risks = [
            RiskRecord(id: directRiskID, title: "State restore corruption", impact: .critical, status: .open),
            RiskRecord(
                title: "Preset corruption",
                impact: .critical,
                status: .open,
                linkedEvidenceIDs: [reverseLinkedEvidenceID]
            ),
            RiskRecord(id: informationalRiskID, title: "Telemetry lag", impact: .medium, status: .open),
        ]
        let record = projectRecord(evidence: [directEvidence, reverseEvidence, nonBlockingEvidence], risks: risks)
        let engine = SearchEngine()

        let directHit = engine.search("Direct blocker", in: [record]).first { $0.recordID == directEvidence.id }
        #expect(directHit?.kind == .evidence)
        #expect(directHit?.isReleaseBlocking == true)

        let reverseHit = engine.search("Reverse blocker", in: [record]).first { $0.recordID == reverseEvidence.id }
        #expect(reverseHit?.kind == .evidence)
        #expect(reverseHit?.isReleaseBlocking == true)

        let nonBlockingHit = engine.search("Informational", in: [record]).first { $0.recordID == nonBlockingEvidence.id }
        #expect(nonBlockingHit?.kind == .evidence)
        #expect(nonBlockingHit?.isReleaseBlocking == false)
    }

    private func projectRecord(
        evidence: [EvidenceRecord],
        risks: [RiskRecord] = []
    ) -> PersistedProjectRecord {
        PersistedProjectRecord(
            name: "Truth Audit Fixture",
            fallbackPath: "/tmp/truth-audit-fixture",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .missing,
            evidence: evidence,
            risks: risks
        )
    }
}
