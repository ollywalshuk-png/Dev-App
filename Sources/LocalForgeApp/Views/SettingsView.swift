import AppKit
import LocalForgeCore
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var confirmingImport = false
    @State private var pendingImportData: Data?

    var body: some View {
        Form {
            Section("Settings Guide") {
                ExplanationCard(
                    title: "Settings",
                    what: "Settings control LocalForge appearance, diagnostic background behaviour, scan policy, workspace import/export, and privacy defaults.",
                    why: "These preferences make the app readable and predictable without changing the project source code.",
                    next: "Choose the diagnostic background level you can read comfortably, keep heavy scans manual, and export workspace data before replacing it.",
                    safety: "Settings persist locally. Importing workspace data requires confirmation because it replaces LocalForge's saved workspace metadata.",
                    example: "Example: disable the code background for maximum contrast, or reduce motion for a static field.",
                    symbol: "gearshape",
                    tint: .gray
                )
            }

            Section("Appearance") {
                Picker("Appearance", selection: $store.themePreferences.appearance) {
                    ForEach(ThemeAppearance.allCases, id: \.self) { appearance in
                        Text(appearance.rawValue).tag(appearance)
                    }
                }

                TextField("Accent", text: $store.themePreferences.accentName)

                Slider(value: $store.themePreferences.brightnessAdjustment, in: -20...20) {
                    Text("Brightness offset")
                }
                Text("Appearance preferences are local and persist with the workspace. Brightness is a reserved visual offset for this V1 shell.")
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostic Background") {
                Toggle("Structured code background", isOn: $store.themePreferences.animatedDiagnosticBackground)
                Picker("Intensity", selection: $store.themePreferences.diagnosticBackgroundIntensity) {
                    ForEach(DiagnosticBackgroundIntensity.allCases, id: \.self) { intensity in
                        Text(intensity.rawValue).tag(intensity)
                    }
                }
                Picker("Density", selection: $store.themePreferences.diagnosticBackgroundDensity) {
                    ForEach(DiagnosticBackgroundDensity.allCases, id: \.self) { density in
                        Text(density.rawValue).tag(density)
                    }
                }
                Picker("Motion", selection: $store.themePreferences.diagnosticBackgroundMotion) {
                    ForEach(DiagnosticBackgroundMotion.allCases, id: \.self) { motion in
                        Text(motion.rawValue).tag(motion)
                    }
                }
                Toggle("Reduce when inactive", isOn: $store.themePreferences.reduceDiagnosticBackgroundWhenInactive)
                Text("Local visual preference only. The background is a fixed-grid on-device Canvas layer; it never scans, uploads, monitors, or modifies project data. Reduce Motion freezes the field.")
                    .foregroundStyle(.secondary)
            }

            Section("Safety") {
                Label("Read-only by default", systemImage: "eye")
                Label("Mutating utilities require explicit approval", systemImage: "lock.shield")
                Label("No telemetry, cloud AI, hosted backend, or source upload", systemImage: "network.slash")
            }

            Section("Scan Policy") {
                Picker("Mode", selection: $store.scanMode) {
                    ForEach(ScanMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                Text("Heavy scans are manual. Aggressive mode should be temporary and explicit.")
                    .foregroundStyle(.secondary)
            }

            Section("Workspace Data") {
                HStack {
                    Button {
                        exportWorkspace()
                    } label: {
                        Label("Export Workspace…", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        chooseImportFile()
                    } label: {
                        Label("Import Workspace…", systemImage: "square.and.arrow.down")
                    }
                }
                Text("Export writes the entire workspace (missions, verification, evidence, registers, journal) as JSON — a local backup you control. Import replaces the current workspace from such a file.")
                    .foregroundStyle(.secondary)
            }

            Section("Diagnostics") {
                Label("Runtime validation checklist: Docs/26_Runtime_Validation_Checklist.md", systemImage: "checklist")
                    .textSelection(.enabled)
                Label("Launch logs: ./script/build_and_run.sh --logs", systemImage: "terminal")
                    .textSelection(.enabled)
            }

            Section("Privacy") {
                Label("Read-only analysis in V1", systemImage: "eye")
                Label("No telemetry by default", systemImage: "checkmark.circle")
                Label("No cloud AI by default", systemImage: "checkmark.circle")
                Label("No source upload by default", systemImage: "checkmark.circle")
                Label("Optional integrations are disabled in V1", systemImage: "power.circle")
            }
        }
        .padding()
        .frame(width: 520)
        .confirmationDialog(
            "Replace the current workspace?",
            isPresented: $confirmingImport
        ) {
            Button("Replace Workspace", role: .destructive) {
                if let data = pendingImportData {
                    _ = store.importWorkspace(from: data)
                }
                pendingImportData = nil
            }
            Button("Cancel", role: .cancel) { pendingImportData = nil }
        } message: {
            Text("Importing replaces every project, mission, verification record, and register with the file's contents. Export a backup first if unsure.")
        }
    }

    private func exportWorkspace() {
        guard let data = store.exportWorkspaceJSON() else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "LocalForge-Workspace.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        try? data.write(to: url)
    }

    private func chooseImportFile() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url,
              let data = try? Data(contentsOf: url) else { return }
        pendingImportData = data
        confirmingImport = true
    }
}
