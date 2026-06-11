import AppKit
import Foundation
import LocalForgeCore

@MainActor
final class WorkspaceStore: ObservableObject {
    @Published private(set) var projects: [ProjectContext] = []
    @Published private(set) var snapshots: [UUID: RepoSnapshot] = [:]
    @Published var selectedProjectID: UUID?
    @Published var selectedModule: WorkspaceModule = .workspace
    @Published var scanMode: ScanMode = .balanced {
        didSet {
            guard !isRestoringState else { return }
            updateSelectedProjectScanPolicy()
            persistWorkspaceState()
        }
    }
    @Published var themePreferences: ThemePreferences = .default {
        didSet {
            guard !isRestoringState else { return }
            persistWorkspaceState()
        }
    }
    @Published var isScanning = false
    @Published var statusMessage = "Open a repository to begin local-first analysis."
    @Published var setupProjectID: UUID?
    // Phase 8.5: command palette
    @Published var showCommandPalette = false
    // Phase 8.5: pinning + favourites
    @Published var favoritedProjectIDs: Set<UUID> = []
    @Published var pinnedItems: [PinnedItem] = []
    // Phase 8.5: saved views
    @Published var savedViews: [SavedView] = []

    private let scanner = ScannerEngine()
    private let guardian = GuardianEngine()
    private let reportEngine = ReportEngine()
    private let verificationEngine = VerificationEngine()
    private let realityEngine = RealityEngine()
    private let journalEngine = JournalEngine()
    private let releaseEngine = ReleaseReadinessEngine()
    private let truthEngine = TruthEngine()
    private let whyEngine = WhyEngine()
    private let healthEngine = WorkspaceHealthEngine()
    private let doctorEngine = WorkspaceDoctorEngine()
    private let commandPaletteEngine = CommandPaletteEngine()
    let backupEngine = BackupEngine()
    let utilityCentre = UtilityCentreEngine()
    private let codeBloatScanner = CodeBloatScannerEngine()
    private let persistenceStore: any WorkspacePersisting
    private let bookmarkProvider: any SecurityScopedBookmarkProviding
    private var persistedRecords: [UUID: PersistedProjectRecord] = [:]
    private var activeSecurityScopeURLs: [UUID: URL] = [:]
    private var isRestoringState = false
    /// Set when SQLite could not be initialised and we fell back to UserDefaults.
    private(set) var persistenceFallbackNote: String?

    init(
        persistenceStore: (any WorkspacePersisting)? = nil,
        bookmarkProvider: any SecurityScopedBookmarkProviding = SecurityScopedBookmarkProvider()
    ) {
        if let persistenceStore {
            self.persistenceStore = persistenceStore
        } else {
            // Phase 8 default: SQLite (with automatic one-time migration from the
            // legacy UserDefaults blob). If SQLite cannot even be created, fall
            // back to UserDefaults — visibly, never silently.
            do {
                self.persistenceStore = try SQLitePersistenceStore()
            } catch {
                self.persistenceStore = WorkspacePersistenceStore()
                self.persistenceFallbackNote = "SQLite storage unavailable (\(error.localizedDescription)); using UserDefaults fallback."
            }
        }
        self.bookmarkProvider = bookmarkProvider
        loadPersistedWorkspace()
    }

    var selectedProject: ProjectContext? {
        guard let selectedProjectID else { return nil }
        return projects.first { $0.id == selectedProjectID }
    }

    var selectedRecord: PersistedProjectRecord? {
        guard let selectedProjectID else { return nil }
        return persistedRecords[selectedProjectID]
    }

    var selectedSnapshot: RepoSnapshot? {
        guard let selectedProjectID else { return nil }
        return snapshots[selectedProjectID]
    }

    var guardianRecommendation: GuardianRecommendation {
        if let selectedSnapshot, let id = selectedProjectID {
            return guardian.recommendation(
                for: selectedSnapshot,
                knowledge: knowledgeNotes(for: id),
                journal: journal(for: id),
                evidence: evidence(for: id)
            )
        }
        return GuardianRecommendation(
            mode: "Workspace Overview Mode",
            riskLevel: .unknown,
            topIssue: "No active project",
            evidence: "No repository has been selected.",
            confidence: .unknown,
            nextAction: "Open Repository to grant explicit folder access."
        )
    }

    /// Phase 6.5: Release Readiness board for the active project.
    var releaseBoard: ReleaseReadinessBoard? {
        guard let snapshot = selectedSnapshot else { return nil }
        return releaseEngine.board(for: snapshot)
    }

    /// Phase 6.5: Cross-project insights for the workspace overview.
    var workspaceInsights: WorkspaceInsights {
        let ordered = projects.compactMap { snapshots[$0.id] }
        return releaseEngine.insights(for: ordered)
    }

    // MARK: - Phase 7.5 Truth System surface

    var selectedRealityBreakdown: RealityBreakdown {
        guard let snapshot = selectedSnapshot, let id = selectedProjectID else { return .empty }
        return truthEngine.breakdown(
            snapshot: snapshot,
            evidence: evidence(for: id),
            risks: risks(for: id),
            assumptions: assumptions(for: id)
        )
    }

    var selectedConfidence: ConfidenceAssessment {
        guard let snapshot = selectedSnapshot, let id = selectedProjectID else { return .unknown }
        return truthEngine.confidence(
            snapshot: snapshot,
            evidence: evidence(for: id),
            assumptions: assumptions(for: id)
        )
    }

    var selectedRegisterHealth: RegisterHealth {
        guard let snapshot = selectedSnapshot, let id = selectedProjectID else { return .empty }
        return truthEngine.registerHealth(
            snapshot: snapshot,
            evidence: evidence(for: id),
            decisions: decisions(for: id),
            risks: risks(for: id),
            architecture: architecture(for: id),
            assumptions: assumptions(for: id)
        )
    }

