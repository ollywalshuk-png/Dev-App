import LocalForgeCore
import SwiftUI

struct SidebarView: View {
    @ObservedObject var store: WorkspaceStore
    @AppStorage("LocalForge.ShowFoundationStubs") private var showStubs = false

    private var coreModules: [WorkspaceModule] {
        [.workspace, .search, .projects, .mission, .verification, .releaseReadiness,
         .timeline, .journal, .truthCentre, .registers, .knowledgeVault, .reports, .handoff]
    }

    private var operationsModules: [WorkspaceModule] {
        [.workspaceHealth, .workspaceDoctor, .savedViews, .projectReview,
         .buildHistory, .devTools, .recommendations, .testRegistry, .environmentRegistry, .backupCentre, .utilityCentre]
    }

    private var systemModules: [WorkspaceModule] {
        [.cli, .settings]
    }

    var body: some View {
        List(selection: $store.selectedModule) {
            Section("Command Centre") {
                ForEach(coreModules) { module in
                    Label(module.rawValue, systemImage: module.symbolName)
                        .font(.body.weight(.medium))
                        .tag(module)
                }
            }

            Section("Operations") {
                ForEach(operationsModules) { module in
                    Label(module.rawValue, systemImage: module.symbolName)
                        .tag(module)
                }
            }

            Section("System") {
                ForEach(systemModules) { module in
                    Label(module.rawValue, systemImage: module.symbolName)
                        .tag(module)
                }
            }

            let favourites = store.projects.filter { store.isFavourited($0.id) }
            if !favourites.isEmpty {
                Section("Favourites") {
                    ForEach(favourites) { project in
                        Button {
                            store.selectProject(project)
                        } label: {
                            HStack {
                                ProjectSidebarRow(project: project, snapshot: store.snapshots[project.id])
                                Spacer()
                                FavouriteToggleButton(store: store, projectID: project.id)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            if !store.projects.isEmpty {
                Section("Projects") {
                    ForEach(store.projects) { project in
                        Button {
                            store.selectProject(project)
                        } label: {
                            HStack {
                                ProjectSidebarRow(
                                    project: project,
                                    snapshot: store.snapshots[project.id]
                                )
                                Spacer()
                                FavouriteToggleButton(store: store, projectID: project.id)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Section {
                Toggle("Show foundation stubs", isOn: $showStubs)
                    .font(.caption)
                if showStubs {
                    ForEach(WorkspaceModule.allCases.filter { !$0.isImplemented }) { module in
                        Label(module.rawValue, systemImage: module.symbolName)
                            .foregroundStyle(.secondary)
                            .tag(module)
                    }
                }
            } header: {
                Text("Deferred (Phase 6+)")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("LocalForge")
    }
}

private struct ProjectSidebarRow: View {
    var project: ProjectContext
    var snapshot: RepoSnapshot?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: (snapshot?.identity.kind ?? .unidentified).symbolName)
                .foregroundStyle((snapshot?.identity.kind ?? .unidentified).tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(ProjectHealth.resolve(project: project, snapshot: snapshot).color)
                        .frame(width: 7, height: 7)
                    Text(project.name)
                        .lineLimit(1)
                }
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    private var subtitle: String {
        if project.bookmarkStatus.requiresAttention { return project.bookmarkStatus.displayName }
        guard let snapshot else { return "Not scanned" }
        var parts = [snapshot.identity.kind.shortLabel]
        if snapshot.git.isRepository { parts.append(snapshot.git.branchDisplay) }
        parts.append("\(snapshot.summary.totalFiles) files")
        return parts.joined(separator: " · ")
    }
}
