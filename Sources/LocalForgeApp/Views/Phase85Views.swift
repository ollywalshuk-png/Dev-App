import AppKit
import LocalForgeCore
import SwiftUI

// MARK: - Verification History View

/// Phase 8.5 — Verification history reconstructed from the project journal.
struct VerificationHistoryView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var filter: HistoryFilter = .all
    @State private var areaFilter: String = ""

    enum HistoryFilter: String, CaseIterable, Identifiable {
        case all = "All"
        case verified = "Verified"
        case failed = "Failed"
        case inProgress = "In Progress"
        case unknown = "Unknown"
        var id: String { rawValue }
    }

    var body: some View {
        if let project = store.selectedProject {
            VStack(alignment: .leading, spacing: 0) {
                header(project: project)
                Divider()
                content(project: project)
            }
        } else {
            ContentUnavailableView("No project selected", systemImage: "clock.arrow.circlepath",
                description: Text("Select a project to view verification history."))
        }
    }

    private func header(project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Verification History")
                .font(.system(size: 26, weight: .bold))
            Text(project.name)
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Picker("Filter", selection: $filter) {
                    ForEach(HistoryFilter.allCases) { f in
                        Text(f.rawValue).tag(f)
                    }
                }
                .pickerStyle(.segmented)
                .frame(width: 380)

                TextField("Filter by area…", text: $areaFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
            }
        }
        .padding(20)
    }

    private func content(project: ProjectContext) -> some View {
        let entries = store.journal(for: project.id).filter { $0.kind == .verification }
        let filtered = entries.filter { entry in
            let matchesArea = areaFilter.isEmpty || entry.summary.localizedCaseInsensitiveContains(areaFilter)
            let matchesState: Bool = {
                switch filter {
                case .all: return true
                case .verified: return entry.summary.localizedCaseInsensitiveContains("Verified")
                case .failed: return entry.summary.localizedCaseInsensitiveContains("Failed")
                case .inProgress: return entry.summary.localizedCaseInsensitiveContains("In Progress")
                case .unknown: return entry.summary.localizedCaseInsensitiveContains("Unknown")
                }
            }()
            return matchesArea && matchesState
        }

        return Group {
            if filtered.isEmpty {
                ContentUnavailableView(
                    "No verification history",
                    systemImage: "clock.arrow.circlepath",
                    description: Text("Verification changes will be recorded here as you mark areas.")
                )
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 4) {
                        ForEach(filtered) { entry in
                            HistoryRow(entry: entry)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
}

private struct HistoryRow: View {
    var entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: stateIcon)
                .foregroundStyle(stateColor)
                .frame(width: 20)
                .padding(.top, 2)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry.summary)
                    .font(.system(size: 13, weight: .medium))
                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
                Text(entry.occurredAt.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var stateIcon: String {
        if entry.summary.localizedCaseInsensitiveContains("Verified") { return "checkmark.seal.fill" }
        if entry.summary.localizedCaseInsensitiveContains("Failed") { return "xmark.octagon.fill" }
        if entry.summary.localizedCaseInsensitiveContains("In Progress") { return "clock.fill" }
        return "questionmark.circle"
    }

    private var stateColor: Color {
        if entry.summary.localizedCaseInsensitiveContains("Verified") { return .green }
        if entry.summary.localizedCaseInsensitiveContains("Failed") { return .red }
        if entry.summary.localizedCaseInsensitiveContains("In Progress") { return .blue }
        return .secondary
    }
}

// MARK: - Saved Views

struct SavedViewsView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var selection: SavedView?

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            detail
        }
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Saved Views").font(.headline)
                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 8)

            List(selection: $selection) {
                Section("Pinned") {
                    ForEach(store.savedViews.filter(\.isPinned)) { view in
                        savedViewRow(view).tag(view)
                    }
                }
                Section("All") {
                    ForEach(store.savedViews) { view in
                        savedViewRow(view).tag(view)
                    }
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 240)
    }

    private func savedViewRow(_ view: SavedView) -> some View {
        HStack {
            Image(systemName: iconForKind(view.kind))
            Text(view.name).lineLimit(1)
            Spacer()
            if view.isPinned {
                Image(systemName: "pin.fill").font(.caption2).foregroundStyle(.orange)
            }
        }
    }

    private var detail: some View {
        Group {
            if let view = selection {
                SavedViewDetail(store: store, view: view)
            } else {
                ContentUnavailableView(
                    "Select a saved view",
                    systemImage: "bookmark",
                    description: Text("Choose a saved view to see what it matches across the workspace.")
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func iconForKind(_ kind: SavedViewKind) -> String {
        switch kind {
        case .myBlockers: "exclamationmark.octagon"
        case .openRisks: "exclamationmark.shield"
        case .releaseRisks: "flag.checkered"
        case .staleVerification: "clock.badge.exclamationmark"
        case .architectureReview: "square.3.layers.3d"
        case .recentEvidence: "paperclip"
        case .criticalAssumptions: "questionmark.diamond.fill"
        case .pinnedIssues: "pin"
        case .custom: "bookmark"
        }
    }
}

private struct SavedViewDetail: View {
    @ObservedObject var store: WorkspaceStore
    var view: SavedView

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    Text(view.name).font(.title2.weight(.semibold))
                    Spacer()
                    Button {
                        store.toggleSavedViewPin(id: view.id)
                    } label: {
                        Label(view.isPinned ? "Unpin" : "Pin", systemImage: view.isPinned ? "pin.slash" : "pin")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                results
            }
            .padding(20)
        }
    }

    @ViewBuilder
    private var results: some View {
        switch view.kind {
        case .openRisks, .releaseRisks:
            riskResults(releaseOnly: view.kind == .releaseRisks)
        case .staleVerification:
            staleVerificationResults
        case .recentEvidence:
            recentEvidenceResults
        case .criticalAssumptions:
            criticalAssumptionsResults
        case .architectureReview:
            architectureResults
        case .myBlockers:
            myBlockersResults
        case .pinnedIssues:
            pinnedResults
        case .custom:
            Text("Custom views are saved locally and applied to the workspace.")
                .foregroundStyle(.secondary)
        }
    }

    private func riskResults(releaseOnly: Bool) -> some View {
        let pairs = store.projects.flatMap { p -> [(ProjectContext, RiskRecord)] in
            store.risks(for: p.id).filter { r in
                r.status == .open && (!releaseOnly || r.isReleaseBlocking)
            }.map { (p, $0) }
        }
        return resultList(count: pairs.count, empty: "No matching risks.") {
            ForEach(pairs, id: \.1.id) { (project, risk) in
                resultRow(symbol: "exclamationmark.shield", title: risk.title,
                          subtitle: "\(risk.impact.rawValue) · \(project.name)")
            }
        }
    }

    private var staleVerificationResults: some View {
        let now = Date()
        let pairs = store.projects.flatMap { p -> [(ProjectContext, VerificationRecord)] in
            (store.snapshots[p.id]?.verification ?? []).filter { v in
                v.state == .verified && now.timeIntervalSince(v.updatedAt) > 90 * 86_400
            }.map { (p, $0) }
        }
        return resultList(count: pairs.count, empty: "No stale verification.") {
            ForEach(pairs, id: \.1.id) { (project, v) in
                resultRow(symbol: "clock.badge.exclamationmark", title: v.area,
                          subtitle: "Last verified \(v.ageDescription) · \(project.name)")
            }
        }
    }

    private var recentEvidenceResults: some View {
        let pairs = store.projects.flatMap { p -> [(ProjectContext, EvidenceRecord)] in
            store.evidence(for: p.id).prefix(10).map { (p, $0) }
        }
        return resultList(count: pairs.count, empty: "No evidence found.") {
            ForEach(pairs, id: \.1.id) { (project, e) in
                resultRow(symbol: "paperclip", title: e.summary.isEmpty ? e.kind.rawValue : e.summary,
                          subtitle: "\(e.area) · \(project.name)")
            }
        }
    }

    private var criticalAssumptionsResults: some View {
        let pairs = store.projects.flatMap { p -> [(ProjectContext, AssumptionRecord)] in
            store.assumptions(for: p.id).filter { $0.status == .active }.map { (p, $0) }
        }
        return resultList(count: pairs.count, empty: "No active assumptions.") {
            ForEach(pairs, id: \.1.id) { (project, a) in
                resultRow(symbol: "questionmark.diamond", title: a.assumption,
                          subtitle: project.name)
            }
        }
    }

    private var architectureResults: some View {
        let pairs = store.projects.flatMap { p -> [(ProjectContext, ArchitectureItem)] in
            store.architecture(for: p.id).filter { $0.status == .needsReview || $0.status == .failing }.map { (p, $0) }
        }
        return resultList(count: pairs.count, empty: "No architecture review needed.") {
            ForEach(pairs, id: \.1.id) { (project, a) in
                resultRow(symbol: "square.3.layers.3d", title: a.name,
                          subtitle: "\(a.status.rawValue) · \(project.name)")
            }
        }
    }

    private var myBlockersResults: some View {
        let blockers = store.projects.flatMap { p -> [String] in
            (store.snapshots[p.id]?.verification ?? []).filter { $0.state == .failed }.map { "\($0.area) — \(p.name)" }
        }
        return resultList(count: blockers.count, empty: "No blockers.") {
            ForEach(blockers, id: \.self) { blocker in
                resultRow(symbol: "exclamationmark.octagon.fill", title: blocker, subtitle: "Failed verification")
            }
        }
    }

    private var pinnedResults: some View {
        resultList(count: store.pinnedItems.count, empty: "Nothing pinned.") {
            ForEach(store.pinnedItems) { item in
                resultRow(symbol: "pin.fill", title: item.label, subtitle: item.kind.rawValue)
            }
        }
    }

    private func resultRow(symbol: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: symbol).foregroundStyle(.secondary).frame(width: 18)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 13))
                Text(subtitle).font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    @ViewBuilder
    private func resultList<Content: View>(count: Int, empty: String, @ViewBuilder content: () -> Content) -> some View {
        if count == 0 {
            Text(empty).foregroundStyle(.secondary).padding()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Text("\(count) match\(count == 1 ? "" : "es")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                content()
            }
        }
    }
}

