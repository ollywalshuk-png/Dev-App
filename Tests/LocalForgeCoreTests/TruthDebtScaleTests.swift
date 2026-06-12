import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Truth debt scale tests")
struct TruthDebtScaleTests {
    @Test("large synthetic truth debt fixture remains deterministic and read-only")
    func largeSyntheticTruthDebtFixtureRemainsDeterministicAndReadOnly() {
        let fixture = makeLargeTruthDebtFixture(projectCount: 240, areasPerProject: 12)
        let originalSnapshots = fixture.snapshots
        let originalEvidence = fixture.evidenceByProject
        let originalRisks = fixture.risksByProject
        let originalAssumptions = fixture.assumptionsByProject
        let engine = TruthDebtEngine()

        let startedAt = Date()
        let reports = makeReports(for: fixture, using: engine)
        let repeatedReports = makeReports(for: fixture, using: engine)
        let elapsed = Date().timeIntervalSince(startedAt)

        let gates = reports.flatMap(\.gates)
        let repeatedGates = repeatedReports.flatMap(\.gates)
        let signature = orderedSignature(for: reports)

        #expect(fixture.snapshots.count == 240)
        #expect(fixture.snapshots.flatMap(\.verification).count == 2_880)
        #expect(fixture.evidenceByProject.flatMap { $0 }.count == 3_120)
        #expect(fixture.risksByProject.flatMap { $0 }.count == 960)
        #expect(fixture.assumptionsByProject.flatMap { $0 }.count == 960)

        #expect(reports == repeatedReports)
        #expect(gates == repeatedGates)
        #expect(signature == orderedSignature(for: repeatedReports))
        #expect(signatureHash(signature) == "c3fbe55934abb772")
        #expect(reports.allSatisfy { $0.status == .blocked })
        #expect(reports.filter { $0.gates.count == 20 }.count == 60)
        #expect(reports.filter { $0.gates.count == 19 }.count == 180)
        #expect(gates.count == 4_620)
        #expect(gates.filter(\.blocksReleaseClaim).count == 2_940)
        #expect(gates.filter { !$0.blocksReleaseClaim }.count == 1_680)

        let expectedKindCounts: [TruthDebtKind: Int] = [
            .missingMission: 60,
            .missingEvidence: 480,
            .unverifiedArea: 960,
            .failedVerification: 240,
            .staleVerification: 720,
            .blockedDependency: 720,
            .releaseBlockingRisk: 480,
            .activeAssumption: 720,
            .contradictoryEvidence: 240,
        ]
        #expect(kindCounts(for: gates) == expectedKindCounts)

        let expectedSeverityCounts: [TruthDebtSeverity: Int] = [
            .critical: 1_680,
            .high: 1_740,
            .medium: 720,
            .low: 480,
        ]
        #expect(severityCounts(for: gates) == expectedSeverityCounts)
        #expect(reports.allSatisfy(hasStableTruthDebtOrdering))
        #expect(Array(signature.prefix(3)) == [
            "0000|Stale Verification|Critical|true|P0000 Truth Area 01|P0000 Truth Area 01 verification is expired",
            "0000|Failed Verification|Critical|true|P0000 Truth Area 02|P0000 Truth Area 02 is failed",
            "0000|Release-Blocking Risk|Critical|true|P0000 Truth Area 02|Release blocker A 0000",
        ])
        #expect(Array(signature.suffix(3)) == [
            "0239|Missing Evidence|Medium|false|P0239 Truth Area 08|P0239 Truth Area 08 is verified without strong evidence",
            "0239|Stale Verification|Low|false|P0239 Truth Area 05|P0239 Truth Area 05 verification is stale",
            "0239|Unverified Area|Low|false|P0239 Truth Area 09|P0239 Truth Area 09 is Unknown",
        ])

        #expect(fixture.snapshots == originalSnapshots)
        #expect(fixture.evidenceByProject == originalEvidence)
        #expect(fixture.risksByProject == originalRisks)
        #expect(fixture.assumptionsByProject == originalAssumptions)
        #expect(
            elapsed < 6,
            "TruthDebtEngine scale pass took \(elapsed)s; investigate accidental superlinear work."
        )
    }

    private struct LargeTruthDebtFixture {
        var projectCount: Int
        var areasPerProject: Int
        var snapshots: [RepoSnapshot]
        var evidenceByProject: [[EvidenceRecord]]
        var risksByProject: [[RiskRecord]]
        var assumptionsByProject: [[AssumptionRecord]]
    }

    private func makeLargeTruthDebtFixture(projectCount: Int, areasPerProject: Int) -> LargeTruthDebtFixture {
        precondition(areasPerProject == 12, "Truth debt scale fixture expects exactly 12 areas per project.")

        let now = Date()
        var snapshots: [RepoSnapshot] = []
        var evidenceByProject: [[EvidenceRecord]] = []
        var risksByProject: [[RiskRecord]] = []
        var assumptionsByProject: [[AssumptionRecord]] = []

        snapshots.reserveCapacity(projectCount)
        evidenceByProject.reserveCapacity(projectCount)
        risksByProject.reserveCapacity(projectCount)
        assumptionsByProject.reserveCapacity(projectCount)

        for projectIndex in 0..<projectCount {
            let project = makeProjectFixture(projectIndex: projectIndex, now: now)
            snapshots.append(project.snapshot)
            evidenceByProject.append(project.evidence)
            risksByProject.append(project.risks)
            assumptionsByProject.append(project.assumptions)
        }

        return LargeTruthDebtFixture(
            projectCount: projectCount,
            areasPerProject: areasPerProject,
            snapshots: snapshots,
            evidenceByProject: evidenceByProject,
            risksByProject: risksByProject,
            assumptionsByProject: assumptionsByProject
        )
    }

    private func makeProjectFixture(
        projectIndex: Int,
        now: Date
    ) -> (
        snapshot: RepoSnapshot,
        evidence: [EvidenceRecord],
        risks: [RiskRecord],
        assumptions: [AssumptionRecord]
    ) {
        let projectKey = padded(projectIndex)
        let projectID = deterministicID(namespace: 1, index: projectIndex)
        let rootPath = "/tmp/localforge-truth-debt-scale-\(projectKey)"
        let freshDate = now.addingTimeInterval(-day)
        let staleDate = now.addingTimeInterval(-120 * day)
        let expiredDate = now.addingTimeInterval(-220 * day)
        let mission = projectIndex.isMultiple(of: 4)
            ? nil
            : UserMissionProfile(
                statedMission: "Keep synthetic truth debt reporting deterministic",
                category: .developerTool,
                goals: ["stress TruthDebtEngine", "preserve stable release gates"],
                currentPhase: "Scale validation",
                updatedAt: now
            )
        let applicability = (0..<12).map { areaIndex in
            let priority = priority(for: areaIndex)
            return ApplicabilityItem(
                area: areaName(projectIndex: projectIndex, areaIndex: areaIndex),
                status: priority == .critical || priority == .high ? .required : .expected,
                priority: priority
            )
        }
        let verification = applicability.enumerated().map { areaIndex, item in
            VerificationRecord(
                id: deterministicID(namespace: 10, index: projectIndex * 100 + areaIndex),
                area: item.area,
                state: verificationState(for: areaIndex),
                note: "Synthetic truth debt fixture \(projectKey)-\(areaIndex)",
                verifiedBy: "Truth debt scale harness",
                updatedAt: verificationDate(for: areaIndex, fresh: freshDate, stale: staleDate, expired: expiredDate),
                dependsOn: dependencies(for: areaIndex, projectIndex: projectIndex)
            )
        }
        let evidence = makeEvidence(projectIndex: projectIndex, verification: verification, createdAt: freshDate)
        let risks = makeRisks(projectIndex: projectIndex, verification: verification, now: now)
        let assumptions = makeAssumptions(
            projectIndex: projectIndex,
            verification: verification,
            risks: risks,
            now: now
        )
        let snapshot = RepoSnapshot(
            id: deterministicID(namespace: 80, index: projectIndex),
            project: ProjectContext(
                id: projectID,
                name: "Truth Debt Scale \(projectKey)",
                rootURL: URL(fileURLWithPath: rootPath),
                permission: .approved(scopeDescription: "truth debt scale fixture"),
                scanPolicy: .balanced,
                bookmarkStatus: .saved
            ),
            scannedAt: now,
            permissionState: .approved,
            scanPolicy: .balanced,
            identity: ProjectIdentity(
                kind: .swiftPackage,
                detail: "Synthetic TruthDebtEngine scale fixture",
                ecosystems: ["SwiftPM"],
                markers: ["Package.swift"],
                confidence: .observed
            ),
            mission: mission?.asMissionProfile() ?? .unknown,
            userMission: mission,
            applicability: applicability,
            verification: verification,
            reality: .unknown,
            git: GitStatus(isRepository: true, branch: "main", hasUpstream: true),
            summary: RepoSummary(totalFiles: 96, sourceFiles: 48, testFiles: 24, documentationFiles: 8),
            findings: [],
            evidence: [
                Evidence(
                    id: deterministicID(namespace: 90, index: projectIndex),
                    title: "Read-only synthetic scan \(projectKey)",
                    detail: rootPath,
                    classification: .observed,
                    source: "truth debt scale fixture",
                    collectedAt: now
                )
            ]
        )

        return (snapshot, evidence, risks, assumptions)
    }

    private func makeEvidence(
        projectIndex: Int,
        verification: [VerificationRecord],
        createdAt: Date
    ) -> [EvidenceRecord] {
        var evidence: [EvidenceRecord] = []
        evidence.reserveCapacity(13)

        for (areaIndex, record) in verification.enumerated() {
            evidence.append(EvidenceRecord(
                id: deterministicID(namespace: 20, index: projectIndex * 100 + areaIndex),
                area: record.area,
                kind: .observation,
                summary: evidenceSummary(for: areaIndex, record: record, failure: false),
                body: "Synthetic evidence record for deterministic truth debt scale coverage.",
                linkedID: record.id,
                classification: evidenceClassification(for: areaIndex),
                author: "Truth debt scale harness",
                createdAt: createdAt,
                linkedVerificationIDs: [record.id]
            ))

            if areaIndex == 6 {
                evidence.append(EvidenceRecord(
                    id: deterministicID(namespace: 21, index: projectIndex * 100 + areaIndex),
                    area: record.area,
                    kind: .logExcerpt,
                    summary: evidenceSummary(for: areaIndex, record: record, failure: true),
                    body: "The same check fails in the release lane.",
                    linkedID: record.id,
                    classification: .measured,
                    author: "Truth debt scale harness",
                    createdAt: createdAt,
                    linkedVerificationIDs: [record.id]
                ))
            }
        }

        return evidence
    }

    private func makeRisks(
        projectIndex: Int,
        verification: [VerificationRecord],
        now: Date
    ) -> [RiskRecord] {
        let projectKey = padded(projectIndex)

        return [
            RiskRecord(
                id: deterministicID(namespace: 30, index: projectIndex * 10),
                title: "Release blocker A \(projectKey)",
                likelihood: .high,
                impact: .critical,
                status: .open,
                linkedVerificationAreas: [verification[2].area],
                createdAt: now,
                updatedAt: now,
                linkedVerificationIDs: [verification[2].id]
            ),
            RiskRecord(
                id: deterministicID(namespace: 30, index: projectIndex * 10 + 1),
                title: "Release blocker B \(projectKey)",
                likelihood: .medium,
                impact: .high,
                status: .open,
                linkedVerificationAreas: [verification[6].area],
                createdAt: now,
                updatedAt: now,
                linkedVerificationIDs: [verification[6].id]
            ),
            RiskRecord(
                id: deterministicID(namespace: 30, index: projectIndex * 10 + 2),
                title: "Low likelihood watch \(projectKey)",
                likelihood: .low,
                impact: .high,
                status: .open,
                linkedVerificationAreas: [verification[4].area],
                createdAt: now,
                updatedAt: now,
                linkedVerificationIDs: [verification[4].id]
            ),
            RiskRecord(
                id: deterministicID(namespace: 30, index: projectIndex * 10 + 3),
                title: "Mitigated critical watch \(projectKey)",
                likelihood: .high,
                impact: .critical,
                status: .mitigated,
                linkedVerificationAreas: [verification[11].area],
                createdAt: now,
                updatedAt: now,
                linkedVerificationIDs: [verification[11].id]
            ),
        ]
    }

    private func makeAssumptions(
        projectIndex: Int,
        verification: [VerificationRecord],
        risks: [RiskRecord],
        now: Date
    ) -> [AssumptionRecord] {
        let projectKey = padded(projectIndex)

        return [
            AssumptionRecord(
                id: deterministicID(namespace: 60, index: projectIndex * 10),
                assumption: "Assumption A \(projectKey)",
                status: .active,
                linkedVerificationArea: verification[2].area,
                createdAt: now,
                updatedAt: now,
                linkedRiskIDs: [risks[0].id],
                linkedVerificationIDs: [verification[2].id]
            ),
            AssumptionRecord(
                id: deterministicID(namespace: 60, index: projectIndex * 10 + 1),
                assumption: "Assumption B \(projectKey)",
                status: .active,
                linkedVerificationArea: verification[4].area,
                createdAt: now,
                updatedAt: now,
                linkedRiskIDs: [risks[2].id],
                linkedVerificationIDs: [verification[4].id]
            ),
            AssumptionRecord(
                id: deterministicID(namespace: 60, index: projectIndex * 10 + 2),
                assumption: "Assumption C \(projectKey)",
                status: .active,
                linkedVerificationArea: verification[10].area,
                createdAt: now,
                updatedAt: now,
                linkedVerificationIDs: [verification[10].id]
            ),
            AssumptionRecord(
                id: deterministicID(namespace: 60, index: projectIndex * 10 + 3),
                assumption: "Verified assumption \(projectKey)",
                status: .verified,
                linkedVerificationArea: verification[0].area,
                createdAt: now,
                updatedAt: now,
                linkedVerificationIDs: [verification[0].id]
            ),
        ]
    }

    private func makeReports(for fixture: LargeTruthDebtFixture, using engine: TruthDebtEngine) -> [TruthDebtReport] {
        fixture.snapshots.enumerated().map { projectIndex, snapshot in
            engine.report(
                snapshot: snapshot,
                evidence: fixture.evidenceByProject[projectIndex],
                risks: fixture.risksByProject[projectIndex],
                assumptions: fixture.assumptionsByProject[projectIndex]
            )
        }
    }

    private func hasStableTruthDebtOrdering(_ report: TruthDebtReport) -> Bool {
        zip(report.gates, report.gates.dropFirst()).allSatisfy { lhs, rhs in
            if lhs.blocksReleaseClaim != rhs.blocksReleaseClaim {
                return lhs.blocksReleaseClaim && !rhs.blocksReleaseClaim
            }
            if lhs.severity != rhs.severity { return lhs.severity < rhs.severity }
            if lhs.area != rhs.area { return lhs.area < rhs.area }
            return lhs.title <= rhs.title
        }
    }

    private func orderedSignature(for reports: [TruthDebtReport]) -> [String] {
        reports.enumerated().flatMap { projectIndex, report in
            report.gates.map { gate in
                [
                    padded(projectIndex),
                    gate.kind.rawValue,
                    gate.severity.rawValue,
                    String(gate.blocksReleaseClaim),
                    gate.area,
                    gate.title,
                ].joined(separator: "|")
            }
        }
    }

    private func signatureHash(_ signature: [String]) -> String {
        var hash: UInt64 = 14_695_981_039_346_656_037
        let prime: UInt64 = 1_099_511_628_211

        for line in signature {
            for byte in line.utf8 {
                hash ^= UInt64(byte)
                hash &*= prime
            }
            hash ^= 10
            hash &*= prime
        }

        return String(format: "%016llx", hash)
    }

    private func kindCounts(for gates: [TruthDebtGate]) -> [TruthDebtKind: Int] {
        gates.reduce(into: [:]) { counts, gate in
            counts[gate.kind, default: 0] += 1
        }
    }

    private func severityCounts(for gates: [TruthDebtGate]) -> [TruthDebtSeverity: Int] {
        gates.reduce(into: [:]) { counts, gate in
            counts[gate.severity, default: 0] += 1
        }
    }

    private func verificationState(for areaIndex: Int) -> VerificationState {
        switch areaIndex {
        case 0, 1, 5, 6, 7, 8, 11: .verified
        case 2: .failed
        case 3, 9: .unknown
        case 4, 10: .inProgress
        default: .unknown
        }
    }

    private func priority(for areaIndex: Int) -> VerificationPriority {
        switch areaIndex {
        case 0, 2, 7, 11: .critical
        case 1, 3, 6, 10: .high
        case 4, 8: .medium
        case 5, 9: .low
        default: .medium
        }
    }

    private func verificationDate(for areaIndex: Int, fresh: Date, stale: Date, expired: Date) -> Date {
        switch areaIndex {
        case 1, 11: expired
        case 5: stale
        default: fresh
        }
    }

    private func dependencies(for areaIndex: Int, projectIndex: Int) -> [String] {
        switch areaIndex {
        case 4, 10: [areaName(projectIndex: projectIndex, areaIndex: 2)]
        case 9: [areaName(projectIndex: projectIndex, areaIndex: 3)]
        default: []
        }
    }

    private func evidenceClassification(for areaIndex: Int) -> EvidenceClassification {
        switch areaIndex {
        case 1: .assumed
        case 8: .inferred
        default: .measured
        }
    }

    private func evidenceSummary(for areaIndex: Int, record: VerificationRecord, failure: Bool) -> String {
        if areaIndex == 6, failure {
            return "\(record.area) fails release validation"
        }
        if areaIndex == 6 {
            return "\(record.area) passes release validation"
        }
        return "Neutral evidence for \(record.area)"
    }

    private func areaName(projectIndex: Int, areaIndex: Int) -> String {
        "P\(padded(projectIndex)) Truth Area \(String(format: "%02d", areaIndex))"
    }

    private func padded(_ value: Int) -> String {
        String(format: "%04d", value)
    }

    private var day: TimeInterval { 86_400 }

    private func deterministicID(namespace: Int, index: Int) -> UUID {
        let value = UInt64(namespace) * 1_000_000 + UInt64(index)
        let hex = String(value, radix: 16)
        let suffix = String(repeating: "0", count: 12 - hex.count) + hex
        return UUID(uuidString: "00000000-0000-0000-0000-\(suffix)")!
    }
}
