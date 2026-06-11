import LocalForgeCore
import SwiftUI

struct ContentView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        ZStack {
            DiagnosticRainBackground(
                isEnabled: store.themePreferences.animatedDiagnosticBackground,
                intensity: store.themePreferences.diagnosticBackgroundIntensity,
                density: store.themePreferences.diagnosticBackgroundDensity,
                motion: store.themePreferences.diagnosticBackgroundMotion,
                reduceWhenInactive: store.themePreferences.reduceDiagnosticBackgroundWhenInactive
            )
            .ignoresSafeArea()

            NavigationSplitView {
                SidebarView(store: store)
            } content: {
                MainWorkspaceView(store: store)
            } detail: {
                GuardianPanel(store: store)
            }
            .sheet(item: setupProjectBinding) { project in
                if let snapshot = store.snapshots[project.id] {
                    ProjectSetupWizardView(
                        project: project,
                        snapshot: snapshot,
                        onSave: { draft in store.applySetup(draft, for: project.id) },
                        onCancel: { store.setupProjectID = nil }
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .primaryAction) {
                    Button {
                        store.showCommandPalette = true
                    } label: {
                        Label("Command Palette", systemImage: "command")
                    }
                    .keyboardShortcut("k", modifiers: .command)
                    .help("Open command palette (⌘K)")

                    Picker("Scan Mode", selection: $store.scanMode) {
                        ForEach(ScanMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 480)

                    Button {
                        store.openRepositoryPanel()
                    } label: {
                        Label("Open Repository", systemImage: "folder.badge.plus")
                    }

                    Button {
                        Task { await store.rescanSelectedProject() }
                    } label: {
                        Label("Rescan", systemImage: "arrow.clockwise")
                    }
                    .disabled(store.selectedProject == nil || store.isScanning)
                }
            }

            if store.showCommandPalette {
                Color.black.opacity(0.25)
                    .ignoresSafeArea()
                    .onTapGesture { store.showCommandPalette = false }
                CommandPaletteView(store: store, isPresented: $store.showCommandPalette)
            }
        }
    }

    private var setupProjectBinding: Binding<ProjectContext?> {
        Binding(
            get: {
                guard let id = store.setupProjectID else { return nil }
                return store.projects.first { $0.id == id }
            },
            set: { value in
                store.setupProjectID = value?.id
            }
        )
    }
}
