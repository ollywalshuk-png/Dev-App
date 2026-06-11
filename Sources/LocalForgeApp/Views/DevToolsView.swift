import AppKit
import LocalForgeCore
import SwiftUI

struct DevToolsView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var appBundlePath = ""
    @State private var running: DevToolsCommandKind?
    @State private var results: [DevToolsCommandResult] = []

    private let engine = DevCommandEngine()

    var body: some View {
        guard let project = store.selectedProject else {
            return AnyView(ContentUnavailableView(
                "No project selected",
                systemImage: "terminal",
                description: Text("Select a project before running development commands.")
            ))
        }

        let commands = engine.presets(projectRoot: project.rootURL.path, appBundlePath: appBundlePath.isEmpty ? nil : appBundlePath)
        return AnyView(VStack(alignment: .leading, spacing: 16) {
            header(project)
            ExplanationCard(
                title: "Dev Tools",
                what: "Dev Tools runs approved local presets such as build, test, Git status, signing checks, and environment capture.",
                why: "The output becomes evidence, so build and test work can support verification without using a free-form terminal.",
                next: "Run Swift Build or Swift Test, then review the created build, test, and evidence records.",
                safety: "Preset-only. No shell strings, no automatic fixes, no commits, no pushes, no deletes, and no background polling.",
                example: "Swift Test creates a BuildRecord, TestRecord, and EvidenceRecord. It still does not automatically mark verification as passed.",
                symbol: "terminal",
                tint: .teal
            )
            targetPanel(project)
            commandGrid(commands, project: project)
            resultsPanel
        })
    }

    private func header(_ project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(project.name)
                .font(.title2.weight(.semibold))
            Label("Preset-only, project-scoped Dev Tools. Output is local and can be captured as evidence; no source files are edited by LocalForge.", systemImage: "lock.shield")
                .foregroundStyle(.secondary)
        }
    }

    private func targetPanel(_ project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("TARGETS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            HStack {
                Label(project.rootURL.path, systemImage: "folder")
                    .font(.caption)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Spacer()
            }
            HStack {
                TextField("Optional .app bundle for codesign/Gatekeeper", text: $appBundlePath)
                    .textFieldStyle(.roundedBorder)
                Button("Find App") {
                    let candidates = store.utilityCentre.findAppBundles(under: project.rootURL.path)
                    if let first = candidates.first {
                        appBundlePath = first
                    } else {
                        store.statusMessage = "No .app bundle found under selected project."
                    }
                }
                Button("Choose...") {
                    chooseBundle()
                }
            }
        }
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func commandGrid(_ commands: [DevToolsCommand], project: ProjectContext) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
            ForEach(commands) { command in
                DevCommandCard(
                    command: command,
                    isRunning: running == command.kind,
                    isDisabled: running != nil || (command.requiresAppBundle && appBundlePath.isEmpty),
                    onRun: { run(command, project: project) }
                )
            }
        }
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("RESULTS").font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            if results.isEmpty {
                ContentUnavailableView(
                    "No commands run",
                    systemImage: "terminal",
                    description: Text("Run a preset to capture local output into build, test, evidence, or environment records.")
                )
            } else {
                ForEach(results) { result in
                    DevCommandResultCard(result: result)
                }
            }
        }
    }

    private func chooseBundle() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            appBundlePath = url.path
        }
    }

    private func run(_ command: DevToolsCommand, project: ProjectContext) {
        guard running == nil else { return }
        running = command.kind

        Task {
            let result: DevToolsCommandResult
            if command.kind == .environmentCapture {
                let started = Date()
                let snapshot = await store.utilityCentre.captureEnvironment()
                result = DevToolsCommandResult(
                    command: command,
                    status: .success,
                    output: snapshot.summaryLines.joined(separator: "\n"),
                    startedAt: started
                )
                await MainActor.run {
                    store.addEnvironmentSnapshot(snapshot, for: project.id)
                }
            } else {
                result = await engine.run(command, projectRoot: project.rootURL.path)
            }

            await MainActor.run {
                capture(result, projectID: project.id)
                results.insert(result, at: 0)
                if results.count > 20 { results = Array(results.prefix(20)) }
                running = nil
            }
        }
    }

    private func capture(_ result: DevToolsCommandResult, projectID: UUID) {
        let evidence = EvidenceRecord(
            area: result.command.verificationArea,
            kind: result.command.kind == .environmentCapture ? .environment : .logExcerpt,
            summary: "\(result.command.title): \(result.status.rawValue)",
            body: result.output,
            classification: result.status == .success ? .observed : .unknown
        )
        store.addEvidence(evidence, for: projectID)

        switch result.command.kind {
        case .swiftBuild:
            store.addBuildRecord(
                BuildRecord(
                    buildType: .swiftBuild,
                    startTime: result.startedAt,
                    endTime: result.endedAt,
                    result: result.status.buildResult,
                    notes: result.output,
                    linkedEvidenceIDs: [evidence.id],
                    linkedVerificationAreas: ["Build"]
                ),
                for: projectID
            )
        case .swiftTest:
            store.addBuildRecord(
                BuildRecord(
                    buildType: .swiftTest,
                    startTime: result.startedAt,
                    endTime: result.endedAt,
                    result: result.status.buildResult,
                    notes: result.output,
                    linkedEvidenceIDs: [evidence.id],
                    linkedVerificationAreas: ["Tests"]
                ),
                for: projectID
            )
            store.addTestRecord(
                TestRecord(
                    name: "swift test",
                    kind: .automated,
                    outcome: result.status.testOutcome,
                    linkedVerificationArea: "Tests",
                    notes: result.output,
                    author: NSFullUserName()
                ),
                for: projectID
            )
        case .gitStatus, .codesignVerify, .gatekeeperCheck, .environmentCapture:
            break
        }

        store.statusMessage = "\(result.command.title) \(result.status.rawValue.lowercased())."
    }
}

