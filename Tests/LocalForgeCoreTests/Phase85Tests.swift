import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Phase 8.5 — Truth refinement engines")
struct Phase85Tests {

    // MARK: - Command Palette

    @Test("command palette finds projects, verification, risks, and decisions by fuzzy substring")
    func commandPaletteFuzzy() {
        let projectID = UUID()
        let record = PersistedProjectRecord(
            id: projectID,
            name: "AudioPro",
            fallbackPath: "/tmp/audiopro",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .saved,
            verification: [VerificationRecord(area: "Preset System", state: .verified)],
            decisions: [DecisionRecord(title: "Adopt SwiftData")],
            risks: [RiskRecord(title: "AU state restoration fails on quit", impact: .high)]
        )
        let engine = CommandPaletteEngine()
        let names = [projectID: "AudioPro"]

        let projHits = engine.items(query: "audio", records: [record], projectNames: names)
        #expect(projHits.contains { $0.kind == .project && $0.title == "AudioPro" })

        let verHits = engine.items(query: "preset", records: [record], projectNames: names)
        #expect(verHits.contains { $0.kind == .verification })

        let riskHits = engine.items(query: "au state", records: [record], projectNames: names)
        #expect(riskHits.contains { $0.kind == .risk })

        let actionHits = engine.items(query: "open workspace health", records: [record], projectNames: names)
        #expect(actionHits.contains { $0.actionKind == .openWorkspaceHealth })
    }

    @Test("command palette handles empty query by returning actions")
    func commandPaletteEmpty() {
        let engine = CommandPaletteEngine()
        let items = engine.items(query: "", records: [], projectNames: [:])
        #expect(items.contains { $0.kind == .action })
    }

    // MARK: - Workspace Health Engine

    @Test("workspace health detects stale verification, failed verification, and missing mitigation")
    func workspaceHealthDetects() {
        let pid = UUID()
        let oldDate = Date().addingTimeInterval(-180 * 86_400)
        let record = PersistedProjectRecord(
            id: pid,
            name: "App",
            fallbackPath: "/tmp",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .saved,
            mission: UserMissionProfile(statedMission: "Test mission"),
            verification: [
                VerificationRecord(area: "Old Area", state: .verified, updatedAt: oldDate),
                VerificationRecord(area: "Broken", state: .failed, updatedAt: Date()),
            ],
            risks: [RiskRecord(title: "No mitigation", status: .open, mitigation: "")]
        )

        let engine = WorkspaceHealthEngine()
        let report = engine.report(projects: [record], projectNames: [pid: "App"])

        #expect(report.issues(for: .truthDecay).contains { $0.title.contains("stale") })
        #expect(report.issues(for: .truthDecay).contains { $0.title.contains("failed") })
        #expect(report.issues(for: .registerDecay).contains { $0.title.contains("mitigation") })
    }

    @Test("workspace health flags missing mission only when verification exists")
    func workspaceHealthMissionFlag() {
        let pid = UUID()
        let record = PersistedProjectRecord(
            id: pid, name: "P", fallbackPath: "/tmp",
            bookmarkData: nil, scanPolicy: .balanced, bookmarkStatus: .saved,
            verification: [VerificationRecord(area: "AU", state: .unknown)]
        )
        let report = WorkspaceHealthEngine().report(projects: [record], projectNames: [pid: "P"])
        #expect(report.issues.contains { $0.title.contains("mission") })
    }

    // MARK: - Workspace Doctor

