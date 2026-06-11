import LocalForgeCore
import SwiftUI

struct MainWorkspaceView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        VStack(spacing: 0) {
            ProjectTabStrip(store: store)
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HeaderView(store: store)
                    moduleContent
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .navigationTitle(store.selectedModule.rawValue)
    }

    @ViewBuilder
    private var moduleContent: some View {
        switch store.selectedModule {
        case .workspace:
            WorkspaceDashboard(store: store)
        case .search:
            SearchView(store: store)
        case .timeline:
            TimelineView(store: store)
        case .projects:
            ProjectDetailView(store: store)
        case .verification:
            VerificationView(store: store)
        case .releaseReadiness:
            ReleaseReadinessView(store: store)
        case .mission:
            MissionModuleView(store: store)
        case .journal:
            JournalView(store: store)
        case .truthCentre:
            TruthCentreView(store: store)
        case .registers:
            RegistersView(store: store)
        case .knowledgeVault:
            KnowledgeVaultView(store: store)
        case .reports:
            ReportView(store: store)
        case .handoff:
            HandoffView(store: store)
        case .cli:
            CLIView()
        case .settings:
            SettingsView(store: store)
        case .workspaceHealth:
            WorkspaceHealthView(store: store)
        case .workspaceDoctor:
            WorkspaceDoctorView(store: store)
        case .backupCentre:
            BackupCentreView(store: store)
        case .utilityCentre:
            UtilityCentreView(store: store)
        case .buildHistory:
            BuildHistoryView(store: store)
        case .devTools:
            DevToolsView(store: store)
        case .recommendations:
            RecommendationsView(store: store)
        case .testRegistry:
            TestRegistryView(store: store)
        case .environmentRegistry:
            EnvironmentRegistryView(store: store)
        case .projectReview:
            ProjectReviewView(store: store)
        case .savedViews:
            SavedViewsView(store: store)
        default:
            EngineFoundationView(module: store.selectedModule)
        }
    }
}

private struct HeaderView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 6) {
                Text(store.selectedModule.rawValue)
                    .font(.largeTitle.weight(.semibold))
                Text(store.statusMessage)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label(store.isScanning ? "Scanning" : "Read-only", systemImage: store.isScanning ? "waveform.path.ecg" : "eye")
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.quaternary, in: Capsule())
        }
    }
}

private struct ProjectTabStrip: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if store.projects.isEmpty {
                    Text("No projects open")
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                } else {
                    ForEach(store.projects) { project in
                        let snapshot = store.snapshots[project.id]
                        let kind = snapshot?.identity.kind ?? .unidentified
                        Button {
                            store.selectProject(project)
                        } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(ProjectHealth.resolve(project: project, snapshot: snapshot).color)
                                    .frame(width: 8, height: 8)
                                Image(systemName: kind.symbolName)
                                    .foregroundStyle(kind.tint)
                                Text(project.name)
                                    .lineLimit(1)
                                if let snapshot {
                                    Text("\(snapshot.findings.count)")
                                        .font(.caption2.weight(.bold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(project.id == store.selectedProjectID ? Color.accentColor.opacity(0.28) : Color.secondary.opacity(0.12))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
    }
}