// MARK: - Build History

struct BuildHistoryView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var showAdd = false
    @State private var newType: BuildType = .swiftBuild
    @State private var newResult: BuildResult = .success
    @State private var newNotes = ""

    var body: some View {
        if let project = store.selectedProject {
            ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                    header(project: project)
                    ExplanationCard(
                        title: "Build History",
                        what: "Build History records build observations, whether entered manually or captured from Dev Tools.",
                        why: "A build record is useful evidence, but it does not automatically verify the Build area until promoted or linked.",
                        next: "Log a successful or failed build, then promote successful output to evidence when you want it to support verification.",
                        safety: "Manual build records only update LocalForge's local workspace. Dev Tools presets run only when clicked.",
                        symbol: "hammer.circle",
                        tint: .orange
                    )
                    addCard
                    listCard(project: project)
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView("No project selected", systemImage: "hammer.circle",
                description: Text("Select a project to view its build history."))
        }
    }

    private func header(project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Build History").font(.system(size: 28, weight: .bold))
            Text(project.name).foregroundStyle(.secondary)
        }
    }

    private var addCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("LOG A BUILD").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                Picker("Type", selection: $newType) {
                    ForEach(BuildType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                Picker("Result", selection: $newResult) {
                    ForEach(BuildResult.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                TextField("Notes", text: $newNotes).textFieldStyle(.roundedBorder)
                Button("Add") {
                    guard let pid = store.selectedProjectID else { return }
                    let record = BuildRecord(buildType: newType, endTime: Date(), result: newResult, notes: newNotes)
                    store.addBuildRecord(record, for: pid)
                    newNotes = ""
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func listCard(project: ProjectContext) -> some View {
        let history = store.buildHistory(for: project.id)
        return VStack(alignment: .leading, spacing: 8) {
            Text("HISTORY").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            Text("Build records are a journal of what you ran. They do not auto-verify the Build area — promote a successful record to evidence to attach it.")
                .font(.caption).foregroundStyle(.secondary)
            if history.isEmpty {
                Text("No builds recorded.").foregroundStyle(.secondary)
            } else {
                ForEach(history) { record in
                    HStack(spacing: 10) {
                        Image(systemName: record.result.symbolName)
                            .foregroundStyle(colorForResult(record.result))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(record.buildType.rawValue) — \(record.result.rawValue)")
                                .font(.system(size: 13, weight: .medium))
                            HStack(spacing: 6) {
                                Text(record.startTime.formatted(date: .abbreviated, time: .shortened))
                                Text("·")
                                Text(record.durationDisplay)
                                Text("·")
                                Text("Recorded — not yet verification evidence")
                                    .foregroundStyle(.orange)
                            }
                            .font(.caption).foregroundStyle(.secondary)
                            if !record.notes.isEmpty {
                                Text(record.notes).font(.caption).lineLimit(2)
                            }
                        }
                        Spacer()
                        if record.result == .success {
                            Button("Promote to Evidence") {
                                promote(record, for: project.id)
                            }
                            .controlSize(.small)
                        }
                    }
                    .padding(10)
                    .background(Color(nsColor: .controlBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            }
        }
    }

    private func promote(_ record: BuildRecord, for projectID: UUID) {
        let evidence = EvidenceRecord(
            area: "Build",
            kind: .reproduction,
            summary: "\(record.buildType.rawValue) succeeded \(record.startTime.formatted(date: .abbreviated, time: .shortened))",
            body: record.notes.isEmpty ? "Build duration: \(record.durationDisplay)" : record.notes,
            classification: .observed
        )
        store.addEvidence(evidence, for: projectID)
    }

    private func colorForResult(_ r: BuildResult) -> Color {
        switch r {
        case .success: .green
        case .failure: .red
        case .warning: .orange
        case .cancelled: .secondary
        case .unknown: .gray
        }
    }
}

// MARK: - Utility Centre

struct UtilityCentreView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var results: [UtilityResult] = []
    @State private var path: String = ""
    @State private var section: UtilitySection = .security
    @State private var runningActions: Set<String> = []
    @State private var pendingMutation: PendingMutation?
    @State private var appCandidates: [String] = []
    @State private var showAppPicker = false
    @State private var includeBuildArtefacts = false
    @State private var largeFiles: [UtilityCentreEngine.LargeFileResult] = []

    enum UtilitySection: String, CaseIterable, Identifiable {
        case security = "Security"
        case build = "Build"
        case repo = "Repository"
        case environment = "Environment"
        var id: String { rawValue }
    }

    private struct PendingMutation: Identifiable {
        let id = UUID()
        let actionName: String
        let target: String
        let run: () async -> UtilityResult
    }

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .alert("Confirm \(pendingMutation?.actionName ?? "")",
               isPresented: Binding(get: { pendingMutation != nil }, set: { if !$0 { pendingMutation = nil } })) {
            Button("Cancel", role: .cancel) { pendingMutation = nil }
            Button("Run", role: .destructive) {
                if let p = pendingMutation {
                    executeAction(name: p.actionName, run: p.run)
                }
                pendingMutation = nil
            }
        } message: {
            Text("This is a mutating action and will modify files at:\n\(pendingMutation?.target ?? "")")
        }
        .sheet(isPresented: $showAppPicker) {
            AppBundlePicker(candidates: appCandidates) { selected in
                if let s = selected { path = s }
                showAppPicker = false
            }
        }
    }

    // MARK: - Sidebar / Layout

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Utility Centre").font(.headline).padding(.horizontal, 14).padding(.top, 14).padding(.bottom, 8)
            List(selection: $section) {
                ForEach(UtilitySection.allCases) { s in
                    Label(s.rawValue, systemImage: iconFor(s)).tag(s)
                }
            }
            .listStyle(.sidebar)
        }
        .frame(width: 200)
    }

    private func iconFor(_ s: UtilitySection) -> String {
        switch s {
        case .security: "lock.shield"
        case .build: "hammer"
        case .repo: "folder.badge.gearshape"
        case .environment: "gear"
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                modeBanner
                ExplanationCard(
                    title: "Utility Centre",
                    what: "Utility Centre runs local inspection tools for signing, quarantine, bundles, repository hygiene, build folders, and environment capture.",
                    why: "These checks explain why an app may not launch, sign, notarise, build, or behave consistently across machines.",
                    next: "Choose the correct target: use a `.app` bundle for signing/security tools and the project root for repository tools.",
                    safety: "Read-only mode blocks mutating actions. Remove Quarantine and Clean DerivedData require approval mode and a confirmation.",
                    symbol: "wrench.and.screwdriver",
                    tint: .blue
                )
                targetPanel
                actions
                resultsView
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Mode banner (read-only gating)

    private var modeBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: store.allowUtilityMutations ? "lock.open" : "lock.fill")
                .foregroundStyle(store.allowUtilityMutations ? Color.orange : Color.secondary)
            Text(store.allowUtilityMutations
                 ? "Approval mode ON — mutating actions (Remove Quarantine, Clean DerivedData) will prompt for confirmation."
                 : "Read-only mode — mutating actions are blocked.")
                .font(.caption)
            Spacer()
            Toggle("Allow mutations", isOn: $store.allowUtilityMutations)
                .toggleStyle(.switch)
                .controlSize(.mini)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    // MARK: - Target panel

    private var projectRootPath: String? {
        guard let pid = store.selectedProjectID,
              let p = store.projects.first(where: { $0.id == pid }) else { return nil }
        return p.rootURL.path
    }

    private var targetPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TARGET").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if let root = projectRootPath {
                HStack(spacing: 6) {
                    Image(systemName: "folder").foregroundStyle(.secondary)
                    Text("Project Root").font(.caption.weight(.semibold))
                    Text(root).font(.caption).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            HStack {
                TextField("Utility target path (.app for bundle/security tools)", text: $path)
                    .textFieldStyle(.roundedBorder)
                Button("Choose…") { chooseFile() }
                if projectRootPath != nil {
                    Button("Use Project Root") { path = projectRootPath ?? "" }
                    Button("Find App Bundles") { discoverAppBundles() }
                }
            }
            if !path.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: store.utilityCentre.isAppBundle(path) ? "app.fill" : "folder.fill")
                        .foregroundStyle(store.utilityCentre.isAppBundle(path) ? Color.green : Color.secondary)
                        .font(.caption2)
                    Text(store.utilityCentre.isAppBundle(path) ? "Selected target is a valid .app bundle" : "Selected target is a directory or file")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = true
        if panel.runModal() == .OK, let url = panel.url {
            path = url.path
        }
    }

    private func discoverAppBundles() {
        guard let root = projectRootPath else { return }
        let candidates = store.utilityCentre.findAppBundles(under: root)
        appCandidates = candidates
        if candidates.count == 1 {
            path = candidates[0]
        } else if candidates.isEmpty {
            results.insert(UtilityResult(
                title: "Find App Bundles",
                status: .info,
                output: "No .app bundles found under \(root). Build the project first.",
                target: root
            ), at: 0)
        } else {
            showAppPicker = true
        }
    }

    // MARK: - Actions

    @ViewBuilder
    private var actions: some View {
        switch section {
        case .security: securityActions
        case .build: buildActions
        case .repo: repoActions
        case .environment: envActions
        }
    }

    private var securityActions: some View {
        let actions: [(String, Bool, Bool, () async -> UtilityResult)] = [
            ("Quarantine Inspector", true, false, { await store.utilityCentre.runQuarantineInspector(path: path) }),
            ("Remove Quarantine", true, true, { await store.utilityCentre.runRemoveQuarantine(path: path) }),
            ("Gatekeeper Check", true, false, { await store.utilityCentre.runGatekeeperCheck(path: path) }),
            ("Signature Inspector", true, false, { await store.utilityCentre.runSignatureInspector(path: path) }),
            ("Signature Verification", true, false, { await store.utilityCentre.runSignatureVerification(path: path) }),
            ("Entitlement Viewer", true, false, { await store.utilityCentre.runEntitlements(path: path) }),
            ("Notarisation Check", true, false, { await store.utilityCentre.runNotarisationCheck(path: path) }),
        ]
        return actionGrid(actions)
    }

    private var buildActions: some View {
        let actions: [(String, Bool, Bool, () async -> UtilityResult)] = [
            ("DerivedData Size", false, false, { await store.utilityCentre.runDerivedDataSize() }),
            ("Clean DerivedData", false, true, { await store.utilityCentre.runCleanDerivedData() }),
            ("Bundle Inspector", true, false, { await store.utilityCentre.runBundleInspector(path: path) }),
        ]
        return actionGrid(actions)
    }

    private var repoActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            let actions: [(String, Bool, Bool, () async -> UtilityResult)] = [
                ("Git Health", true, false, { await store.utilityCentre.runGitHealth(repoRoot: path) }),
                ("Empty Folders", true, false, { await store.utilityCentre.runEmptyFolders(repoRoot: path, includeBuildAndCache: includeBuildArtefacts) }),
            ]
            actionGrid(actions)
            HStack {
                Toggle("Include build/cache folders", isOn: $includeBuildArtefacts).controlSize(.mini)
                Spacer()
                Button {
                    runLargeFiles()
                } label: {
                    HStack {
                        if runningActions.contains("Large Files") { ProgressView().controlSize(.mini) }
                        Image(systemName: "magnifyingglass").font(.caption)
                        Text("Large Files").font(.caption)
                    }
                }
                .buttonStyle(.bordered)
                .disabled(path.isEmpty || runningActions.contains("Large Files"))
            }
            if !largeFiles.isEmpty {
                largeFilesView
            }
        }
    }

    private var largeFilesView: some View {
        let grouped = Dictionary(grouping: largeFiles, by: \.group)
        return VStack(alignment: .leading, spacing: 6) {
            Text("LARGE FILES BY CATEGORY").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            ForEach(UtilityCentreEngine.LargeFileGroup.allCases, id: \.self) { group in
                if let entries = grouped[group], !entries.isEmpty {
                    DisclosureGroup("\(group.rawValue) (\(entries.count))") {
                        ForEach(Array(entries.prefix(20).enumerated()), id: \.offset) { _, entry in
                            HStack {
                                Text(URL(fileURLWithPath: entry.path).lastPathComponent).font(.caption).lineLimit(1)
                                Spacer()
                                Text(formatBytes(entry.sizeBytes)).font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                        if entries.count > 20 {
                            Text("… and \(entries.count - 20) more.").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .font(.caption)
                }
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func runLargeFiles() {
        guard !runningActions.contains("Large Files") else { return }
        runningActions.insert("Large Files")
        let target = path
        let include = includeBuildArtefacts
        Task {
            let (result, files) = await store.utilityCentre.runLargeFiles(repoRoot: target, includeBuildArtefacts: include)
            await MainActor.run {
                largeFiles = files
                appendResult(result)
                runningActions.remove("Large Files")
            }
        }
    }

    private var envActions: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                guard !runningActions.contains("Capture Environment") else { return }
                runningActions.insert("Capture Environment")
                Task {
                    let snap = await store.utilityCentre.captureEnvironment()
                    await MainActor.run {
                        if let pid = store.selectedProjectID {
                            store.addEnvironmentSnapshot(snap, for: pid)
                        }
                        appendResult(UtilityResult(
                            title: "Environment Captured",
                            status: .success,
                            output: "macOS \(snap.macOSVersion)\nXcode \(snap.xcodeVersion)\nSwift \(snap.swiftVersion)\nSDK \(snap.sdkVersion)",
                            interpretation: "Snapshot saved to the project's Environment Registry."
                        ))
                        runningActions.remove("Capture Environment")
                    }
                }
            } label: {
                HStack {
                    if runningActions.contains("Capture Environment") { ProgressView().controlSize(.mini) }
                    Text("Capture Environment Snapshot")
                }
            }
            .buttonStyle(.borderedProminent)

            if let pid = store.selectedProjectID {
                let envs = store.environments(for: pid)
                if !envs.isEmpty {
                    Text("RECENT SNAPSHOTS").font(.caption.weight(.semibold)).foregroundStyle(.secondary).padding(.top, 6)
                    ForEach(envs) { env in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(env.capturedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.system(size: 12, weight: .medium))
                            Text("macOS \(env.macOSVersion) · Swift \(env.swiftVersion.prefix(40))")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color(nsColor: .controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                    }
                }
            }
        }
    }

    private func actionGrid(_ actions: [(String, Bool, Bool, () async -> UtilityResult)]) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], spacing: 8) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, item in
                let (name, needsPath, isMutating, run) = item
                let blocked = isMutating && !store.allowUtilityMutations
                let isRunning = runningActions.contains(name)
                Button {
                    if isMutating {
                        pendingMutation = PendingMutation(actionName: name, target: path, run: run)
                    } else {
                        executeAction(name: name, run: run)
                    }
                } label: {
                    HStack {
                        if isRunning {
                            ProgressView().controlSize(.mini)
                        } else if isMutating {
                            Image(systemName: blocked ? "lock.fill" : "exclamationmark.triangle.fill")
                                .font(.caption2)
                                .foregroundStyle(blocked ? Color.secondary : Color.orange)
                        } else {
                            Image(systemName: "play.fill").font(.caption2)
                        }
                        Text(name).font(.caption).lineLimit(1)
                        if blocked {
                            Text("Requires Approval").font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled((needsPath && path.isEmpty) || blocked || isRunning)
                .help(blocked ? "Toggle Allow mutations to enable." : (needsPath && path.isEmpty ? "Set a Target Path first." : ""))
            }
        }
    }

    private func executeAction(name: String, run: @escaping () async -> UtilityResult) {
        guard !runningActions.contains(name) else { return }
        runningActions.insert(name)
        Task {
            let result = await run()
            await MainActor.run {
                appendResult(result)
                runningActions.remove(name)
            }
        }
    }

    private func appendResult(_ r: UtilityResult) {
        results.insert(r, at: 0)
        if results.count > 30 { results = Array(results.prefix(30)) }
    }

    private var resultsView: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RESULTS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if results.isEmpty {
                Text("Run a utility to see output here.").foregroundStyle(.secondary).font(.caption)
            } else {
                ForEach(results) { r in
                    UtilityResultCard(result: r)
                }
            }
        }
    }

    private func formatBytes(_ b: Int64) -> String {
        if b < 1024 { return "\(b) B" }
        if b < 1024 * 1024 { return String(format: "%.1f KB", Double(b) / 1024) }
        if b < 1024 * 1024 * 1024 { return String(format: "%.1f MB", Double(b) / 1_048_576) }
        return String(format: "%.2f GB", Double(b) / 1_073_741_824)
    }
}

private struct UtilityResultCard: View {
    var result: UtilityResult

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: result.status.symbolName).foregroundStyle(statusColor)
                Text(result.title).font(.system(size: 12, weight: .medium))
                Spacer()
                Text(result.status.rawValue).font(.caption2).foregroundStyle(statusColor)
                Text(result.generatedAt.formatted(date: .omitted, time: .shortened))
                    .font(.caption2).foregroundStyle(.secondary)
            }
            if !result.interpretation.isEmpty {
                Text(result.interpretation).font(.caption).foregroundStyle(.primary)
            }
            if !result.target.isEmpty {
                HStack(spacing: 4) {
                    Image(systemName: "scope").font(.caption2).foregroundStyle(.secondary)
                    Text(result.target).font(.caption2).foregroundStyle(.secondary).lineLimit(1).truncationMode(.middle)
                }
            }
            Text(result.output)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.black.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            if !result.nextAction.isEmpty {
                Text("Next: \(result.nextAction)").font(.caption2).foregroundStyle(.secondary)
            }
            if !result.command.isEmpty {
                Text(result.command).font(.system(size: 10, design: .monospaced)).foregroundStyle(.tertiary)
            }
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var statusColor: Color {
        switch result.status {
        case .success: .green
        case .info: .blue
        case .warning: .orange
        case .failure: .red
        case .targetError: .orange
        case .timeout: .orange
        case .blocked: .secondary
        }
    }
}

