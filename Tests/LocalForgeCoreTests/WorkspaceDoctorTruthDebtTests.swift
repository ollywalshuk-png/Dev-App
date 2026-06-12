import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Workspace Doctor truth debt")
struct WorkspaceDoctorTruthDebtTests {
    @Test("release-relevant stale verification requires strong evidence")
    func releaseRelevantStaleVerificationWithoutStrongEvidenceIsFlagged() throws {
        let pid = UUID()
        let verification = VerificationRecord(
            area: "Signing",
            state: .verified,
            updatedAt: Date(timeIntervalSinceNow: -220 * day)
        )
        let risk = RiskRecord(
            title: "Signing fails on release machine",
            likelihood: .medium,
            impact: .critical,
            status: .open,
            mitigation: "Re-run signing validation before release.",
            linkedVerificationAreas: ["Signing"]
        )
        let record = project(
            id: pid,
            verification: [verification],
            evidence: [
                EvidenceRecord(area: "Signing", summary: "Expected to pass", classification: .assumed)
            ],
            risks: [risk]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])
        let issue = try #require(report.issues.first { $0.title.contains("stale truth without strong evidence") })

        #expect(issue.kind == .missingReference)
        #expect(issue.severity == .critical)
        #expect(issue.impact.contains("observed, measured, or verified evidence"))
    }

    @Test("strong evidence backs stale release-relevant verification")
    func strongEvidenceSuppressesReleaseRelevantStaleVerificationFinding() {
        let pid = UUID()
        let verification = VerificationRecord(
            area: "Signing",
            state: .verified,
            updatedAt: Date(timeIntervalSinceNow: -120 * day)
        )
        let risk = RiskRecord(
            title: "Signing fails on release machine",
            likelihood: .medium,
            impact: .critical,
            status: .open,
            mitigation: "Re-run signing validation before release.",
            linkedVerificationAreas: ["Signing"]
        )
        let record = project(
            id: pid,
            verification: [verification],
            evidence: [
                EvidenceRecord(area: "Signing", summary: "CI signing validation passed", classification: .measured)
            ],
            risks: [risk]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])

        #expect(!report.issues.contains { $0.title.contains("stale truth without strong evidence") })
    }

    @Test("active assumptions linked to release-relevant risks are flagged")
    func activeAssumptionsLinkedToReleaseRelevantRisksAreFlagged() throws {
        let pid = UUID()
        let verification = VerificationRecord(area: "Signing", state: .verified)
        let risk = RiskRecord(
            title: "Signing fails on release machine",
            likelihood: .medium,
            impact: .critical,
            status: .open,
            mitigation: "Re-run signing validation before release.",
            linkedVerificationAreas: ["Signing"]
        )
        let monitoredRisk = RiskRecord(
            title: "Dependency update may break packaging",
            likelihood: .medium,
            impact: .high,
            status: .monitoring
        )
        let activeAssumption = AssumptionRecord(
            assumption: "Release certificate is installed on CI",
            status: .active,
            linkedRiskIDs: [risk.id]
        )
        let monitoredAssumption = AssumptionRecord(
            assumption: "Dependency update remains compatible",
            status: .active,
            linkedRiskIDs: [monitoredRisk.id]
        )
        let verifiedAssumption = AssumptionRecord(
            assumption: "Developer account is active",
            status: .verified,
            linkedRiskIDs: [risk.id]
        )
        let record = project(
            id: pid,
            verification: [verification],
            risks: [risk, monitoredRisk],
            assumptions: [activeAssumption, monitoredAssumption, verifiedAssumption]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])
        let issue = try #require(report.issues.first { $0.title.contains("active assumption") })

        #expect(issue.kind == .missingReference)
        #expect(issue.severity == .high)
        #expect(issue.title.contains("2"))
        #expect(issue.recommendation.contains("verify or disprove"))
    }

    @Test("release-blocking risks need mitigation and verification support")
    func releaseBlockingRisksMissingMitigationOrSupportAreFlagged() throws {
        let pid = UUID()
        let build = VerificationRecord(area: "Build", state: .verified)
        let signing = VerificationRecord(area: "Signing", state: .verified)
        let noPlan = RiskRecord(
            title: "Build fails on clean release machine",
            likelihood: .medium,
            impact: .critical,
            status: .open,
            linkedVerificationAreas: ["Build"]
        )
        let noSupport = RiskRecord(
            title: "Notarisation result is unknown",
            likelihood: .medium,
            impact: .high,
            status: .open,
            mitigation: "Hold release until notarisation is checked."
        )
        let supported = RiskRecord(
            title: "Signing identity may expire",
            likelihood: .medium,
            impact: .critical,
            status: .open,
            mitigation: "Check certificate expiry before release.",
            linkedVerificationAreas: ["Signing"]
        )
        let record = project(
            id: pid,
            verification: [build, signing],
            risks: [noPlan, noSupport, supported]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])
        let issue = try #require(report.issues.first { $0.title.contains("release-blocking open risk") })

        #expect(issue.kind == .orphanRisk)
        #expect(issue.severity == .critical)
        #expect(issue.title.contains("2"))
        #expect(issue.impact.contains("release-ready claim is defensible"))
    }

    @Test("truth debt findings keep duplicate verification behavior compatible")
    func duplicateVerificationIssuesRemainCompatible() {
        let pid = UUID()
        let record = project(
            id: pid,
            verification: [
                VerificationRecord(area: "Build", state: .verified),
                VerificationRecord(area: "build", state: .failed)
            ]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])

        #expect(report.issues.contains { $0.kind == .duplicateRecord && $0.title.contains("duplicate verification area") })
        #expect(report.issues.contains { $0.kind == .corruptRelationship && $0.title.contains("conflicting states") })
    }

    private func project(
        id: UUID,
        verification: [VerificationRecord]? = nil,
        evidence: [EvidenceRecord]? = nil,
        risks: [RiskRecord]? = nil,
        assumptions: [AssumptionRecord]? = nil
    ) -> PersistedProjectRecord {
        PersistedProjectRecord(
            id: id,
            name: "App",
            fallbackPath: "/tmp/app",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .saved,
            verification: verification,
            evidence: evidence,
            risks: risks,
            assumptions: assumptions
        )
    }
}

private let day: TimeInterval = 86_400
