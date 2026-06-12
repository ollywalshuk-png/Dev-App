import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth Centre scale stress tests")
struct TruthScaleStressTests {
    @Test("large workspace truth data remains deterministic and responsive")
    func largeWorkspaceTruthDataRemainsDeterministicAndResponsive() {
        let fixture = makeLargeTruthFixture(projectCount: 1_200, areasPerProject: 10)
        let truthEngine = TruthEngine()
        let startedAt = Date()

        let scoredSnapshots = rescoreSnapshots(fixture)
        let repeatedScores = rescoreSnapshots(fixture).map(\.reality.score)
        let summary = truthEngine.workspaceTruth(records: fixture.records, snapshots: scoredSnapshots)
        let repeatedSummary = truthEngine.workspaceTruth(records: fixture.records, snapshots: scoredSnapshots)

        let sampleRecord = fixture.records[fixture.sampleProjectIndex]
        let sampleSnapshot = scoredSnapshots[fixture.sampleProjectIndex]
        let sampleEvidence = sampleRecord.evidence ?? []
        let sampleRisks = sampleRecord.risks ?? []
        let sampleDecisions = sampleRecord.decisions ?? []
        let sampleArchitecture = sampleRecord.architecture ?? []
        let sampleAssumptions = sampleRecord.assumptions ?? []

        let breakdown = truthEngine.breakdown(
            snapshot: sampleSnapshot,
            evidence: sampleEvidence,
            risks: sampleRisks,
            assumptions: sampleAssumptions
        )
        let repeatedBreakdown = truthEngine.breakdown(
            snapshot: sampleSnapshot,
            evidence: sampleEvidence,
            risks: sampleRisks,
            assumptions: sampleAssumptions
        )
        let confidence = truthEngine.confidence(
            snapshot: sampleSnapshot,
            evidence: sampleEvidence,
            assumptions: sampleAssumptions
        )
        let repeatedConfidence = truthEngine.confidence(
            snapshot: sampleSnapshot,
            evidence: sampleEvidence,
            assumptions: sampleAssumptions
        )
        let health = truthEngine.registerHealth(
            snapshot: sampleSnapshot,
            evidence: sampleEvidence,
            decisions: sampleDecisions,
            risks: sampleRisks,
            architecture: sampleArchitecture,
            assumptions: sampleAssumptions
        )
        let repeatedHealth = truthEngine.registerHealth(
            snapshot: sampleSnapshot,
            evidence: sampleEvidence,
            decisions: sampleDecisions,
            risks: sampleRisks,
            architecture: sampleArchitecture,
            assumptions: sampleAssumptions
        )
        let related = truthEngine.related(
            to: .verification(fixture.sampleVerification.id),
            evidence: fixture.allEvidence,
            risks: fixture.allRisks,
            decisions: fixture.allDecisions,
            architecture: fixture.allArchitecture,
            assumptions: fixture.allAssumptions,
            verification: fixture.allVerification
        )
        let repeatedRelated = truthEngine.related(
            to: .verification(fixture.sampleVerification.id),
            evidence: fixture.allEvidence,
            risks: fixture.allRisks,
            decisions: fixture.allDecisions,
            architecture: fixture.allArchitecture,
            assumptions: fixture.allAssumptions,
            verification: fixture.allVerification
        )

        let elapsed = Date().timeIntervalSince(startedAt)
        let scores = scoredSnapshots.map(\.reality.score)

        #expect(scores == repeatedScores)
        #expect(scores.allSatisfy { $0 >= 0 && $0 <= 100 })
        #expect(Set(scores).count == 1)

        #expect(summary == repeatedSummary)
        #expect(summary.totalProjects == 1_200)
        #expect(summary.verifiedRecords == 4_800)
        #expect(summary.evidenceRecords == 12_000)
        #expect(summary.openRisks == 2_400)
        #expect(summary.activeAssumptions == 2_400)
        #expect(summary.criticalFailures == 2_400)
        #expect(summary.decisionRecords == 3_600)
        #expect(summary.architectureItems == 12_000)
        #expect(summary.staleVerifications == 1_200)
        #expect(summary.criticalOpenRisks == 1_200)
        #expect(summary.journalEntries == 2_400)

        #expect(breakdown.finalScore == sampleSnapshot.reality.score)
        #expect(contributionSignature(breakdown.contributions) == contributionSignature(repeatedBreakdown.contributions))
        #expect(breakdown.negatives.contains { $0.label.localizedCaseInsensitiveContains("failed verification") })
        #expect(breakdown.negatives.contains { $0.label.localizedCaseInsensitiveContains("open critical risk") })
        #expect(breakdown.negatives.contains { $0.label.localizedCaseInsensitiveContains("active assumption") })
        #expect(breakdown.negatives.contains { $0.label.localizedCaseInsensitiveContains("stale verified") })

        #expect(confidence.score == repeatedConfidence.score)
        #expect(confidence.label == repeatedConfidence.label)
        #expect(confidence.summary == repeatedConfidence.summary)
        #expect(contributionSignature(confidence.contributions) == contributionSignature(repeatedConfidence.contributions))
        #expect(health == repeatedHealth)

        #expect(related == repeatedRelated)
        #expect(related.evidence.count == 1)
        #expect(related.risks.count == 1)
        #expect(related.decisions.count == 1)
        #expect(related.architecture.count == 1)
        #expect(related.assumptions.count == 1)
        #expect(related.totalCount == 5)

        #expect(
            elapsed < 10,
            "Truth Centre scale pass took \(elapsed)s; investigate accidental superlinear work."
        )
    }

    private struct LargeTruthFixture {
        var projectCount: Int
        var areasPerProject: Int
        var sampleProjectIndex: Int
        var sampleVerification: VerificationRecord
        var records: [PersistedProjectRecord]
        var snapshots: [RepoSnapshot]
        var allVerification: [VerificationRecord]
        var allEvidence: [EvidenceRecord]
        var allRisks: [RiskRecord]
        var allDecisions: [DecisionRecord]
        var allArchitecture: [ArchitectureItem]
        var allAssumptions: [AssumptionRecord]
    }

    private func makeLargeTruthFixture(projectCount: Int, areasPerProject: Int) -> LargeTruthFixture {
        let now = Date()
        let sampleProjectIndex = projectCount / 2
        let sampleAreaIndex = 2
        var sampleVerification: VerificationRecord?
        var records: [PersistedProjectRecord] = []
        var snapshots: [RepoSnapshot] = []
        var allVerification: [VerificationRecord] = []
        var allEvidence: [EvidenceRecord] = []
        var allRisks: [RiskRecord] = []
        var allDecisions: [DecisionRecord] = []
        var allArchitecture: [ArchitectureItem] = []
        var allAssumptions: [AssumptionRecord] = []

        records.reserveCapacity(projectCount)
        snapshots.reserveCapacity(projectCount)
        allVerification.reserveCapacity(projectCount * areasPerProject)
        allEvidence.reserveCapacity(projectCount * areasPerProject)
        allRisks.reserveCapacity(projectCount * 4)
        allDecisions.reserveCapacity(projectCount * 3)
        allArchitecture.reserveCapacity(projectCount * areasPerProject)
        allAssumptions.reserveCapacity(projectCount * 4)

        for projectIndex in 0..<projectCount {
            let project = makeProjectFixture(projectIndex: projectIndex, areasPerProject: areasPerProject, now: now)
            records.append(project.record)
            snapshots.append(project.snapshot)
            allVerification.append(contentsOf: project.verification)
            allEvidence.append(contentsOf: project.evidence)
            allRisks.append(contentsOf: project.risks)
            allDecisions.append(contentsOf: project.decisions)
            allArchitecture.append(contentsOf: project.architecture)
            allAssumptions.append(contentsOf: project.assumptions)

            if projectIndex == sampleProjectIndex {
                sampleVerification = project.verification[sampleAreaIndex]
            }
        }

        return LargeTruthFixture(
            projectCount: projectCount,
            areasPerProject: areasPerProject,
            sampleProjectIndex: sampleProjectIndex,
            sampleVerification: sampleVerification!,
            records: records,
            snapshots: snapshots,
            allVerification: allVerification,
            allEvidence: allEvidence,
            allRisks: allRisks,
            allDecisions: allDecisions,
            allArchitecture: allArchitecture,
            allAssumptions: allAssumptions
        )
    }

    private func makeProjectFixture(
        projectIndex: Int,
        areasPerProject: Int,
        now: Date
    ) -> (
        record: PersistedProjectRecord,
        snapshot: RepoSnapshot,
        verification: [VerificationRecord],
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        decisions: [DecisionRecord],
        architecture: [ArchitectureItem],
        assumptions: [AssumptionRecord]
    ) {
        let projectID = deterministicID(namespace: 1, index: projectIndex)
        let projectName = "Scale Project \(projectIndex)"
        let rootPath = "/tmp/localforge-scale-\(projectIndex)"
        let freshDate = now.addingTimeInterval(-day)
        let expiredDate = now.addingTimeInterval(-220 * day)
        let userMission = UserMissionProfile(
            statedMission: "Keep a large workspace truth register deterministic",
            category: .developerTool,
            goals: ["stress truth aggregation", "preserve honest risk accounting"],
            currentPhase: "Release hardening",
            updatedAt: now
        )
        let identity = ProjectIdentity(
            kind: .swiftPackage,
            detail: "Synthetic truth scale fixture",
            ecosystems: ["SwiftPM"],
            markers: ["Package.swift"],
            confidence: .observed
        )
        let applicability = (0..<areasPerProject).map { areaIndex in
            ApplicabilityItem(
                area: areaName(projectIndex: projectIndex, areaIndex: areaIndex),
                status: areaIndex.isMultiple(of: 2) ? .required : .expected,
                priority: priority(for: areaIndex)
            )
        }
        let verification = applicability.enumerated().map { areaIndex, item in
            VerificationRecord(
                id: deterministicID(namespace: 10, index: projectIndex * areasPerProject + areaIndex),
                area: item.area,
                state: verificationState(for: areaIndex),
                note: "Scale fixture \(item.area)",
                verifiedBy: "Truth scale harness",
                updatedAt: areaIndex == 1 ? expiredDate : freshDate
            )
        }
        let evidence = verification.enumerated().map { areaIndex, record in
            EvidenceRecord(
                id: deterministicID(namespace: 20, index: projectIndex * areasPerProject + areaIndex),
                area: record.area,
                kind: .observation,
                summary: "Recorded evidence for \(record.area)",
                body: "Synthetic scale evidence for deterministic Truth Centre coverage.",
                linkedID: record.id,
                classification: .observed,
                author: "Truth scale harness",
                createdAt: freshDate,
                linkedVerificationIDs: [record.id]
            )
        }
        let risks = [
            RiskRecord(
                id: deterministicID(namespace: 30, index: projectIndex * 4),
                title: "Critical release blocker \(projectIndex)",
                likelihood: .high,
                impact: .critical,
                status: .open,
                linkedVerificationAreas: [verification[2].area],
                linkedVerificationIDs: [verification[2].id]
            ),
            RiskRecord(
                id: deterministicID(namespace: 30, index: projectIndex * 4 + 1),
                title: "High release watch \(projectIndex)",
                likelihood: .medium,
                impact: .high,
                status: .open,
                linkedVerificationAreas: [verification[7].area],
                linkedVerificationIDs: [verification[7].id]
            ),
            RiskRecord(
                id: deterministicID(namespace: 30, index: projectIndex * 4 + 2),
                title: "Mitigated compatibility concern \(projectIndex)",
                likelihood: .low,
                impact: .medium,
                status: .mitigated,
                linkedVerificationAreas: [verification[0].area],
                linkedVerificationIDs: [verification[0].id]
            ),
            RiskRecord(
                id: deterministicID(namespace: 30, index: projectIndex * 4 + 3),
                title: "Closed investigation \(projectIndex)",
                likelihood: .low,
                impact: .low,
                status: .closed
            ),
        ]
        let decisions = [
            DecisionRecord(
                id: deterministicID(namespace: 40, index: projectIndex * 3),
                title: "Require failed-area evidence before release \(projectIndex)",
                linkedEvidenceIDs: [evidence[2].id],
                linkedRiskIDs: [risks[0].id],
                linkedVerificationIDs: [verification[2].id]
            ),
            DecisionRecord(
                id: deterministicID(namespace: 40, index: projectIndex * 3 + 1),
                title: "Keep fresh build proof \(projectIndex)",
                linkedEvidenceIDs: [evidence[0].id],
                linkedVerificationIDs: [verification[0].id]
            ),
            DecisionRecord(
                id: deterministicID(namespace: 40, index: projectIndex * 3 + 2),
                title: "Track high release watch \(projectIndex)",
                linkedEvidenceIDs: [evidence[7].id],
                linkedRiskIDs: [risks[1].id],
                linkedVerificationIDs: [verification[7].id]
            ),
        ]
        let architecture = verification.enumerated().map { areaIndex, record in
            ArchitectureItem(
                id: deterministicID(namespace: 50, index: projectIndex * areasPerProject + areaIndex),
                name: "Subsystem \(projectIndex)-\(areaIndex)",
                subsystemType: subsystemType(for: areaIndex),
                purpose: "Back \(record.area)",
                status: .live,
                linkedVerificationAreas: [record.area],
                linkedEvidenceIDs: [evidence[areaIndex].id]
            )
        }
        let assumptions = [
            AssumptionRecord(
                id: deterministicID(namespace: 60, index: projectIndex * 4),
                assumption: "Failed area has a known release impact \(projectIndex)",
                status: .active,
                linkedVerificationArea: verification[2].area,
                linkedEvidenceIDs: [evidence[2].id],
                linkedRiskIDs: [risks[0].id],
                linkedVerificationIDs: [verification[2].id]
            ),
            AssumptionRecord(
                id: deterministicID(namespace: 60, index: projectIndex * 4 + 1),
                assumption: "High-risk area remains user-visible \(projectIndex)",
                status: .active,
                linkedVerificationArea: verification[7].area,
                linkedEvidenceIDs: [evidence[7].id],
                linkedRiskIDs: [risks[1].id],
                linkedVerificationIDs: [verification[7].id]
            ),
            AssumptionRecord(
                id: deterministicID(namespace: 60, index: projectIndex * 4 + 2),
                assumption: "Fresh proof covers the primary build path \(projectIndex)",
                status: .verified,
                linkedVerificationArea: verification[0].area,
                linkedEvidenceIDs: [evidence[0].id],
                linkedVerificationIDs: [verification[0].id]
            ),
            AssumptionRecord(
                id: deterministicID(namespace: 60, index: projectIndex * 4 + 3),
                assumption: "Old note has been superseded \(projectIndex)",
                status: .superseded
            ),
        ]
        let journal = [
            JournalEntry(
                id: deterministicID(namespace: 70, index: projectIndex * 2),
                kind: .verification,
                summary: "Recorded truth fixture \(projectIndex)",
                occurredAt: now
            ),
            JournalEntry(
                id: deterministicID(namespace: 70, index: projectIndex * 2 + 1),
                kind: .decision,
                summary: "Captured scale decision \(projectIndex)",
                occurredAt: now
            ),
        ]
        let record = PersistedProjectRecord(
            id: projectID,
            name: projectName,
            fallbackPath: rootPath,
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .saved,
            createdAt: now,
            lastOpenedAt: now,
            mission: userMission,
            verification: verification,
            journal: journal,
            evidence: evidence,
            decisions: decisions,
            architecture: architecture,
            risks: risks,
            assumptions: assumptions
        )
        let snapshot = RepoSnapshot(
            id: deterministicID(namespace: 80, index: projectIndex),
            project: ProjectContext(
                id: projectID,
                name: projectName,
                rootURL: URL(fileURLWithPath: rootPath),
                permission: .approved(scopeDescription: "truth scale fixture"),
                scanPolicy: .balanced,
                bookmarkStatus: .saved
            ),
            scannedAt: now,
            permissionState: .approved,
            scanPolicy: .balanced,
            identity: identity,
            mission: userMission.asMissionProfile(),
            userMission: userMission,
            applicability: applicability,
            verification: verification,
            reality: .unknown,
            git: GitStatus(isRepository: true, branch: "main", hasUpstream: true),
            summary: RepoSummary(totalFiles: 120, sourceFiles: 60, testFiles: 30, documentationFiles: 10),
            findings: [],
            evidence: [
                Evidence(
                    id: deterministicID(namespace: 90, index: projectIndex),
                    title: "Read-only scan \(projectIndex)",
                    detail: rootPath,
                    classification: .observed,
                    source: "truth scale fixture",
                    collectedAt: now
                )
            ]
        )

        return (record, snapshot, verification, evidence, risks, decisions, architecture, assumptions)
    }

    private func rescoreSnapshots(_ fixture: LargeTruthFixture) -> [RepoSnapshot] {
        let realityEngine = RealityEngine()
        return fixture.snapshots.enumerated().map { index, snapshot in
            let record = fixture.records[index]
            var rescored = snapshot
            rescored.reality = realityEngine.assess(
                identity: snapshot.identity,
                mission: snapshot.mission,
                applicability: snapshot.applicability,
                git: snapshot.git,
                summary: snapshot.summary,
                findings: snapshot.findings,
                evidence: snapshot.evidence,
                verification: record.verification ?? [],
                evidenceRecords: record.evidence ?? [],
                riskRecords: record.risks ?? [],
                assumptionRecords: record.assumptions ?? []
            )
            return rescored
        }
    }

    private var day: TimeInterval { 86_400 }

    private func verificationState(for areaIndex: Int) -> VerificationState {
        switch areaIndex % 5 {
        case 0, 1: .verified
        case 2: .failed
        case 3: .unknown
        default: .inProgress
        }
    }

    private func priority(for areaIndex: Int) -> VerificationPriority {
        switch areaIndex % 5 {
        case 0, 2: .critical
        case 1: .high
        case 3: .medium
        default: .low
        }
    }

    private func subsystemType(for areaIndex: Int) -> SubsystemType {
        switch areaIndex % 5 {
        case 0: .buildSystem
        case 1: .persistence
        case 2: .securityBoundary
        case 3: .dataModel
        default: .appShell
        }
    }

    private func areaName(projectIndex: Int, areaIndex: Int) -> String {
        "Project \(projectIndex) Truth Area \(areaIndex)"
    }

    private func contributionSignature(_ contributions: [RealityContribution]) -> [String] {
        contributions.map { "\($0.label)|\($0.delta)" }
    }

    private func deterministicID(namespace: Int, index: Int) -> UUID {
        let value = UInt64(namespace) * 1_000_000 + UInt64(index)
        let hex = String(value, radix: 16)
        let suffix = String(repeating: "0", count: 12 - hex.count) + hex
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
    }
}