private struct AppBundlePicker: View {
    var candidates: [String]
    var onSelect: (String?) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Select App Bundle").font(.headline)
            Text("Multiple .app bundles were found under the project root. Newest first.")
                .font(.caption).foregroundStyle(.secondary)
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(candidates, id: \.self) { c in
                        Button {
                            onSelect(c)
                        } label: {
                            HStack {
                                Image(systemName: "app.fill").foregroundStyle(.blue)
                                Text(c).font(.system(size: 12)).lineLimit(1).truncationMode(.middle)
                                Spacer()
                            }
                            .padding(8)
                            .background(Color(nsColor: .controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(minWidth: 500, minHeight: 200, maxHeight: 320)
            HStack {
                Spacer()
                Button("Cancel") { onSelect(nil) }
            }
        }
        .padding(16)
    }
}

// MARK: - Project Review Mode

struct ProjectReviewView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var session: ProjectReviewSession?
    @State private var lastResult: String?

    var body: some View {
        if let project = store.selectedProject {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(project: project)
                    if let session = session {
                        questionsCard(session: session, project: project)
                    } else {
                        startCard(project: project)
                    }
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView("No project selected", systemImage: "checklist",
                description: Text("Select a project to start a review."))
        }
    }

    private func header(project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Project Review").font(.system(size: 28, weight: .bold))
            Text(project.name).foregroundStyle(.secondary)
        }
    }