private struct DevCommandCard: View {
    var command: DevToolsCommand
    var isRunning: Bool
    var isDisabled: Bool
    var onRun: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(command.title, systemImage: icon)
                    .font(.headline)
                Spacer()
                Text(command.risk.rawValue)
                    .font(.caption2.weight(.semibold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(riskColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(riskColor)
            }
            Text(command.detail)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text(command.displayCommand.isEmpty ? "Captured through LocalForge environment tools" : command.displayCommand)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .truncationMode(.middle)
            Button {
                onRun()
            } label: {
                HStack {
                    if isRunning { ProgressView().controlSize(.mini) }
                    Text(isRunning ? "Running" : "Run")
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(isDisabled)
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var icon: String {
        switch command.kind {
        case .swiftBuild: "hammer"
        case .swiftTest: "testtube.2"
        case .gitStatus: "point.3.connected.trianglepath.dotted"
        case .codesignVerify: "signature"
        case .gatekeeperCheck: "lock.shield"
        case .environmentCapture: "desktopcomputer"
        }
    }

    private var riskColor: Color {
        switch command.risk {
        case .readOnly: .green
        case .buildWrites: .orange
        case .externalAssessment: .blue
        }
    }
}

private struct DevCommandResultCard: View {
    var result: DevToolsCommandResult

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label(result.command.title, systemImage: statusIcon)
                    .foregroundStyle(statusColor)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(result.durationDisplay)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(result.status.rawValue)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor)
            }
            Text(result.output.isEmpty ? "(no output)" : result.output)
                .font(.system(size: 11, design: .monospaced))
                .textSelection(.enabled)
                .lineLimit(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(8)
                .background(Color.black.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 8))
    }

    private var statusIcon: String {
        switch result.status {
        case .success: "checkmark.circle.fill"
        case .failure: "xmark.circle.fill"
        case .blocked: "hand.raised.fill"
        case .timeout: "clock.badge.exclamationmark"
        }
    }

    private var statusColor: Color {
        switch result.status {
        case .success: .green
        case .failure: .red
        case .blocked: .orange
        case .timeout: .orange
        }
    }
}