    @Test("workspace doctor detects broken cross-links and broken dependency chains")
    func workspaceDoctorBrokenLinks() {
        let pid = UUID()
        let missingID = UUID()
        let record = PersistedProjectRecord(
            id: pid, name: "P", fallbackPath: "/tmp",
            bookmarkData: nil, scanPolicy: .balanced, bookmarkStatus: .saved,
            verification: [VerificationRecord(area: "A", dependsOn: ["DoesNotExist"])],
            risks: [RiskRecord(title: "R", linkedEvidenceIDs: [missingID])]
        )
        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "P"])
        #expect(report.issues.contains { $0.kind == .brokenLink })
        #expect(report.issues.contains { $0.kind == .brokenDependencyChain })
    }

    @Test("workspace doctor detects duplicate verification areas")
    func workspaceDoctorDuplicates() {
        let pid = UUID()
        let record = PersistedProjectRecord(
            id: pid, name: "P", fallbackPath: "/tmp",
            bookmarkData: nil, scanPolicy: .balanced, bookmarkStatus: .saved,
            verification: [
                VerificationRecord(area: "Preset System"),
                VerificationRecord(area: "preset system"),
            ]
        )
        let report = WorkspaceDoctorEngine().diagnose(records: [record], projectNames: [pid: "P"])
        #expect(report.issues.contains { $0.kind == .duplicateRecord })
    }

    // MARK: - Why Engine

    @Test("why engine surfaces evidence + verification for a verification record")
    func whyVerificationIncludesEvidence() {
        let area = "AU Validation"
        let record = VerificationRecord(area: area, state: .verified)
        let evidence = [EvidenceRecord(area: area, summary: "auval passes")]
        let why = WhyEngine().whyVerification(record: record, evidence: evidence, journal: [])
        #expect(why.title.contains(area))
        #expect(why.sections.contains { $0.title.localizedCaseInsensitiveContains("evidence") })
    }

    @Test("why engine builds confidence provenance from evidence classifications")
    func confidenceProvenance() {
        let evidence = [
            EvidenceRecord(area: "A", summary: "x", classification: .observed),
            EvidenceRecord(area: "A", summary: "y", classification: .measured),
            EvidenceRecord(area: "A", summary: "z", classification: .verified),
        ]
        let assessment = ConfidenceAssessment(score: 80, label: "High", summary: "", contributions: [])
        let provenance = WhyEngine().confidenceProvenance(assessment: assessment, evidence: evidence)
        #expect(provenance.score == 80)
        #expect(provenance.items.count >= 3)
    }

    @Test("why engine detects contradictory evidence within a single area")
    func contradictoryEvidence() {
        let pid = UUID()
        let evidence = [
            EvidenceRecord(area: "AU", summary: "passes test", classification: .observed),
            EvidenceRecord(area: "AU", summary: "fails reproducibly", classification: .observed),
        ]
        let conflicts = WhyEngine().detectConflicts(evidence: evidence, projectID: pid, projectName: "P")
        #expect(!conflicts.isEmpty)
        #expect(conflicts.first?.area == "AU")
    }

    // MARK: - Backup Engine

    @Test("backup engine creates, lists, and deletes backups locally")
    func backupRoundTrip() throws {
        let tmpSource = FileManager.default.temporaryDirectory
            .appendingPathComponent("backup-test-\(UUID().uuidString).sqlite")
        try Data("hello".utf8).write(to: tmpSource)
        defer { try? FileManager.default.removeItem(at: tmpSource) }

        let engine = BackupEngine()
        let record = try engine.createBackup(from: tmpSource, note: "unit test")
        defer { try? engine.delete(backup: record) }

        let list = try engine.listBackups()
        #expect(list.contains { $0.filename == record.filename })
    }

    // MARK: - Build / Environment / Test models

    @Test("build record durationDisplay handles short and long durations")
    func buildDuration() {
        let start = Date()
        let short = BuildRecord(buildType: .swiftBuild, startTime: start, endTime: start.addingTimeInterval(25))
        let long = BuildRecord(buildType: .swiftTest, startTime: start, endTime: start.addingTimeInterval(125))
        #expect(short.durationDisplay == "25s")
        #expect(long.durationDisplay.contains("m"))
    }

    @Test("environment snapshot comparison identifies changed toolchain fields")
    func environmentComparison() {
        let previous = EnvironmentSnapshot(
            macOSVersion: "14.5",
            xcodeVersion: "15.4",
            swiftVersion: "5.10",
            sdkVersion: "14.5",
            auValVersion: "1.10"
        )
        let current = EnvironmentSnapshot(
            macOSVersion: "15.0",
            xcodeVersion: "16.0",
            swiftVersion: "6.0",
            sdkVersion: "15.0",
            auValVersion: "1.10"
        )

        let diffs = current.comparison(to: previous)
        #expect(diffs.filter { $0.changed }.map(\.field) == ["macOS", "Xcode", "Swift", "SDK"])
        #expect(diffs.first { $0.field == "auval" }?.changed == false)
    }

    @Test("theme preferences decode diagnostic background defaults from older saved JSON")
    func themePreferencesDecodeDiagnosticDefaults() throws {
        let json = Data("""
        {
          "appearance": "Dark",
          "accentName": "Blue",
          "brightnessAdjustment": 2
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(ThemePreferences.self, from: json)

        #expect(decoded.animatedDiagnosticBackground)
        #expect(decoded.diagnosticBackgroundIntensity == .medium)
        #expect(decoded.diagnosticBackgroundDensity == .balanced)
        #expect(decoded.diagnosticBackgroundMotion == .slow)
        #expect(decoded.reduceDiagnosticBackgroundWhenInactive)
    }

    @Test("theme preferences persist diagnostic intensity density and motion")
    func themePreferencesPersistDiagnosticControls() throws {
        let prefs = ThemePreferences(
            appearance: .dark,
            accentName: "Blue",
            brightnessAdjustment: 0,
            animatedDiagnosticBackground: true,
            diagnosticBackgroundIntensity: .high,
            diagnosticBackgroundDensity: .dense,
            diagnosticBackgroundMotion: .medium,
            reduceDiagnosticBackgroundWhenInactive: false
        )

        let encoded = try JSONEncoder().encode(prefs)
        let decoded = try JSONDecoder().decode(ThemePreferences.self, from: encoded)

        #expect(decoded == prefs)
    }

    @Test("test outcomes describe release readiness impact including blocked")
    func testOutcomeReleaseImpact() {
        #expect(TestOutcome.passed.releaseReadinessImpact.contains("confidence"))
        #expect(TestOutcome.failed.releaseReadinessImpact.localizedCaseInsensitiveContains("blocks"))
        #expect(TestOutcome.blocked.releaseReadinessImpact.localizedCaseInsensitiveContains("blocks"))
        #expect(TestOutcome.unknown.releaseReadinessImpact.localizedCaseInsensitiveContains("verification"))
    }
}