    private func startCard(project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Run through a structured review: what changed, what failed, what is verified, what risks/decisions/assumptions are new, and whether the project is release-ready. Your answers become journal entries.")
                .foregroundStyle(.secondary)
            if let lastResult {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(lastResult).font(.caption)
                }
                .padding(.vertical, 4)
            }
            Button("Start Review") {
                lastResult = nil
                session = store.startProjectReview(for: project.id)
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func questionsCard(session: ProjectReviewSession, project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(Array(session.questions.enumerated()), id: \.element.id) { idx, q in
                VStack(alignment: .leading, spacing: 4) {
                    Text(q.question).font(.system(size: 13, weight: .semibold))
                    TextEditor(text: Binding(
                        get: { self.session?.questions[idx].answer ?? "" },
                        set: { newValue in
                            self.session?.questions[idx].answer = newValue
                            self.session?.questions[idx].isAnswered = !newValue.isEmpty
                        }
                    ))
                    .font(.system(size: 12))
                    .frame(minHeight: 50, maxHeight: 80)
                    .padding(4)
                    .background(Color(nsColor: .textBackgroundColor))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .padding(10)
                .background(Color(nsColor: .controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            HStack {
                Button("Cancel", role: .cancel) { self.session = nil }
                Spacer()
                Button("Complete Review") {
                    if let s = self.session {
                        let count = store.completeProjectReview(s)
                        lastResult = "Review completed — \(count) answer(s) journaled."
                    }
                    self.session = nil
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
}

// MARK: - Favourites Sidebar Section (shared component)

struct FavouriteToggleButton: View {
    @ObservedObject var store: WorkspaceStore
    var projectID: UUID

    var body: some View {
        Button {
            store.toggleFavourite(projectID)
        } label: {
            Image(systemName: store.isFavourited(projectID) ? "star.fill" : "star")
                .foregroundStyle(store.isFavourited(projectID) ? Color.yellow : Color.secondary)
        }
        .buttonStyle(.plain)
        .help(store.isFavourited(projectID) ? "Unfavourite" : "Favourite")
    }
}
