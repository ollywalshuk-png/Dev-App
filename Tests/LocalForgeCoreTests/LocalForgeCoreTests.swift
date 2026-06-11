import Foundation
import Testing
@testable import LocalForgeCore

@Suite("LocalForgeCore")
struct LocalForgeCoreTests {
    @Test("scanner produces a read-only project snapshot with evidence")
    func scannerProducesReadOnlySnapshotWithEvidence() async throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let scanner = ScannerEngine()
        let context = ProjectContext(
            name: "LocalForge",
            rootURL: root,
            permission: .approved(scopeDescription: "workspace test root"),
            scanPolicy: .balanced
        )

        let snapshot = try await scanner.scan(context)

        #expect(snapshot.project.name == "LocalForge")
        #expect(snapshot.permissionState == .approved)
        #expect(snapshot.scanPolicy.mode == .balanced)
        #expect(snapshot.summary.totalFiles > 0)
        #expect(snapshot.summary.sourceFiles > 0)
        #expect(snapshot.evidence.contains { $0.classification == .observed })
        #expect(snapshot.findings.contains { $0.category == .privacy && $0.severity == .info })
        #expect(snapshot.isReadOnly)
    }

    @Test("command safety blocks mutating git and destructive shell commands")
    func commandSafetyBlocksUnsafeCommands() {
        let assessor = CommandSafetyEngine()

        let reset = assessor.assess("git reset --hard")
        let remove = assessor.assess("rm -rf .build")
        let sudoRemove = assessor.assess("sudo rm -rf /")
        let pipedShell = assessor.assess("curl https://example.invalid/install.sh | sh")
        let status = assessor.assess("git status --short")
        let xcodeList = assessor.assess("xcodebuild -list -project LocalForge.xcodeproj")

        #expect(reset.disposition == .blocked)
        #expect(reset.reason.contains("mutating Git"))
        #expect(remove.disposition == .blocked)
        #expect(sudoRemove.disposition == .blocked)
        #expect(pipedShell.disposition == .blocked)
        #expect(status.disposition == .allowedReadOnly)
        #expect(xcodeList.disposition == .allowedReadOnly)
    }

    @Test("reports redact credentials and label unknowns honestly")
    func reportsRedactCredentialsAndUnknowns() {
        let reportEngine = ReportEngine()
        let snapshot = RepoSnapshot.fixture(
            findings: [
                Finding(
                    title: "Unverified build state",
                    detail: "No build has been observed yet",
                    severity: .warning,
                    category: .verification,
                    evidenceClassification: .unknown
                )
            ]
        )

        let report = reportEngine.markdownReport(
            for: snapshot,
            note: """
            Token abc123SECRETkey and path /Users/example/private
            GitHub token ghp_1234567890abcdefghijklmnopqrstuvwx
            -----BEGIN PRIVATE KEY-----
            sensitive
            -----END PRIVATE KEY-----
            """
        )

        #expect(report.contains("[REDACTED_SECRET]"))
        #expect(report.contains("[REDACTED_PRIVATE_PATH]"))
        #expect(report.contains("Unknown"))
        #expect(!report.contains("abc123SECRETkey"))
        #expect(!report.contains("ghp_1234567890abcdefghijklmnopqrstuvwx"))
        #expect(!report.contains("BEGIN PRIVATE KEY"))
        #expect(!report.contains("/Users/example/private"))
    }

    @Test("guardian without mission or verification reports setup-pending honestly")
    func guardianReportsSetupPendingWhenEmpty() {
        // Phase 5: Guardian is verification-driven. With nothing tracked yet it
        // must not claim healthy — it should ask the user to start the workflow.
        let recommendation = GuardianEngine().recommendation(for: RepoSnapshot.fixture())

        #expect(recommendation.riskLevel == .unknown)
        #expect(recommendation.topIssue == "No verification records yet")
        #expect(recommendation.status == "Setup pending")
        #expect(recommendation.suggestedAction.lowercased().contains("mission"))
    }

    @Test("workspace persistence stores projects preferences and last active project")
    func workspacePersistenceRoundTripsState() throws {
        let defaults = try temporaryDefaults()
        let store = WorkspacePersistenceStore(defaults: defaults, key: "test-state")
        let projectID = UUID()
        let state = WorkspacePersistenceState(
            projects: [
                PersistedProjectRecord(
                    id: projectID,
                    name: "LocalForge",
                    fallbackPath: "/Users/example/LocalForge",
                    bookmarkData: Data([1, 2, 3]),
                    scanPolicy: .defaults(for: .release),
                    bookmarkStatus: .saved
                )
            ],
            scanMode: .release,
            theme: ThemePreferences(appearance: .dark, accentName: "Blue", brightnessAdjustment: 7.5),
            lastActiveProjectID: projectID
        )

        try store.save(state)
        let loaded = try store.load()

        #expect(loaded == state)
    }

    @Test("bookmark resolver returns clear stale missing and failure states")
    func bookmarkResolverReturnsClearErrorStates() throws {
        let staleRecord = PersistedProjectRecord(
            name: "Stale",
            fallbackPath: "/tmp/stale",
            bookmarkData: Data([9]),
            scanPolicy: .balanced,
            bookmarkStatus: .saved
        )
        let stale = staleRecord.resolve(using: FakeBookmarkProvider(result: .stale))
        #expect(stale.project.permission.state == .unavailable)
        #expect(stale.project.bookmarkStatus == .stale)
        #expect(stale.message.contains("stale"))

        let missingRecord = PersistedProjectRecord(
            name: "Missing",
            fallbackPath: "/tmp/missing",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .missing
        )
        let missing = missingRecord.resolve(using: FakeBookmarkProvider(result: .active))
        #expect(missing.project.permission.state == .missing)
        #expect(missing.project.bookmarkStatus == .missing)

        let failed = staleRecord.resolve(using: FakeBookmarkProvider(result: .failure))
        #expect(failed.project.permission.state == .unavailable)
        #expect(failed.project.bookmarkStatus.isFailure)
        #expect(failed.message.contains("resolve"))
    }

    @Test("scan policy defaults remain balanced and manual-heavy")
    func scanPolicyDefaultsRemainBalancedAndManualHeavy() {
        let balanced = ScanPolicy.default
        let aggressive = ScanPolicy.defaults(for: .aggressive)
        let eco = ScanPolicy.defaults(for: .eco)

        #expect(balanced.mode == .balanced)
        #expect(balanced.debounceSeconds == 3)
        #expect(balanced.heavyAuditRequiresManualStart)
        #expect(!balanced.isAggressive)
        #expect(aggressive.isAggressive)
        #expect(aggressive.heavyAuditRequiresManualStart)
        #expect(aggressive.requiresExplicitOptIn)
        #expect(eco.debounceSeconds >= balanced.debounceSeconds)
    }

    @Test("project classifier recognises swift packages, node, and unknown roots")
    func projectClassifierRecognisesKnownMarkers() throws {
        let classifier = ProjectClassifier()

        let swiftRoot = try makeTempDir()
        try "// swift-tools-version: 6.0".write(to: swiftRoot.appendingPathComponent("Package.swift"), atomically: true, encoding: .utf8)
        #expect(classifier.classify(rootURL: swiftRoot).kind == .swiftPackage)

        let nodeRoot = try makeTempDir()
        try "{}".write(to: nodeRoot.appendingPathComponent("package.json"), atomically: true, encoding: .utf8)
        #expect(classifier.classify(rootURL: nodeRoot).kind == .nodeWeb)

        let emptyRoot = try makeTempDir()
        let unknown = classifier.classify(rootURL: emptyRoot)
        #expect(unknown.kind == .unidentified)
        #expect(unknown.confidence == .unknown)
    }

    @Test("project classifier detects audio unit markers from Info.plist")
    func projectClassifierDetectsAudioUnit() throws {
        let classifier = ProjectClassifier()
        let root = try makeTempDir()
        let plist = """
        <?xml version="1.0" encoding="UTF-8"?>
        <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
        <plist version="1.0"><dict>
          <key>AudioComponents</key><array><dict><key>type</key><string>aufx</string></dict></array>
        </dict></plist>
        """
        try plist.write(to: root.appendingPathComponent("Info.plist"), atomically: true, encoding: .utf8)
        // type "aufx" should classify specifically as an effect.
        #expect(classifier.classify(rootURL: root).kind == .audioUnitEffect)
    }

    @Test("git engine reports a non-repository folder without crashing")
    func gitEngineHandlesNonRepository() throws {
        let root = try makeTempDir()
        let status = GitEngine().status(at: root)
        #expect(status.isRepository == false)
        #expect(status.isClean)
    }

    @Test("applicability scopes differ by project kind and exclude irrelevant areas")
    func applicabilityScopesByKind() {
        let engine = ApplicabilityEngine()

        let instrument = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .inferred)
        let instrumentItems = engine.items(for: instrument, mission: .unknown)
        func status(_ items: [ApplicabilityItem], _ area: String) -> ApplicabilityStatus? {
            items.first { $0.area == area }?.status
        }
        #expect(status(instrumentItems, "MIDI") == .required)
        #expect(status(instrumentItems, "AU Validation") == .required)
        #expect(status(instrumentItems, "Document Workflow") == .notApplicable)

        let app = ProjectIdentity(kind: .swiftUIApp, detail: "", confidence: .inferred)
        let appItems = engine.items(for: app, mission: .unknown)
        #expect(status(appItems, "User Interface") == .required)
        #expect(status(appItems, "AU Validation") == .notApplicable)
        #expect(status(appItems, "DSP") == .notApplicable)
    }

    @Test("reality engine keeps unknown out of green and recommends a next action")
    func realityEngineHonestScoring() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .inferred)
        let mission = MissionProfileEngine().profile(identity: identity, rootURL: URL(fileURLWithPath: "/tmp/none"), projectName: "Trinity-8")
        let applicability = ApplicabilityEngine().items(for: identity, mission: mission)
        let reality = RealityEngine().assess(
            identity: identity,
            mission: mission,
            applicability: applicability,
            git: GitStatus(isRepository: true, branch: "main"),
            summary: RepoSummary(totalFiles: 40, sourceFiles: 30),
            findings: [],
            evidence: [Evidence(title: "Approved repository scope", detail: "/tmp", classification: .observed, source: "test")]
        )

        // Nothing is verified, so the score must never reach 100 and the chain's
        // Verified stage must not be reached.
        #expect(reality.score < 100)
        #expect(reality.score > 0)
        #expect(reality.verified.isEmpty)
        #expect(reality.chain.first { $0.stage == .verified }?.state == .notReached)
        #expect(reality.chain.first { $0.stage == .implemented }?.state == .reached)
        #expect(!reality.unverified.isEmpty)
        #expect(!reality.nextAction.isEmpty)
        // An AUv3 instrument should surface AU validation or DSP/MIDI as a risk.
        #expect(reality.topRisks.contains { $0.lowercased().contains("au validation") || $0.lowercased().contains("dsp") || $0.lowercased().contains("midi") })
    }

    @Test("verification engine seeds in-scope areas and preserves user edits")
    func verificationEngineReconciles() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .inferred)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        let engine = VerificationEngine()

        let seeded = engine.reconcile(applicability: applicability, saved: [])
        #expect(seeded.allSatisfy { $0.state == .unknown })
        #expect(seeded.contains { $0.area == "AU Validation" })
        #expect(!seeded.contains { $0.area == "Document Workflow" }) // not in scope for an instrument

        let edit = VerificationRecord(area: "AU Validation", state: .verified, note: "auval passed")
        let merged = engine.reconcile(applicability: applicability, saved: [edit])
        #expect(merged.first { $0.area == "AU Validation" }?.state == .verified)
        #expect(merged.first { $0.area == "AU Validation" }?.note == "auval passed")
    }

    @Test("reality reflects verification: failures become risks, full coverage lifts the score")
    func realityReflectsVerification() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let mission = UserMissionProfile(statedMission: "Retro synth", category: .instrument).asMissionProfile()
        let applicability = ApplicabilityEngine().items(for: identity, mission: mission)
        let reality = RealityEngine()
        let git = GitStatus(isRepository: true, branch: "main")
        let summary = RepoSummary(totalFiles: 40, sourceFiles: 30)

        // A failing area must appear as a risk.
        let withFailure = reality.assess(
            identity: identity, mission: mission, applicability: applicability, git: git,
            summary: summary, findings: [], evidence: [],
            verification: [VerificationRecord(area: "Preset System", state: .failed, note: "presets lost on restart")]
        )
        #expect(withFailure.topRisks.contains { $0.lowercased().contains("preset") })
        #expect(withFailure.nextAction.lowercased().contains("preset"))

        // Verifying every in-scope area lifts the score well above an all-unknown baseline.
        let allAreas = VerificationEngine().reconcile(applicability: applicability, saved: [])
        let allVerified = allAreas.map { VerificationRecord(area: $0.area, state: .verified) }
        let high = reality.assess(
            identity: identity, mission: mission, applicability: applicability, git: git,
            summary: summary, findings: [], evidence: [], verification: allVerified
        )
        let baseline = reality.assess(
            identity: identity, mission: mission, applicability: applicability, git: git,
            summary: summary, findings: [], evidence: [], verification: allAreas
        )
        #expect(high.score > baseline.score)
        #expect(high.chain.first { $0.stage == .verified }?.state == .reached)
        #expect(baseline.chain.first { $0.stage == .verified }?.state == .notReached)
    }

    @Test("persisted project record round-trips mission and verification")
    func persistenceRoundTripsMissionAndVerification() throws {
        let defaults = try temporaryDefaults()
        let store = WorkspacePersistenceStore(defaults: defaults, key: "phase3-state")
        let record = PersistedProjectRecord(
            name: "Trinity-8",
            fallbackPath: "/tmp/trinity",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .missing,
            mission: UserMissionProfile(statedMission: "Retro AUv3 synth", category: .instrument, goals: ["Presets", "ARP"], currentPhase: "UI refinement", knownIssues: ["ARP incomplete"]),
            verification: [VerificationRecord(area: "AU Validation", state: .verified, note: "auval ok", verifiedBy: "Oliver")],
            knowledgeNotes: [
                KnowledgeNote(title: "Preset issue", body: "Logic restart loses presets.", kind: .knownIssue, author: "Oliver")
            ]
        )
        let state = WorkspacePersistenceState(projects: [record])
        try store.save(state)
        let loaded = try store.load()
        #expect(loaded.projects.first?.mission?.statedMission == "Retro AUv3 synth")
        #expect(loaded.projects.first?.mission?.goals == ["Presets", "ARP"])
        #expect(loaded.projects.first?.verification?.first?.state == .verified)
        #expect(loaded.projects.first?.verification?.first?.verifiedBy == "Oliver")
        #expect(loaded.projects.first?.knowledgeNotes?.first?.kind == .knownIssue)
    }

    @Test("verification engine timeline is newest first and includes verifier")
    func verificationTimelineOrdersNewestFirst() {
        let old = VerificationRecord(
            area: "Preset System",
            state: .failed,
            note: "Presets do not survive Logic restart.",
            verifiedBy: "Oliver",
            updatedAt: Date(timeIntervalSince1970: 1_000)
        )
        let new = VerificationRecord(
            area: "AU Validation",
            state: .verified,
            note: "auval passed",
            verifiedBy: "LocalForge",
            updatedAt: Date(timeIntervalSince1970: 2_000)
        )

        let timeline = VerificationEngine().timeline([old, new])

        #expect(timeline.map(\.area) == ["AU Validation", "Preset System"])
        #expect(timeline.first?.verifiedBy == "LocalForge")
        #expect(timeline.last?.note.contains("Logic") == true)
    }

    @Test("project setup draft creates mission and unknown verification records")
    func projectSetupDraftCreatesMissionAndVerificationRecords() {
        let areas = ["Audio Engine", "MIDI", "DSP", "Preset System"]
        let draft = ProjectSetupDraft(
            mission: "Retro-inspired synthesizer",
            category: .instrument,
            currentPhase: "UI Refinement",
            selectedVerificationAreas: areas,
            author: "Oliver"
        )

        let result = draft.materialize()

        #expect(result.mission.statedMission == "Retro-inspired synthesizer")
        #expect(result.mission.currentPhase == "UI Refinement")
        #expect(result.verification.map(\.area) == areas)
        #expect(result.verification.allSatisfy { $0.state == .unknown })
        #expect(result.verification.allSatisfy { $0.verifiedBy == "Oliver" })
    }

    // MARK: - Phase 5

    @Test("guardian surfaces a failed verification with full impact and suggested action")
    func guardianSurfacesFailedVerification() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let mission = UserMissionProfile(statedMission: "Retro synth", category: .instrument).asMissionProfile()
        let applicability = ApplicabilityEngine().items(for: identity, mission: mission)
        let failing = VerificationRecord(area: "Preset System", state: .failed, note: "presets lost on Logic restart", verifiedBy: "Oliver")
        let reality = RealityEngine().assess(
            identity: identity, mission: mission, applicability: applicability,
            git: GitStatus(isRepository: true, branch: "main"),
            summary: RepoSummary(totalFiles: 40, sourceFiles: 30),
            findings: [], evidence: [], verification: [failing]
        )
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.mission = mission
        snapshot.applicability = applicability
        snapshot.verification = [failing]
        snapshot.reality = reality

        let rec = GuardianEngine().recommendation(for: snapshot)

        #expect(rec.area == "Preset System")
        #expect(rec.status == "Failed")
        #expect(rec.riskLevel == .critical)
        #expect(rec.verifiedBy == "Oliver")
        #expect(!rec.impact.isEmpty)
        #expect(rec.suggestedAction.lowercased().contains("preset") || rec.suggestedAction.lowercased().contains("logic"))
    }

    @Test("promptforge generates all five artefacts, each non-empty and project-named")
    func promptForgeGeneratesAllArtefacts() {
        let identity = ProjectIdentity(kind: .swiftUIApp, detail: "", confidence: .inferred)
        let mission = UserMissionProfile(statedMission: "Local-first command centre", category: .application, goals: ["Mission", "Verification"], currentPhase: "Polish", knownIssues: []).asMissionProfile()
        let applicability = ApplicabilityEngine().items(for: identity, mission: mission)
        let verification = [
            VerificationRecord(area: "Build", state: .verified, note: "swift build OK"),
            VerificationRecord(area: "User Interface", state: .failed, note: "header text too small")
        ]
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.project = ProjectContext(name: "LocalForge", rootURL: URL(fileURLWithPath: "/tmp/lf"), permission: .approved(scopeDescription: "test"))
        snapshot.mission = mission
        snapshot.applicability = applicability
        snapshot.verification = verification
        snapshot.reality = RealityEngine().assess(
            identity: identity, mission: mission, applicability: applicability,
            git: GitStatus(isRepository: true, branch: "main"),
            summary: snapshot.summary, findings: [], evidence: [], verification: verification
        )

        let engine = PromptForgeEngine()
        for artefact in PromptForgeEngine.Artefact.allCases {
            let text = engine.generate(artefact, snapshot: snapshot)
            #expect(!text.isEmpty)
            #expect(text.contains("LocalForge"))
        }

        let sections = engine.handoffSections(snapshot: snapshot)
        let titles = sections.map(\.title)
        #expect(titles.contains("Project"))
        #expect(titles.contains("Mission"))
        #expect(titles.contains("Reality"))
        #expect(titles.contains("Verification"))
        #expect(titles.contains("Constraints"))
    }

    @Test("fix proposal centres on the failed area and includes diagnostics + rollback")
    func fixProposalCentresOnFailedArea() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.applicability = applicability
        snapshot.verification = [VerificationRecord(area: "AU Validation", state: .failed, note: "auval reports manufacturer code mismatch")]
        snapshot.reality = RealityEngine().assess(
            identity: identity, mission: snapshot.mission, applicability: applicability,
            git: snapshot.git, summary: snapshot.summary, findings: [], evidence: [],
            verification: snapshot.verification
        )

        let text = PromptForgeEngine().generate(.fixProposal, snapshot: snapshot)
        #expect(text.contains("AU Validation"))
        #expect(text.contains("auval"))
        #expect(text.lowercased().contains("rollback"))
        #expect(text.lowercased().contains("verification plan"))
    }

    // MARK: - Phase 6

    @Test("applicability tags Critical priority for AUv3 release blockers")
    func applicabilityTagsCriticalPriority() {
        let items = ApplicabilityEngine().items(
            for: ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed),
            mission: .unknown
        )
        func priority(_ area: String) -> VerificationPriority? { items.first { $0.area == area }?.priority }
        #expect(priority("AU Validation") == .critical)
        #expect(priority("DSP") == .critical)
        #expect(priority("Build") == .critical)
        #expect(priority("User Interface") == .medium)
        #expect(priority("Document Workflow") == .low)
    }

    @Test("reality score penalises critical failures far more than low-priority ones")
    func realityWeightsByPriority() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        let engine = RealityEngine()
        let summary = RepoSummary(totalFiles: 40, sourceFiles: 30)
        let git = GitStatus(isRepository: true, branch: "main")

        let critFail = engine.assess(
            identity: identity, mission: .unknown, applicability: applicability,
            git: git, summary: summary, findings: [], evidence: [],
            verification: [VerificationRecord(area: "AU Validation", state: .failed)]
        )
        let docFail = engine.assess(
            identity: identity, mission: .unknown, applicability: applicability,
            git: git, summary: summary, findings: [], evidence: [],
            verification: [VerificationRecord(area: "Document Workflow", state: .failed)]
        )
        // A critical failure must drop the score noticeably more than a low-priority one.
        #expect(critFail.score < docFail.score)
    }

    @Test("verification age decays trust from fresh to expired")
    func verificationAgeDecaysTrust() {
        let fresh = VerificationAge.from(Date().addingTimeInterval(-2 * 86_400))
        let ageing = VerificationAge.from(Date().addingTimeInterval(-60 * 86_400))
        let stale = VerificationAge.from(Date().addingTimeInterval(-120 * 86_400))
        let expired = VerificationAge.from(Date().addingTimeInterval(-365 * 86_400))
        #expect(fresh == .fresh)
        #expect(ageing == .ageing)
        #expect(stale == .stale)
        #expect(expired == .expired)
        #expect(fresh.trust > ageing.trust)
        #expect(ageing.trust > stale.trust)
        #expect(stale.trust > expired.trust)
        #expect(expired.trust == 0)
    }

    @Test("stale verified records earn less reality credit than fresh ones")
    func realityDecaysWithAge() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        let engine = RealityEngine()
        let summary = RepoSummary(totalFiles: 40, sourceFiles: 30)
        let git = GitStatus(isRepository: true, branch: "main")

        let freshAll = applicability.filter { $0.status.inScope }.map {
            VerificationRecord(area: $0.area, state: .verified, updatedAt: Date())
        }
        let oldAll = applicability.filter { $0.status.inScope }.map {
            VerificationRecord(area: $0.area, state: .verified, updatedAt: Date().addingTimeInterval(-200 * 86_400))
        }

        let freshReality = engine.assess(
            identity: identity, mission: .unknown, applicability: applicability,
            git: git, summary: summary, findings: [], evidence: [], verification: freshAll
        )
        let staleReality = engine.assess(
            identity: identity, mission: .unknown, applicability: applicability,
            git: git, summary: summary, findings: [], evidence: [], verification: oldAll
        )
        #expect(freshReality.score > staleReality.score)
    }

    @Test("guardian surfaces stale verification when nothing is failing")
    func guardianFlagsStaleVerification() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        let stale = VerificationRecord(area: "AU Validation", state: .verified, updatedAt: Date().addingTimeInterval(-200 * 86_400))
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.applicability = applicability
        snapshot.verification = [stale]
        snapshot.reality = RealityEngine().assess(
            identity: identity, mission: snapshot.mission, applicability: applicability,
            git: snapshot.git, summary: snapshot.summary, findings: [], evidence: [],
            verification: [stale]
        )

        let rec = GuardianEngine().recommendation(for: snapshot)
        #expect(rec.area == "AU Validation")
        #expect(rec.status.lowercased().contains("stale") || rec.status.lowercased().contains("expired"))
        #expect(rec.lastObservedAt != nil)
    }

    @Test("journal engine appends entries newest-first and caps the log")
    func journalEngineAppendsAndCaps() {
        let engine = JournalEngine()
        var entries: [JournalEntry] = []
        for i in 0..<10 {
            let entry = JournalEntry(kind: .note, summary: "Entry \(i)")
            entries = engine.appending(entry, to: entries)
        }
        #expect(entries.count == 10)
        #expect(entries.first?.summary == "Entry 9")

        // Cap is 500.
        var big = entries
        for i in 0..<600 {
            big = engine.appending(JournalEntry(kind: .note, summary: "Bulk \(i)"), to: big)
        }
        #expect(big.count == 500)
    }

    // MARK: - Phase 6.5

    @Test("release readiness is blocked when a critical area is failing")
    func releaseReadinessBlocksOnCriticalFailure() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.applicability = applicability
        snapshot.verification = [VerificationRecord(area: "AU Validation", state: .failed)]
        let board = ReleaseReadinessEngine().board(for: snapshot)
        #expect(board.status == .blocked)
        #expect(board.blockers.contains("AU Validation"))
        #expect(board.rows.contains { $0.area == "AU Validation" && $0.state == .failed })
    }

    @Test("verification dependencies surface blockers in the release board")
    func dependenciesSurfaceBlockers() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.applicability = applicability
        snapshot.verification = [
            VerificationRecord(area: "Preset System", state: .failed),
            VerificationRecord(area: "AU Validation", state: .unknown, dependsOn: ["Preset System"])
        ]
        let board = ReleaseReadinessEngine().board(for: snapshot)
        let auRow = board.rows.first { $0.area == "AU Validation" }
        #expect(auRow?.blockedBy.contains { $0.contains("Preset System") } == true)
    }

    @Test("workspace insights highlights highest-risk and least-verified projects")
    func workspaceInsightsRankProjects() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)

        func makeSnapshot(name: String, state: VerificationState) -> RepoSnapshot {
            var s = RepoSnapshot.fixture(identity: identity)
            s.project = ProjectContext(name: name, rootURL: URL(fileURLWithPath: "/tmp/\(name)"), permission: .approved(scopeDescription: "test"))
            s.applicability = applicability
            s.verification = applicability.filter { $0.status.inScope }.map { VerificationRecord(area: $0.area, state: state) }
            s.reality = RealityEngine().assess(
                identity: identity, mission: s.mission, applicability: applicability,
                git: s.git, summary: s.summary, findings: [], evidence: [], verification: s.verification
            )
            return s
        }

        let healthy = makeSnapshot(name: "ApplyPro", state: .verified)
        let stuck = makeSnapshot(name: "Trinity-8", state: .failed)
        let untouched = makeSnapshot(name: "Visual-UI", state: .unknown)

        let insights = ReleaseReadinessEngine().insights(for: [healthy, stuck, untouched])
        #expect(insights.totalProjects == 3)
        #expect(insights.blockedCount == 1)
        #expect(insights.highestRisk?.name == "Trinity-8")
        #expect(insights.mostComplete?.name == "ApplyPro")
        #expect(insights.leastVerified?.verified == 0)
    }

    @Test("guardian enrichment pulls journal activity and linked notes")
    func guardianEnrichmentReadsJournalAndNotes() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.applicability = applicability
        snapshot.verification = [VerificationRecord(area: "Preset System", state: .failed, note: "presets lost")]
        snapshot.reality = RealityEngine().assess(
            identity: identity, mission: snapshot.mission, applicability: applicability,
            git: snapshot.git, summary: snapshot.summary, findings: [], evidence: [],
            verification: snapshot.verification
        )

        let journal = [
            JournalEntry(kind: .verification, summary: "Preset System → Failed"),
            JournalEntry(kind: .note, summary: "Investigated Preset System AUState handling"),
            JournalEntry(kind: .note, summary: "Unrelated entry")
        ]
        let knowledge = [
            KnowledgeNote(title: "Preset System investigation", body: "Notes on AUState", kind: .knownIssue)
        ]

        let rec = GuardianEngine().recommendation(for: snapshot, knowledge: knowledge, journal: journal)
        #expect(rec.area == "Preset System")
        #expect(rec.linkedJournalCount >= 2)
        #expect(rec.linkedNotesCount == 1)
        #expect(rec.recentActivity.contains { $0.contains("Preset System") })
    }

    // MARK: - Phase 7

    @Test("evidence record persists and survives backward-compatible decode")
    func evidenceRecordBackwardCompat() throws {
        let original = EvidenceRecord(area: "Preset System", kind: .reproduction, summary: "Presets lost on restart", body: "Reproduced twice", classification: .observed, author: "Oliver")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(EvidenceRecord.self, from: data)
        #expect(decoded.area == "Preset System")
        #expect(decoded.classification == .observed)
        #expect(decoded.kind == .reproduction)
    }

    @Test("evidence keeps trust high on a stale verified record")
    func evidenceProtectsTrustOnStaleRecord() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        let engine = RealityEngine()
        let summary = RepoSummary(totalFiles: 40, sourceFiles: 30)
        let git = GitStatus(isRepository: true, branch: "main")
        let staleAll = applicability.filter { $0.status.inScope }.map {
            VerificationRecord(area: $0.area, state: .verified, updatedAt: Date().addingTimeInterval(-200 * 86_400))
        }
        let backedEvidence = staleAll.map { EvidenceRecord(area: $0.area, summary: "Observed working", classification: .observed) }
        let unbacked = engine.assess(identity: identity, mission: .unknown, applicability: applicability,
            git: git, summary: summary, findings: [], evidence: [], verification: staleAll)
        let backed = engine.assess(identity: identity, mission: .unknown, applicability: applicability,
            git: git, summary: summary, findings: [], evidence: [], verification: staleAll, evidenceRecords: backedEvidence)
        #expect(backed.score > unbacked.score)
    }

    @Test("open critical risks pull reality score down and surface as risks")
    func openRisksPenaliseReality() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        let engine = RealityEngine()
        let summary = RepoSummary(totalFiles: 40, sourceFiles: 30)
        let git = GitStatus(isRepository: true, branch: "main")
        let verified = applicability.filter { $0.status.inScope }.map { VerificationRecord(area: $0.area, state: .verified) }
        let baseline = engine.assess(identity: identity, mission: .unknown, applicability: applicability,
            git: git, summary: summary, findings: [], evidence: [], verification: verified)
        let withRisk = engine.assess(identity: identity, mission: .unknown, applicability: applicability,
            git: git, summary: summary, findings: [], evidence: [], verification: verified,
            riskRecords: [RiskRecord(title: "Preset corruption", impact: .critical, status: .open)])
        #expect(withRisk.score < baseline.score)
        #expect(withRisk.topRisks.contains { $0.contains("Preset corruption") })
    }

    @Test("active assumptions appear in reality assumption bucket")
    func activeAssumptionsSurface() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        let reality = RealityEngine().assess(
            identity: identity, mission: .unknown, applicability: applicability,
            git: .unknown, summary: RepoSummary(totalFiles: 1, sourceFiles: 1), findings: [], evidence: [],
            assumptionRecords: [
                AssumptionRecord(assumption: "Logic restores AUState correctly", status: .active),
                AssumptionRecord(assumption: "Sample rate is always 44.1", status: .active),
                AssumptionRecord(assumption: "User runs macOS 14+", status: .active)
            ]
        )
        #expect(reality.assumptions.contains { $0.contains("Logic restores AUState") })
        #expect(reality.unknowns.contains { $0.lowercased().contains("active assumption") })
    }

    @Test("mission template catalogue offers an AUv3 synth + pack")
    func missionTemplateCatalogueExposesAUv3() {
        let catalogue = MissionTemplateCatalogue()
        let templates = catalogue.templates(for: .audioUnitInstrument)
        #expect(templates.contains { $0.name == "AUv3 Synth" })
        let packs = catalogue.packs(for: .audioUnitInstrument)
        #expect(packs.contains { $0.name == "AUv3 Instrument Pack" })
        let auvPack = packs.first { $0.name == "AUv3 Instrument Pack" }
        #expect(auvPack?.areas.contains { $0.area == "AU Validation" } == true)
        #expect(auvPack?.areas.first { $0.area == "AU Validation" }?.dependsOn.contains("Preset System") == true)
    }

    @Test("handoff comprehensive includes risk and decision sections when present")
    func handoffIncludesRegisters() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.project = ProjectContext(name: "Trinity-8", rootURL: URL(fileURLWithPath: "/tmp/t8"), permission: .approved(scopeDescription: "test"))
        snapshot.applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        snapshot.verification = [VerificationRecord(area: "AU Validation", state: .failed)]
        snapshot.reality = RealityEngine().assess(identity: identity, mission: snapshot.mission, applicability: snapshot.applicability,
            git: snapshot.git, summary: snapshot.summary, findings: [], evidence: [], verification: snapshot.verification)

        let text = PromptForgeEngine().generate(
            .comprehensiveHandoff,
            snapshot: snapshot,
            risks: [RiskRecord(title: "Preset corruption", impact: .high, status: .open)],
            decisions: [DecisionRecord(title: "Use AUState", reason: "Host compatibility")],
            architecture: [ArchitectureItem(name: "Preset System", subsystemType: .presetSystem)],
            assumptions: [AssumptionRecord(assumption: "Logic restores AUState")]
        )
        #expect(text.contains("Risk Register"))
        #expect(text.contains("Preset corruption"))
        #expect(text.contains("Decision Register"))
        #expect(text.contains("Use AUState"))
        #expect(text.contains("Architecture"))
        #expect(text.contains("Assumption Register"))
    }

    // MARK: - Phase 7.5

    @Test("evidence record cross-link IDs round-trip and default to empty for old records")
    func evidenceCrossLinkBackwardCompat() throws {
        // Old record encoded without the new keys should still decode.
        let oldJSON = """
        {"area":"Preset System","kind":"Observation","summary":"Old","classification":"Observed","createdAt":760000000}
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(EvidenceRecord.self, from: oldJSON)
        #expect(decoded.linkedRiskIDs.isEmpty)
        #expect(decoded.linkedVerificationIDs.isEmpty)

        // New record with explicit links must round-trip.
        let v = UUID(); let r = UUID()
        let fresh = EvidenceRecord(area: "Preset System", summary: "New", linkedVerificationIDs: [v], linkedRiskIDs: [r])
        let data = try JSONEncoder().encode(fresh)
        let again = try JSONDecoder().decode(EvidenceRecord.self, from: data)
        #expect(again.linkedVerificationIDs == [v])
        #expect(again.linkedRiskIDs == [r])
    }

    @Test("reality breakdown lists failures and risks as negative contributions")
    func realityBreakdownAttributes() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.applicability = applicability
        snapshot.verification = [
            VerificationRecord(area: "DSP", state: .verified),
            VerificationRecord(area: "Preset System", state: .failed)
        ]
        snapshot.reality = RealityEngine().assess(
            identity: identity, mission: snapshot.mission, applicability: applicability,
            git: snapshot.git, summary: snapshot.summary, findings: [], evidence: [],
            verification: snapshot.verification
        )
        let breakdown = TruthEngine().breakdown(
            snapshot: snapshot,
            evidence: [EvidenceRecord(area: "DSP", summary: "Verified clean render")],
            risks: [RiskRecord(title: "Preset corruption", impact: .critical, status: .open)],
            assumptions: []
        )
        #expect(breakdown.positives.contains { $0.label.contains("verified") })
        #expect(breakdown.positives.contains { $0.label.contains("evidence") })
        #expect(breakdown.negatives.contains { $0.label.contains("failed") })
        #expect(breakdown.negatives.contains { $0.label.contains("critical") })
    }

    @Test("confidence is separate from reality: failing-but-evidenced can be high confidence")
    func confidenceIsSeparateFromReality() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.applicability = applicability
        snapshot.verification = [VerificationRecord(area: "Preset System", state: .failed)]
        // Plenty of strong evidence backing up the failure claim.
        let evidence = (0..<6).map { i in
            EvidenceRecord(area: "Preset System", summary: "Reproduction \(i)", classification: .observed)
        }
        let high = TruthEngine().confidence(snapshot: snapshot, evidence: evidence, assumptions: [])
        let bare = TruthEngine().confidence(snapshot: snapshot, evidence: [], assumptions: [])
        #expect(high.score > bare.score)
        #expect(high.label == "High" || high.label == "Moderate")
    }

    @Test("register health drops when a register has nothing in it")
    func registerHealthReflectsCoverage() {
        let identity = ProjectIdentity(kind: .audioUnitInstrument, detail: "", confidence: .observed)
        let applicability = ApplicabilityEngine().items(for: identity, mission: .unknown)
        var snapshot = RepoSnapshot.fixture(identity: identity)
        snapshot.applicability = applicability
        snapshot.verification = applicability.filter { $0.status.inScope }.map { VerificationRecord(area: $0.area, state: .unknown) }
        let empty = TruthEngine().registerHealth(
            snapshot: snapshot, evidence: [], decisions: [], risks: [], architecture: [], assumptions: []
        )
        #expect(empty.evidenceCoverage == 0)
        #expect(empty.decisionCoverage == 0)
        let full = TruthEngine().registerHealth(
            snapshot: snapshot,
            evidence: applicability.filter { $0.status.inScope }.map { EvidenceRecord(area: $0.area, summary: "ok") },
            decisions: [DecisionRecord(title: "a"), DecisionRecord(title: "b"), DecisionRecord(title: "c")],
            risks: [RiskRecord(title: "r1"), RiskRecord(title: "r2"), RiskRecord(title: "r3")],
            architecture: applicability.filter { $0.status.inScope }.map { ArchitectureItem(name: $0.area) },
            assumptions: [AssumptionRecord(assumption: "a"), AssumptionRecord(assumption: "b")]
        )
        #expect(full.evidenceCoverage >= 1.0 - 0.0001)
        #expect(full.decisionCoverage >= 1.0 - 0.0001)
        #expect(full.architectureCoverage >= 1.0 - 0.0001)
    }

    @Test("related records resolve in both directions from a single stored link")
    func relatedRecordsBidirectional() {
        // Link stored ONLY on the evidence side: evidence → risk.
        let risk = RiskRecord(title: "Preset corruption")
        let decision = DecisionRecord(title: "Use AUState")
        let evidence = EvidenceRecord(
            area: "Preset System",
            summary: "Presets disappear after restart",
            linkedRiskIDs: [risk.id],
            linkedDecisionIDs: [decision.id]
        )
        let engine = TruthEngine()

        // Forward: asking from the evidence finds the risk and decision.
        let fromEvidence = engine.related(
            to: .evidence(evidence.id),
            evidence: [evidence], risks: [risk], decisions: [decision],
            architecture: [], assumptions: [], verification: []
        )
        #expect(fromEvidence.risks.map(\.id) == [risk.id])
        #expect(fromEvidence.decisions.map(\.id) == [decision.id])

        // Reverse: asking from the risk finds the evidence even though the
        // risk itself stores no link.
        let fromRisk = engine.related(
            to: .risk(risk.id),
            evidence: [evidence], risks: [risk], decisions: [decision],
            architecture: [], assumptions: [], verification: []
        )
        #expect(fromRisk.evidence.map(\.id) == [evidence.id])
        #expect(fromRisk.decisions.isEmpty)
    }

    @Test("related records bridge verification by UUID link and by area name")
    func relatedRecordsVerificationBridges() {
        let verification = VerificationRecord(area: "Preset System", state: .failed)
        // Evidence in the same area (no explicit link) + an explicitly linked risk.
        let evidence = EvidenceRecord(area: "Preset System", summary: "Reproduced twice")
        let risk = RiskRecord(title: "Preset corruption", linkedVerificationIDs: [verification.id])
        let architecture = ArchitectureItem(name: "Preset System", linkedVerificationAreas: ["Preset System"])
        let assumption = AssumptionRecord(assumption: "Logic restores AUState", linkedVerificationArea: "Preset System")

        let related = TruthEngine().related(
            to: .verification(verification.id),
            evidence: [evidence], risks: [risk], decisions: [],
            architecture: [architecture], assumptions: [assumption],
            verification: [verification]
        )
        #expect(related.evidence.map(\.id) == [evidence.id])
        #expect(related.risks.map(\.id) == [risk.id])
        #expect(related.architecture.map(\.id) == [architecture.id])
        #expect(related.assumptions.map(\.id) == [assumption.id])
    }

    // MARK: - Phase 8

    /// A workspace state exercising every persisted collection, plus the
    /// nil-vs-empty-array distinction (project B has [] verification, nil journal).
    private func fatState() -> WorkspacePersistenceState {
        let projectA = PersistedProjectRecord(
            name: "Trinity-8",
            fallbackPath: "/tmp/trinity",
            bookmarkData: Data([0x01, 0x02, 0x03]),
            scanPolicy: .balanced,
            bookmarkStatus: .missing,
            mission: UserMissionProfile(statedMission: "Retro AUv3 synth", category: .instrument, goals: ["Presets"], currentPhase: "UI"),
            verification: [VerificationRecord(area: "Preset System", state: .failed, note: "lost on restart", verifiedBy: "Oliver", dependsOn: ["Parameter Tree"])],
            knowledgeNotes: [KnowledgeNote(title: "Preset issue", body: "Logic restart loses presets.", kind: .knownIssue)],
            journal: [JournalEntry(kind: .verification, summary: "Preset System → Failed", detail: "Reproduced twice")],
            evidence: [EvidenceRecord(area: "Preset System", summary: "Presets disappear after restart", classification: .observed)],
            decisions: [DecisionRecord(title: "Use AUState", decision: "AUState for persistence", reason: "Host compatibility")],
            architecture: [ArchitectureItem(name: "Preset System", subsystemType: .presetSystem)],
            risks: [RiskRecord(title: "Preset corruption", likelihood: .medium, impact: .critical, status: .open)],
            assumptions: [AssumptionRecord(assumption: "Logic restores AUState correctly")],
            environments: [
                EnvironmentSnapshot(
                    macOSVersion: "15.5",
                    xcodeVersion: "16.4",
                    swiftVersion: "6.1",
                    sdkVersion: "15.5",
                    auValVersion: "1.10",
                    notes: "Release machine"
                )
            ],
            testRecords: [
                TestRecord(
                    name: "Logic preset restore",
                    kind: .hostTest,
                    outcome: .blocked,
                    linkedVerificationArea: "Preset System",
                    notes: "Needs retest in Logic",
                    author: "Oliver"
                )
            ]
        )
        let projectB = PersistedProjectRecord(
            name: "ApplyPro",
            fallbackPath: "/tmp/applypro",
            bookmarkData: nil,
            scanPolicy: .balanced,
            bookmarkStatus: .missing,
            verification: [],
            journal: nil
        )
        return WorkspacePersistenceState(
            projects: [projectA, projectB],
            scanMode: .balanced,
            theme: ThemePreferences(appearance: .dark, accentName: "Blue", brightnessAdjustment: 2),
            lastActiveProjectID: projectA.id
        )
    }

    @Test("sqlite persistence round-trips the full workspace state value-equal")
    func sqliteRoundTrip() throws {
        let file = try makeTempDir().appendingPathComponent("ws.sqlite")
        let state = fatState()
        let store = try SQLitePersistenceStore(fileURL: file, legacyDefaults: nil)
        try store.save(state)
        #expect(try store.load() == state)

        // A brand-new instance reading the same file sees the identical state.
        let reopened = try SQLitePersistenceStore(fileURL: file, legacyDefaults: nil)
        #expect(try reopened.load() == state)
        // nil-vs-[] preserved exactly.
        let loadedB = try reopened.load().projects.last
        #expect(loadedB?.verification == [])
        #expect(loadedB?.journal == nil)
    }

    @Test("sqlite imports the legacy UserDefaults blob on first load and keeps it")
    func sqliteMigratesLegacyBlob() throws {
        let defaults = try temporaryDefaults()
        let key = "LocalForge.WorkspaceState"
        let state = fatState()
        try WorkspacePersistenceStore(defaults: defaults, key: key).save(state)

        let file = try makeTempDir().appendingPathComponent("ws.sqlite")
        let sqlite = try SQLitePersistenceStore(fileURL: file, legacyDefaults: defaults, legacyKey: key)
        let migrated = try sqlite.load()
        #expect(migrated == state)
        #expect(sqlite.lastLoadNote?.contains("migrated") == true)
        // The old blob is never deleted in the migrating release.
        #expect(defaults.data(forKey: key) != nil)
        // Second load reads from SQLite (no migration note).
        #expect(try sqlite.load() == state)
        #expect(sqlite.lastLoadNote == nil)
    }

    @Test("sqlite recovers a corrupt database from the legacy backup, never silently empty")
    func sqliteCorruptionRecovery() throws {
        let defaults = try temporaryDefaults()
        let key = "LocalForge.WorkspaceState"
        let state = fatState()
        try WorkspacePersistenceStore(defaults: defaults, key: key).save(state)

        let dir = try makeTempDir()
        let file = dir.appendingPathComponent("ws.sqlite")
        try Data("definitely not a sqlite database".utf8).write(to: file)

        let sqlite = try SQLitePersistenceStore(fileURL: file, legacyDefaults: defaults, legacyKey: key)
        let recovered = try sqlite.load()
        #expect(recovered == state)
        #expect(sqlite.lastLoadNote?.contains("unreadable") == true)
        // The damaged file was kept beside the fresh one.
        let kept = try FileManager.default.contentsOfDirectory(atPath: dir.path)
            .contains { $0.contains(".corrupt-") }
        #expect(kept)
    }

    @Test("universal search finds records across types with snippets and flags")
    func searchAcrossRecordTypes() {
        let state = fatState()
        let engine = SearchEngine()

        let decisionHits = engine.search("AUState", in: state.projects)
        #expect(decisionHits.contains { $0.kind == .decision && $0.projectName == "Trinity-8" })
        // "AUState" also appears in the assumption text.
        #expect(decisionHits.contains { $0.kind == .assumption })

        let presetHits = engine.search("Preset System", in: state.projects)
        let kinds = Set(presetHits.map(\.kind))
        #expect(kinds.isSuperset(of: [.verification, .evidence, .architecture]))

        // Open critical risk carries the release-blocking flag for filtering.
        let riskHits = engine.search("corruption", in: state.projects)
        #expect(riskHits.first { $0.kind == .risk }?.isReleaseBlocking == true)

        // Single character: too short, no scan.
        #expect(engine.search("p", in: state.projects).isEmpty)
    }

    @Test("workspace truth counts critical open risks and journal entries for the portfolio")
    func workspaceTruthPortfolioCounts() {
        let truth = TruthEngine().workspaceTruth(records: fatState().projects, snapshots: [])
        #expect(truth.criticalOpenRisks == 1)
        #expect(truth.journalEntries == 1)
        #expect(truth.openRisks == 1)
        #expect(truth.totalProjects == 2)
    }

    @Test("verification packs carry kind-typical suggested risks that materialise open")
    func packsCarrySuggestedRisks() {
        let catalogue = MissionTemplateCatalogue()
        let pack = catalogue.pack(named: "AUv3 Instrument Pack")
        #expect(pack?.suggestedRisks.isEmpty == false)
        #expect(pack?.suggestedRisks.contains { $0.title == "Preset corruption" } == true)
        let record = pack?.suggestedRisks.first?.materialise()
        #expect(record?.status == .open)
        // The expanded pack carries the state-restore chain the advisor specified.
        #expect(pack?.areas.contains { $0.area == "State Restore" } == true)
        #expect(pack?.areas.first { $0.area == "AU Validation" }?.dependsOn.contains("State Restore") == true)
        // New template families exist for app projects.
        let appPacks = catalogue.packs(for: .swiftUIApp).map(\.name)
        #expect(appPacks.contains("Developer Tool Pack"))
        #expect(appPacks.contains("Automation Tool Pack"))
    }

    private func makeTempDir() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("LocalForgeTest-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func temporaryDefaults() throws -> UserDefaults {
        let suiteName = "LocalForgeCoreTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}

private struct FakeBookmarkProvider: SecurityScopedBookmarkProviding {
    enum Result {
        case active
        case stale
        case failure
    }

    let result: Result

    func makeBookmarkData(for url: URL) throws -> Data {
        Data(url.path.utf8)
    }

    func resolveBookmarkData(_ data: Data) throws -> SecurityScopedBookmarkResolution {
        switch result {
        case .active:
            return SecurityScopedBookmarkResolution(
                url: URL(fileURLWithPath: "/tmp/resolved"),
                isStale: false,
                didStartSecurityScope: true
            )
        case .stale:
            return SecurityScopedBookmarkResolution(
                url: URL(fileURLWithPath: "/tmp/stale"),
                isStale: true,
                didStartSecurityScope: false
            )
        case .failure:
            throw BookmarkAccessError.resolutionFailed("test resolve failure")
        }
    }

    func stopAccessing(_ url: URL) {}
}
