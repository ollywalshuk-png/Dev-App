import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Workspace Doctor trust guardrails")
struct WorkspaceDoctorTrustTests {
    @Test("stale verified areas require backing evidence")
    func staleVerifiedAreasWithoutEvidenceAreFlagged() throws {
        let pid = UUID()
        let expired = Date(timeIntervalSinceNow: -181 * 86_400)
        let record = project(
            id: pid,
            verification: [
                VerificationRecord(area: "Release Build", state: .verified, updatedAt: expired)
            ]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])
        let issue = try #require(report.issues.first { $0.title.contains("stale verified area") })

        #expect(issue.kind == .missingReference)
        #expect(issue.severity == .high)
        #expect(issue.recommendation.contains("Attach recent evidence"))
    }

    @Test("stale verified areas with evidence are not flagged as unbacked")
    func staleVerifiedAreasWithEvidenceAreTrusted() {
        let pid = UUID()
        let verification = VerificationRecord(
            area: "Release Build",
            state: .verified,
            updatedAt: Date(timeIntervalSinceNow: -181 * 86_400)
        )
        let record = project(
            id: pid,
            verification: [verification],
            evidence: [
                EvidenceRecord(area: "Release Build", summary: "Archive passed on CI")
            ]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])

        #expect(!report.issues.contains { $0.title.contains("stale verified area") })
    }

    @Test("active high-impact risks must be linked into the truth chain")
    func activeHighImpactRisksWithoutTruthLinksAreFlagged() throws {
        let pid = UUID()
        let record = project(
            id: pid,
            risks: [
                RiskRecord(title: "Signing identity may be wrong", impact: .critical, status: .open),
                RiskRecord(title: "Notarisation queue is flaky", impact: .high, status: .monitoring),
                RiskRecord(title: "Closed release blocker", impact: .critical, status: .closed),
                RiskRecord(title: "Linked release blocker", impact: .critical, status: .open, linkedVerificationAreas: ["Signing"])
            ]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])
        let issue = try #require(report.issues.first { $0.title.contains("high-impact active risk") })

        #expect(issue.kind == .orphanRisk)
        #expect(issue.severity == .high)
        #expect(issue.title.contains("2"))
    }

    @Test("duplicate verification areas with conflicting states are corrupt truth")
    func duplicateVerificationAreasWithConflictingStatesAreFlagged() throws {
        let pid = UUID()
        let record = project(
            id: pid,
            verification: [
                VerificationRecord(area: "Build", state: .verified),
                VerificationRecord(area: " build ", state: .failed),
                VerificationRecord(area: "Docs", state: .verified),
                VerificationRecord(area: "docs", state: .verified)
            ]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])
        let issue = try #require(report.issues.first { $0.kind == .corruptRelationship })

        #expect(issue.severity == .high)
        #expect(issue.title.contains("1"))
        #expect(issue.recommendation.contains("one current state"))
    }

    @Test("safety recommendations must retain auditable evidence links")
    func safetyRecommendationMissingEvidenceIsFlagged() throws {
        let pid = UUID()
        let missingEvidenceID = UUID()
        let record = project(
            id: pid,
            recommendations: [
                safetyRecommendation(
                    title: "Potential secret in Config.swift:12",
                    targetPath: "/tmp/App/Config.swift",
                    evidenceSummary: "Config.swift:12 matched provider-token",
                    relatedEvidenceIDs: [missingEvidenceID]
                )
            ]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])
        let issue = try #require(report.issues.first { $0.title.contains("recommendation(s) reference missing evidence") })

        #expect(issue.kind == .missingReference)
        #expect(issue.severity == .high)
    }

    @Test("active safety recommendations without a target are orphaned")
    func activeSafetyRecommendationWithoutEvidenceTargetIsFlagged() throws {
        let pid = UUID()
        let record = project(
            id: pid,
            recommendations: [
                safetyRecommendation(
                    title: "Potential secret",
                    targetPath: "",
                    evidenceSummary: "",
                    severity: .critical
                )
            ]
        )

        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "App"])
        let issue = try #require(report.issues.first { $0.title.contains("active safety recommendation") })

        #expect(issue.kind == .missingReference)
        #expect(issue.severity == .high)
    }

    private func project(
        id: UUID,
        verification: [VerificationRecord]? = nil,
        evidence: [EvidenceRecord]? = nil,
        risks: [RiskRecord]? = nil,
        recommendations: [RecommendationRecord]? = nil
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
            recommendations: recommendations
        )
    }

    private func safetyRecommendation(
        title: String,
        targetPath: String,
        evidenceSummary: String,
        severity: RecommendationSeverity = .high,
        relatedEvidenceIDs: [UUID] = []
    ) -> RecommendationRecord {
        RecommendationRecord(
            category: .safety,
            title: title,
            summary: "Secret scan safety finding",
            targetPath: targetPath,
            sourceFilesAffected: true,
            severity: severity,
            evidenceSummary: evidenceSummary,
            impact: "Credentials may be exposed.",
            suggestedAdjustment: "Rotate and remove the credential manually.",
            safetyWarning: "Do not paste the secret while investigating.",
            rollbackNote: "Use version control to review any manual removal.",
            relatedEvidenceIDs: relatedEvidenceIDs
        )
    }
}