    var workspaceTruth: WorkspaceTruthSummary {
        let records = projects.compactMap { persistedRecords[$0.id] }
        let snaps = projects.compactMap { snapshots[$0.id] }
        return truthEngine.workspaceTruth(records: records, snapshots: snaps)
    }

    var workspaceCounts: WorkspaceCounts {
        let allSnapshots = Array(snapshots.values)
        let critical = allSnapshots.filter { snapshot in
            snapshot.findings.contains { $0.severity == .critical }
        }.count
        let warning = allSnapshots.filter { snapshot in
            snapshot.findings.contains { $0.severity == .warning }
        }.count
        let healthy = max(0, allSnapshots.count - critical - warning)

        return WorkspaceCounts(
            total: projects.count,
            healthy: healthy,
            warning: warning,
            critical: critical,
            activeScans: isScanning ? 1 : 0
        )
    }

    func openRepositoryPanel() {
        let panel = NSOpenPanel()
        panel.title = "Open Repository"
        panel.prompt = "Open"
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }
        addProject(url: url, scopeDescription: "User selected folder")
    }

    func addProject(url: URL, scopeDescription: String) {
        let policy = ScanPolicy.defaults(for: scanMode)
        let record: PersistedProjectRecord
        let project: ProjectContext

        do {
            record = try PersistedProjectRecord.approvedProject(
                url: url,
                scanPolicy: policy,
                bookmarkProvider: bookmarkProvider
            )
            project = ProjectContext(
                id: record.id,
                name: record.name,
                rootURL: url,
                permission: .approved(scopeDescription: scopeDescription),
                scanPolicy: policy,
                bookmarkStatus: .saved
            )
            statusMessage = "Saved read-only access for \(project.name)."
        } catch {
            let fallbackRecord = PersistedProjectRecord(
                name: url.lastPathComponent.isEmpty ? "Untitled Project" : url.lastPathComponent,
                fallbackPath: url.path,
                bookmarkData: nil,
                scanPolicy: policy,
                bookmarkStatus: .failed(reason: error.localizedDescription)
            )
            record = fallbackRecord
            project = ProjectContext(
                id: fallbackRecord.id,
                name: fallbackRecord.name,
                rootURL: url,
                permission: .approved(scopeDescription: "\(scopeDescription); bookmark persistence failed"),
                scanPolicy: policy,
                bookmarkStatus: .failed(reason: error.localizedDescription)
            )
            statusMessage = "Opened \(project.name), but bookmark persistence failed: \(error.localizedDescription)"
        }

        projects.append(project)
        persistedRecords[project.id] = record
        selectedProjectID = project.id
        persistWorkspaceState()
        Task { await scan(project) }
    }

    func revoke(_ project: ProjectContext) {
        stopSecurityScope(for: project.id)
        projects.removeAll { $0.id == project.id }
        snapshots[project.id] = nil
        persistedRecords[project.id] = nil
        if selectedProjectID == project.id {
            selectedProjectID = projects.first?.id
        }
        persistWorkspaceState()
        statusMessage = "Access removed for \(project.name)."
    }

    func selectProject(_ project: ProjectContext) {
        selectedProjectID = project.id
        selectedModule = .projects
        persistWorkspaceState()
    }

    func rescanSelectedProject() async {
        guard let selectedProject else {
            statusMessage = "No project selected."
            return
        }
        await scan(selectedProject)
    }

    func reportForSelectedProject() -> String {
        guard let selectedSnapshot else {
            return "No LocalForge report is available because no project has been scanned."
        }
        return reportEngine.markdownReport(for: selectedSnapshot)
    }

    // MARK: - Mission & verification (Phase 3)

    /// Save (or clear) a user-defined mission and recompute reality without rescanning files.
    /// Phase 6: also appends a Mission journal entry so the change is recorded.
    func setMission(_ mission: UserMissionProfile, for projectID: UUID) {
        let previous = persistedRecords[projectID]?.mission
        persistedRecords[projectID]?.mission = mission.isDefined ? mission : nil
        if mission.isDefined, previous?.statedMission != mission.statedMission || previous?.currentPhase != mission.currentPhase {
            appendJournal(
                journalEngine.missionEntry(stated: mission.statedMission, phase: mission.currentPhase, author: ""),
                for: projectID
            )
        }
        persistWorkspaceState()
        reEnrich(projectID)
        statusMessage = mission.isDefined ? "Mission saved for \(projectName(projectID))." : "Mission cleared for \(projectName(projectID))."
    }

    /// Update a single verification record (by area) and recompute reality.
    /// Also appends an entry to the project journal — institutional memory.
    func updateVerification(_ record: VerificationRecord, for projectID: UUID) {
        guard let snapshot = snapshots[projectID] else { return }
        var records = snapshot.verification
        let previous = records.first { $0.area == record.area }
        if let index = records.firstIndex(where: { $0.area == record.area }) {
            records[index] = record
        } else {
            records.append(record)
        }
        persistedRecords[projectID]?.verification = records
        // Only journal real state changes (avoid noise when just editing notes).
        if previous?.state != record.state {
            appendJournal(
                journalEngine.verificationEntry(
                    area: record.area,
                    state: record.state,
                    note: record.note,
                    author: record.verifiedBy
                ),
                for: projectID
            )
        }
        persistWorkspaceState()
        reEnrich(projectID)
    }

    func applySetup(_ draft: ProjectSetupDraft, for projectID: UUID) {
        let result = draft.materialize()
        persistedRecords[projectID]?.mission = result.mission
        persistedRecords[projectID]?.verification = result.verification
        appendJournal(journalEngine.setupEntry(author: draft.author), for: projectID)
        appendJournal(
            journalEngine.missionEntry(stated: result.mission.statedMission, phase: result.mission.currentPhase, author: draft.author),
            for: projectID
        )
        persistWorkspaceState()
        reEnrich(projectID)
        setupProjectID = nil
        statusMessage = "Project setup saved for \(projectName(projectID))."
    }

    func addKnowledgeNote(_ note: KnowledgeNote, for projectID: UUID) {
        var notes = persistedRecords[projectID]?.knowledgeNotes ?? []
        notes.insert(note, at: 0)
        persistedRecords[projectID]?.knowledgeNotes = notes
        appendJournal(journalEngine.knowledgeEntry(title: note.title, kind: note.kind, author: note.author), for: projectID)
        persistWorkspaceState()
        reEnrich(projectID)
        statusMessage = "Knowledge note saved for \(projectName(projectID))."
    }

    func knowledgeNotes(for projectID: UUID?) -> [KnowledgeNote] {
        guard let projectID else { return [] }
        return (persistedRecords[projectID]?.knowledgeNotes ?? [])
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Evidence (Phase 7)

    func evidence(for projectID: UUID?) -> [EvidenceRecord] {
        guard let projectID else { return [] }
        return (persistedRecords[projectID]?.evidence ?? [])
            .sorted { $0.createdAt > $1.createdAt }
    }

    func evidence(for projectID: UUID, area: String) -> [EvidenceRecord] {
        evidence(for: projectID).filter { $0.area == area }
    }

    func addEvidence(_ record: EvidenceRecord, for projectID: UUID) {
        var existing = persistedRecords[projectID]?.evidence ?? []
        existing.insert(record, at: 0)
        persistedRecords[projectID]?.evidence = existing
        appendJournal(
            JournalEntry(
                kind: .note,
                summary: "Evidence added · \(record.area)",
                detail: record.summary,
                author: record.author
            ),
            for: projectID
        )
        persistWorkspaceState()
        reEnrich(projectID)
        statusMessage = "Evidence saved for \(projectName(projectID))."
    }

    func removeEvidence(id: UUID, for projectID: UUID) {
        var existing = persistedRecords[projectID]?.evidence ?? []
        existing.removeAll { $0.id == id }
        persistedRecords[projectID]?.evidence = existing
        persistWorkspaceState()
        reEnrich(projectID)
    }

    // MARK: - Templates & Packs (Phase 7)

    private let templateCatalogue = MissionTemplateCatalogue()

    func missionTemplates(for kind: ProjectKind) -> [MissionTemplate] {
        templateCatalogue.templates(for: kind)
    }

    func verificationPacks(for kind: ProjectKind) -> [VerificationPack] {
        templateCatalogue.packs(for: kind)
    }

    /// One-click: apply a pack's verification areas to the active project,
    /// preserving any existing state where the area is already tracked.
    func applyVerificationPack(_ pack: VerificationPack, for projectID: UUID, author: String = "") {
        let existing = persistedRecords[projectID]?.verification ?? []
        var merged = existing
        let existingAreas = Set(existing.map(\.area))
        for area in pack.areas where !existingAreas.contains(area.area) {
            merged.append(VerificationRecord(
                area: area.area,
                state: .unknown,
                note: "",
                verifiedBy: author,
                dependsOn: area.dependsOn
            ))
        }
        // For areas that already exist, fill in dependencies if the user hasn't set any.
        for (i, record) in merged.enumerated() {
            if record.dependsOn.isEmpty,
               let packDeps = pack.areas.first(where: { $0.area == record.area })?.dependsOn,
               !packDeps.isEmpty {
                merged[i].dependsOn = packDeps
            }
        }
        persistedRecords[projectID]?.verification = merged

        // Phase 8: seed the pack's kind-typical risks — skip any title that
        // already exists so re-applying a pack never duplicates.
        let existingRisks = persistedRecords[projectID]?.risks ?? []
        let existingRiskTitles = Set(existingRisks.map { $0.title.lowercased() })
        let newRisks = pack.suggestedRisks
            .filter { !existingRiskTitles.contains($0.title.lowercased()) }
            .map { $0.materialise() }
        if !newRisks.isEmpty {
            persistedRecords[projectID]?.risks = newRisks + existingRisks
        }

        appendJournal(
            JournalEntry(
                kind: .setup,
                summary: "Applied verification pack: \(pack.name)",
                detail: newRisks.isEmpty ? pack.blurb : "\(pack.blurb) Seeded \(newRisks.count) typical risk(s).",
                author: author
            ),
            for: projectID
        )
        persistWorkspaceState()
        reEnrich(projectID)
        statusMessage = "Applied \(pack.name) to \(projectName(projectID))."
    }

    // MARK: - Project Journal (Phase 6)

    func journal(for projectID: UUID?) -> [JournalEntry] {
        guard let projectID else { return [] }
        return (persistedRecords[projectID]?.journal ?? [])
            .sorted { $0.occurredAt > $1.occurredAt }
    }

    /// Add a free-form developer journal entry (e.g. "Investigated AUState handling").
    func addJournalEntry(_ entry: JournalEntry, for projectID: UUID) {
        appendJournal(entry, for: projectID)
        persistWorkspaceState()
        statusMessage = "Journal entry saved for \(projectName(projectID))."
    }

    /// Internal: append an entry, capped at 500.
    private func appendJournal(_ entry: JournalEntry, for projectID: UUID) {
        let existing = persistedRecords[projectID]?.journal ?? []
        persistedRecords[projectID]?.journal = journalEngine.appending(entry, to: existing)
    }

    /// Set a user-defined mission (overrides Phase 3 behaviour to also journal).
    func setMissionAndJournal(_ mission: UserMissionProfile, for projectID: UUID, author: String = "") {
        persistedRecords[projectID]?.mission = mission.isDefined ? mission : nil
        if mission.isDefined {
            appendJournal(
                journalEngine.missionEntry(stated: mission.statedMission, phase: mission.currentPhase, author: author),
                for: projectID
            )
        }
        persistWorkspaceState()
        reEnrich(projectID)
        statusMessage = mission.isDefined ? "Mission saved for \(projectName(projectID))." : "Mission cleared for \(projectName(projectID))."
    }

    private func projectName(_ id: UUID) -> String {
        projects.first { $0.id == id }?.name ?? "project"
    }

    private func scan(_ project: ProjectContext) async {
        isScanning = true
        statusMessage = "Scanning \(project.name) in \(scanMode.rawValue) mode..."
        do {
            let snapshot = try await scanner.scan(project)
            snapshots[project.id] = enrich(snapshot, projectID: project.id)
            statusMessage = "Last scan: \(project.name), \(snapshot.summary.totalFiles) files observed."
            if persistedRecords[project.id]?.mission == nil {
                setupProjectID = project.id
            }
        } catch {
            statusMessage = "Scan failed: \(error.localizedDescription)"
        }
        isScanning = false
    }

    /// Recompute mission/verification/reality for an already-scanned project (no file IO).
    private func reEnrich(_ projectID: UUID) {
        guard let snapshot = snapshots[projectID] else { return }
        snapshots[projectID] = enrich(snapshot, projectID: projectID)
    }

    /// Fold the user's persisted mission and verification into a snapshot and
    /// recompute the reality assessment from that real, human-entered truth.
    private func enrich(_ snapshot: RepoSnapshot, projectID: UUID) -> RepoSnapshot {
        var enriched = snapshot
        let record = persistedRecords[projectID]
        let userMission = record?.mission
        let reconciled = verificationEngine.reconcile(
            applicability: snapshot.applicability,
            saved: record?.verification ?? []
        )
        let effectiveMission = userMission?.asMissionProfile() ?? snapshot.mission

        enriched.userMission = userMission
        enriched.mission = effectiveMission
        enriched.verification = reconciled
        let knowledgeIssues = (record?.knowledgeNotes ?? [])
            .filter { $0.kind == .knownIssue }
            .map { $0.title.isEmpty ? $0.body : $0.title }
        let evidenceRecords = record?.evidence ?? []
        let riskRecords = record?.risks ?? []
        let assumptionRecords = record?.assumptions ?? []
        enriched.reality = realityEngine.assess(
            identity: snapshot.identity,
            mission: effectiveMission,
            applicability: snapshot.applicability,
            git: snapshot.git,
            summary: snapshot.summary,
            findings: snapshot.findings,
            evidence: snapshot.evidence,
            verification: reconciled,
            knownIssues: (userMission?.knownIssues ?? []) + knowledgeIssues,
            evidenceRecords: evidenceRecords,
            riskRecords: riskRecords,
            assumptionRecords: assumptionRecords
        )
        return enriched
    }

    // MARK: - Registers (Phase 7)

    func decisions(for projectID: UUID?) -> [DecisionRecord] {
        guard let id = projectID else { return [] }
        return (persistedRecords[id]?.decisions ?? []).sorted { $0.updatedAt > $1.updatedAt }
    }
    func architecture(for projectID: UUID?) -> [ArchitectureItem] {
        guard let id = projectID else { return [] }
        return (persistedRecords[id]?.architecture ?? []).sorted { $0.name < $1.name }
    }
    func risks(for projectID: UUID?) -> [RiskRecord] {
        guard let id = projectID else { return [] }
        return (persistedRecords[id]?.risks ?? []).sorted { $0.severityScore > $1.severityScore }
    }
    func assumptions(for projectID: UUID?) -> [AssumptionRecord] {
        guard let id = projectID else { return [] }
        return (persistedRecords[id]?.assumptions ?? []).sorted { $0.updatedAt > $1.updatedAt }
    }

    func addDecision(_ d: DecisionRecord, for projectID: UUID) {
        var existing = persistedRecords[projectID]?.decisions ?? []
        existing.insert(d, at: 0)
        persistedRecords[projectID]?.decisions = existing
        appendJournal(JournalEntry(kind: .decision, summary: "Decision · \(d.title)", detail: d.reason, author: d.author), for: projectID)
        persistWorkspaceState(); reEnrich(projectID)
    }
    func removeDecision(id: UUID, for projectID: UUID) {
        persistedRecords[projectID]?.decisions?.removeAll { $0.id == id }
        persistWorkspaceState(); reEnrich(projectID)
    }

    func addArchitectureItem(_ a: ArchitectureItem, for projectID: UUID) {
        var existing = persistedRecords[projectID]?.architecture ?? []
        existing.insert(a, at: 0)
        persistedRecords[projectID]?.architecture = existing
        appendJournal(JournalEntry(kind: .note, summary: "Architecture · \(a.name)", detail: a.purpose, author: a.owner), for: projectID)
        persistWorkspaceState(); reEnrich(projectID)
    }
    func removeArchitectureItem(id: UUID, for projectID: UUID) {
        persistedRecords[projectID]?.architecture?.removeAll { $0.id == id }
        persistWorkspaceState(); reEnrich(projectID)
    }

    func addRisk(_ r: RiskRecord, for projectID: UUID) {
        var existing = persistedRecords[projectID]?.risks ?? []
        existing.insert(r, at: 0)
        persistedRecords[projectID]?.risks = existing
        appendJournal(JournalEntry(kind: .note, summary: "Risk · \(r.title) (\(r.impact.rawValue)/\(r.likelihood.rawValue))", detail: r.description, author: r.owner), for: projectID)
        persistWorkspaceState(); reEnrich(projectID)
    }
    func removeRisk(id: UUID, for projectID: UUID) {
        persistedRecords[projectID]?.risks?.removeAll { $0.id == id }
        persistWorkspaceState(); reEnrich(projectID)
    }

    func addAssumption(_ a: AssumptionRecord, for projectID: UUID) {
        var existing = persistedRecords[projectID]?.assumptions ?? []
        existing.insert(a, at: 0)
        persistedRecords[projectID]?.assumptions = existing
        appendJournal(JournalEntry(kind: .note, summary: "Assumption · \(a.assumption)", detail: a.rationale), for: projectID)
        persistWorkspaceState(); reEnrich(projectID)
    }
    func removeAssumption(id: UUID, for projectID: UUID) {
        persistedRecords[projectID]?.assumptions?.removeAll { $0.id == id }
        persistWorkspaceState(); reEnrich(projectID)
    }

    // MARK: - Cross-linking (Phase 7.5)

    func updateEvidence(_ record: EvidenceRecord, for projectID: UUID) {
        guard var existing = persistedRecords[projectID]?.evidence,
              let i = existing.firstIndex(where: { $0.id == record.id }) else { return }
        existing[i] = record
        persistedRecords[projectID]?.evidence = existing
        persistWorkspaceState(); reEnrich(projectID)
    }
    func updateDecision(_ record: DecisionRecord, for projectID: UUID) {
        guard var existing = persistedRecords[projectID]?.decisions,
              let i = existing.firstIndex(where: { $0.id == record.id }) else { return }
        existing[i] = record
        persistedRecords[projectID]?.decisions = existing
        persistWorkspaceState(); reEnrich(projectID)
    }
    func updateRisk(_ record: RiskRecord, for projectID: UUID) {
        guard var existing = persistedRecords[projectID]?.risks,
              let i = existing.firstIndex(where: { $0.id == record.id }) else { return }
        existing[i] = record
        persistedRecords[projectID]?.risks = existing
        persistWorkspaceState(); reEnrich(projectID)
    }
    func updateArchitectureItem(_ record: ArchitectureItem, for projectID: UUID) {
        guard var existing = persistedRecords[projectID]?.architecture,
              let i = existing.firstIndex(where: { $0.id == record.id }) else { return }
        existing[i] = record
        persistedRecords[projectID]?.architecture = existing
        persistWorkspaceState(); reEnrich(projectID)
    }
    func updateAssumption(_ record: AssumptionRecord, for projectID: UUID) {
        guard var existing = persistedRecords[projectID]?.assumptions,
              let i = existing.firstIndex(where: { $0.id == record.id }) else { return }
        existing[i] = record
        persistedRecords[projectID]?.assumptions = existing
        persistWorkspaceState(); reEnrich(projectID)
    }

    // MARK: - Universal Search (Phase 8)

    private let searchEngine = SearchEngine()

    /// Search every record type across every open project.
    func searchWorkspace(_ query: String) -> [SearchHit] {
        let ordered = projects.compactMap { persistedRecords[$0.id] }
        return searchEngine.search(query, in: ordered)
    }

    // MARK: - Workspace export / import (Phase 8)

    /// The entire workspace as pretty-printed JSON — backup, audit, or transfer.
    func exportWorkspaceJSON() -> Data? {
        let orderedRecords = projects.compactMap { persistedRecords[$0.id] }
        let state = WorkspacePersistenceState(
            projects: orderedRecords,
            scanMode: scanMode,
            theme: themePreferences,
            lastActiveProjectID: selectedProjectID
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(state)
    }

    /// Replace the whole workspace from an exported JSON file. Destructive by
    /// design (it is a restore) — callers must confirm with the user first.
    func importWorkspace(from data: Data) -> Bool {
        guard let state = try? JSONDecoder().decode(WorkspacePersistenceState.self, from: data) else {
            statusMessage = "Import failed: the file is not a LocalForge workspace export."
            return false
        }
        for project in projects { stopSecurityScope(for: project.id) }
        isRestoringState = true
        scanMode = state.scanMode
        themePreferences = state.theme
        isRestoringState = false
        persistedRecords = Dictionary(uniqueKeysWithValues: state.projects.map { ($0.id, $0) })
        let resolved = state.projects.map { $0.resolve(using: bookmarkProvider) }
        projects = resolved.map(\.project)
        activeSecurityScopeURLs = Dictionary(
            uniqueKeysWithValues: resolved.compactMap { access in
                guard let url = access.securityScopeURL else { return nil }
                return (access.project.id, url)
            }
        )
        selectedProjectID = state.lastActiveProjectID ?? projects.first?.id
        snapshots = [:]
        persistWorkspaceState()
        for project in projects {
            Task { await scan(project) }
        }
        statusMessage = "Imported workspace with \(projects.count) project(s)."
        return true
    }

    /// Everything connected to one record, resolved in both directions.
    func relatedRecords(for ref: TruthRecordRef, projectID: UUID) -> RelatedRecords {
        truthEngine.related(
            to: ref,
            evidence: evidence(for: projectID),
            risks: risks(for: projectID),
            decisions: decisions(for: projectID),
            architecture: architecture(for: projectID),
            assumptions: assumptions(for: projectID),
            verification: snapshots[projectID]?.verification ?? []
        )
    }

    private func loadPersistedWorkspace() {
        isRestoringState = true
        defer { isRestoringState = false }

        do {
            let state = try persistenceStore.load()
            scanMode = state.scanMode
            themePreferences = state.theme
            favoritedProjectIDs = Set(state.favoritedProjectIDs)
            pinnedItems = state.pinnedItems
            savedViews = state.savedViews.isEmpty ? Self.defaultSavedViews : state.savedViews
            persistedRecords = Dictionary(uniqueKeysWithValues: state.projects.map { ($0.id, $0) })

            let resolved = state.projects.map { $0.resolve(using: bookmarkProvider) }
            projects = resolved.map(\.project)
            activeSecurityScopeURLs = Dictionary(
                uniqueKeysWithValues: resolved.compactMap { access in
                    guard let url = access.securityScopeURL else { return nil }
                    return (access.project.id, url)
                }
            )
            selectedProjectID = restoreActiveProject(from: state, projects: projects)

            if projects.isEmpty {
                statusMessage = "Open a repository to begin local-first analysis."
            } else {
                let attention = projects.filter(\.bookmarkStatus.requiresAttention)
                statusMessage = attention.isEmpty
                    ? "Restored \(projects.count) approved project\(projects.count == 1 ? "" : "s")."
                    : "Restored \(projects.count) project\(projects.count == 1 ? "" : "s"); \(attention.count) need access refresh."
            }
            // Surface migration / corruption-recovery / fallback notes honestly.
            if let note = persistenceStore.lastLoadNote {
                statusMessage = note
            }
            if let fallback = persistenceFallbackNote {
                statusMessage = fallback
            }

            for project in projects {
                Task { await scan(project) }
            }
        } catch {
            projects = []
            selectedProjectID = nil
            statusMessage = "Saved workspace state could not be loaded: \(error.localizedDescription)"
        }
    }

    private func restoreActiveProject(from state: WorkspacePersistenceState, projects: [ProjectContext]) -> UUID? {
        if let lastActiveProjectID = state.lastActiveProjectID,
           projects.contains(where: { $0.id == lastActiveProjectID }) {
            return lastActiveProjectID
        }
        return projects.first?.id
    }

    private func updateSelectedProjectScanPolicy() {
        guard let selectedProjectID,
              let index = projects.firstIndex(where: { $0.id == selectedProjectID }) else {
            return
        }
        let policy = ScanPolicy.defaults(for: scanMode)
        projects[index].scanPolicy = policy
        if var record = persistedRecords[selectedProjectID] {
            record.scanPolicy = policy
            persistedRecords[selectedProjectID] = record
        }
    }

    private func persistWorkspaceState() {
        let orderedRecords = projects.compactMap { persistedRecords[$0.id] }
        let state = WorkspacePersistenceState(
            projects: orderedRecords,
            scanMode: scanMode,
            theme: themePreferences,
            lastActiveProjectID: selectedProjectID,
            savedViews: savedViews,
            pinnedItems: pinnedItems,
            favoritedProjectIDs: Array(favoritedProjectIDs)
        )
        do {
            try persistenceStore.save(state)
        } catch {
            statusMessage = "Could not save workspace state: \(error.localizedDescription)"
        }
    }

    private func stopSecurityScope(for projectID: UUID) {
        guard let url = activeSecurityScopeURLs.removeValue(forKey: projectID) else { return }
        bookmarkProvider.stopAccessing(url)
    }

    // MARK: - Phase 8.5: Command Palette

    func commandPaletteItems(query: String) -> [CommandPaletteItem] {
        let records = projects.compactMap { persistedRecords[$0.id] }
        let names = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })
        return commandPaletteEngine.items(query: query, records: records, projectNames: names)
    }

    // MARK: - Phase 8.5: Why Panel

    func whyReality(for projectID: UUID) -> WhyPanelContent {
        let breakdown = selectedRealityBreakdown
        return whyEngine.whyReality(
            breakdown: breakdown,
            evidence: evidence(for: projectID),
            risks: risks(for: projectID),
            decisions: decisions(for: projectID)
        )
    }

    func whyVerification(_ record: VerificationRecord, for projectID: UUID) -> WhyPanelContent {
        whyEngine.whyVerification(
            record: record,
            evidence: evidence(for: projectID, area: record.area),
            journal: journal(for: projectID)
        )
    }

    func whyRisk(_ risk: RiskRecord, for projectID: UUID) -> WhyPanelContent {
        whyEngine.whyRisk(
            risk: risk,
            evidence: evidence(for: projectID),
            verification: snapshots[projectID]?.verification ?? [],
            decisions: decisions(for: projectID),
            architecture: architecture(for: projectID)
        )
    }

    func whyRelease(for projectID: UUID) -> WhyPanelContent {
        guard let board = releaseBoard else { return .empty }
        return whyEngine.whyRelease(board: board, risks: risks(for: projectID))
    }

    // MARK: - Phase 8.5: Workspace Health

    var workspaceHealthReport: WorkspaceHealthReport {
        let records = projects.compactMap { persistedRecords[$0.id] }
        let names = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })
        return healthEngine.report(projects: records, projectNames: names)
    }

    // MARK: - Phase 8.5: Workspace Doctor

    var workspaceDoctorReport: WorkspaceDoctorReport {
        let records = projects.compactMap { persistedRecords[$0.id] }
        let names = Dictionary(uniqueKeysWithValues: projects.map { ($0.id, $0.name) })
        return doctorEngine.diagnose(records: records, projectNames: names)
    }

    // MARK: - Phase 8.5: Evidence Conflicts

    func evidenceConflicts(for projectID: UUID) -> [EvidenceConflict] {
        guard let project = projects.first(where: { $0.id == projectID }) else { return [] }
        return whyEngine.detectConflicts(
            evidence: evidence(for: projectID),
            projectID: projectID,
            projectName: project.name
        )
    }

    // MARK: - Phase 8.5: Confidence Provenance

    func confidenceProvenance(for projectID: UUID) -> ConfidenceProvenance {
        let assessment = selectedConfidence
        return whyEngine.confidenceProvenance(assessment: assessment, evidence: evidence(for: projectID))
    }

    // MARK: - Phase 8.5: Release Blocking Chain

    func releaseBlockingChain(for projectID: UUID) -> ReleaseBlockNode? {
        guard let board = releaseBoard else { return nil }
        let riskRecords = risks(for: projectID)
        let blockers = board.rows.filter { $0.state == .failed || !$0.blockedBy.isEmpty }
        let riskBlockers = riskRecords.filter(\.isReleaseBlocking)

        var children: [ReleaseBlockNode] = blockers.map { row in
            let depNodes = row.blockedBy.map { dep in
                ReleaseBlockNode(label: dep, kind: .dependency, state: "Blocking", isBlocking: true)
            }
            return ReleaseBlockNode(
                label: row.area,
                kind: .verification,
                state: row.state.rawValue,
                isBlocking: true,
                children: depNodes
            )
        }
        children += riskBlockers.map { r in
            ReleaseBlockNode(label: r.title, kind: .risk, state: "\(r.impact.rawValue) risk", isBlocking: true)
        }

        return ReleaseBlockNode(
            label: "Release",
            kind: .release,
            state: board.status.rawValue,
            isBlocking: board.status == .blocked || board.status == .notReady,
            children: children
        )
    }

    // MARK: - Phase 8.5: Favourites + Pinning

    func toggleFavourite(_ projectID: UUID) {
        if favoritedProjectIDs.contains(projectID) {
            favoritedProjectIDs.remove(projectID)
        } else {
            favoritedProjectIDs.insert(projectID)
        }
        persistWorkspaceState()
    }

    func isFavourited(_ projectID: UUID) -> Bool {
        favoritedProjectIDs.contains(projectID)
    }

    func pin(_ item: PinnedItem) {
        guard !pinnedItems.contains(where: { $0.recordID == item.recordID && $0.kind == item.kind }) else { return }
        pinnedItems.insert(item, at: 0)
        persistWorkspaceState()
    }

    func unpin(id: UUID) {
        pinnedItems.removeAll { $0.id == id }
        persistWorkspaceState()
    }

    func isPinned(recordID: UUID, kind: PinnedItemKind) -> Bool {
        pinnedItems.contains { $0.recordID == recordID && $0.kind == kind }
    }

    // MARK: - Phase 8.5: Saved Views

    func addSavedView(_ view: SavedView) {
        savedViews.append(view)
        persistWorkspaceState()
    }

    func removeSavedView(id: UUID) {
        savedViews.removeAll { $0.id == id }
        persistWorkspaceState()
    }

    func toggleSavedViewPin(id: UUID) {
        guard let i = savedViews.firstIndex(where: { $0.id == id }) else { return }
        savedViews[i].isPinned.toggle()
        persistWorkspaceState()
    }

    private static let defaultSavedViews: [SavedView] = [
        SavedView(kind: .myBlockers, name: "My Blockers"),
        SavedView(kind: .openRisks, name: "Open Risks"),
        SavedView(kind: .releaseRisks, name: "Release Risks"),
        SavedView(kind: .staleVerification, name: "Stale Verification"),
        SavedView(kind: .architectureReview, name: "Architecture Review"),
        SavedView(kind: .recentEvidence, name: "Recent Evidence"),
        SavedView(kind: .criticalAssumptions, name: "Critical Assumptions"),
    ]

    // MARK: - Phase 8.5: Project Review Mode

    func startProjectReview(for projectID: UUID) -> ProjectReviewSession {
        let questions = [
            "What changed since the last review?",
            "What failed or broke?",
            "What was verified or confirmed?",
            "Are there new risks to log?",
            "Are there new decisions to record?",
            "Are there new assumptions to track?",
            "Is the project release-ready?",
        ].map { ProjectReviewQuestion(question: $0) }
        return ProjectReviewSession(projectID: projectID, questions: questions)
    }

    /// Result of a project review submission — surfaced inline in the Review
    /// view rather than leaking into the global status banner (which is shown
    /// across every screen).
    @discardableResult
    func completeProjectReview(_ session: ProjectReviewSession) -> Int {
        let answered = session.questions.filter { $0.isAnswered && !$0.answer.isEmpty }
        for q in answered {
            appendJournal(
                JournalEntry(
                    kind: .note,
                    summary: "Review: \(q.question)",
                    detail: q.answer,
                    author: ""
                ),
                for: session.projectID
            )
        }
        persistWorkspaceState()
        return answered.count
    }

    /// Read-only gating: mutating Utility Centre actions (Remove Quarantine,
    /// Clean DerivedData) are blocked unless the user opts in. Default is
    /// blocked; the toggle lives in the Utility Centre header.
    @Published var allowUtilityMutations: Bool = false

    // MARK: - Phase 9: Build History

    func buildHistory(for projectID: UUID?) -> [BuildRecord] {
        guard let id = projectID else { return [] }
        return (persistedRecords[id]?.buildHistory ?? []).sorted { $0.startTime > $1.startTime }
    }

    func addBuildRecord(_ record: BuildRecord, for projectID: UUID) {
        var existing = persistedRecords[projectID]?.buildHistory ?? []
        existing.insert(record, at: 0)
        if existing.count > 50 { existing = Array(existing.prefix(50)) }
        persistedRecords[projectID]?.buildHistory = existing
        appendJournal(
            JournalEntry(
                kind: .note,
                summary: "Build \(record.buildType.rawValue): \(record.result.rawValue)",
                detail: record.notes,
                author: ""
            ),
            for: projectID
        )
        persistWorkspaceState()
    }

    // MARK: - Phase 9: Environment Registry

    func environments(for projectID: UUID?) -> [EnvironmentSnapshot] {
        guard let id = projectID else { return [] }
        return (persistedRecords[id]?.environments ?? []).sorted { $0.capturedAt > $1.capturedAt }
    }

    func addEnvironmentSnapshot(_ snapshot: EnvironmentSnapshot, for projectID: UUID) {
        var existing = persistedRecords[projectID]?.environments ?? []
        existing.insert(snapshot, at: 0)
        if existing.count > 20 { existing = Array(existing.prefix(20)) }
        persistedRecords[projectID]?.environments = existing
        persistWorkspaceState()
        statusMessage = "Environment snapshot saved."
    }

    // MARK: - Phase 9: Test Registry

    func testRecords(for projectID: UUID?) -> [TestRecord] {
        guard let id = projectID else { return [] }
        return (persistedRecords[id]?.testRecords ?? []).sorted { $0.testedAt > $1.testedAt }
    }

    func addTestRecord(_ record: TestRecord, for projectID: UUID) {
        var existing = persistedRecords[projectID]?.testRecords ?? []
        if let index = existing.firstIndex(where: { $0.id == record.id }) {
            existing[index] = record
            statusMessage = "Test record updated."
        } else {
            existing.insert(record, at: 0)
            appendJournal(
                JournalEntry(
                    kind: .note,
                    summary: "Test \(record.outcome.rawValue): \(record.name)",
                    detail: record.notes,
                    author: record.author
                ),
                for: projectID
            )
            statusMessage = "Test record saved."
        }
        persistedRecords[projectID]?.testRecords = existing.sorted { $0.testedAt > $1.testedAt }
        persistWorkspaceState()
    }

    // MARK: - Phase 10C: Recommendations / Approval Gate

    func recommendations(for projectID: UUID?) -> [RecommendationRecord] {
        guard let id = projectID else { return [] }
        return (persistedRecords[id]?.recommendations ?? [])
            .sorted {
                if $0.severity.rank == $1.severity.rank { return $0.updatedAt > $1.updatedAt }
                return $0.severity.rank > $1.severity.rank
            }
    }

    func runCodeSizeRecommendationScan(for projectID: UUID) {
        guard let project = projects.first(where: { $0.id == projectID }) else { return }
        let findings = codeBloatScanner.scan(repoRoot: project.rootURL)
        let scanned = codeBloatScanner.recommendations(from: findings)
        mergeRecommendations(scanned, for: projectID)

        let evidence = EvidenceRecord(
            area: "Repository Hygiene",
            kind: .observation,
            summary: "Code-size scan found \(findings.count) file(s) over \(CodeBloatScannerEngine.defaultLineThreshold) lines.",
            body: findings.map { "\($0.relativePath): \($0.lineCount) lines" }.joined(separator: "\n"),
            classification: .observed,
            author: "LocalForge",
        )
        addEvidence(evidence, for: projectID)
        statusMessage = findings.isEmpty ? "Code-size scan complete: no files over threshold." : "Code-size scan complete: \(findings.count) recommendation(s) created."
    }

    func updateRecommendationState(
        id: UUID,
        state: RecommendationApprovalState,
        for projectID: UUID,
        author: String = NSFullUserName(),
        note: String = ""
    ) {
        guard var recommendations = persistedRecords[projectID]?.recommendations,
              let index = recommendations.firstIndex(where: { $0.id == id }) else { return }
        let updated = recommendations[index].withApprovalState(state, by: author, note: note)
        let evidence = EvidenceRecord(
            area: "Approval Gate",
            kind: .observation,
            summary: "Recommendation marked \(state.rawValue): \(updated.title)",
            body: """
            Target: \(updated.targetPath)
            Source files affected: \(updated.sourceFilesAffected ? "Yes" : "No")
            Warning: \(updated.safetyWarning)
            Note: \(note)
            """,
            classification: .observed,
            author: author
        )
        var withEvidence = updated
        withEvidence.relatedEvidenceIDs.insert(evidence.id, at: 0)
        recommendations[index] = withEvidence
        persistedRecords[projectID]?.recommendations = recommendations
        appendJournal(
            JournalEntry(
                kind: .note,
                summary: "Recommendation \(state.rawValue): \(updated.title)",
                detail: note.isEmpty ? updated.suggestedAdjustment : note,
                author: author
            ),
            for: projectID
        )
        addEvidence(evidence, for: projectID)
        persistWorkspaceState()
        statusMessage = "Recommendation marked \(state.rawValue)."
    }

    private func mergeRecommendations(_ incoming: [RecommendationRecord], for projectID: UUID) {
        var existing = persistedRecords[projectID]?.recommendations ?? []
        for recommendation in incoming {
            if let index = existing.firstIndex(where: {
                $0.category == recommendation.category && $0.targetPath == recommendation.targetPath
            }) {
                var merged = recommendation
                merged.id = existing[index].id
                merged.createdAt = existing[index].createdAt
                merged.approvalState = existing[index].approvalState
                merged.approvedBy = existing[index].approvedBy
                merged.approvalNote = existing[index].approvalNote
                merged.relatedEvidenceIDs = existing[index].relatedEvidenceIDs
                existing[index] = merged
            } else {
                existing.insert(recommendation, at: 0)
            }
        }
        persistedRecords[projectID]?.recommendations = existing
        persistWorkspaceState()
    }
}

struct WorkspaceCounts: Equatable {
    var total: Int
    var healthy: Int
    var warning: Int
    var critical: Int
    var activeScans: Int
}
