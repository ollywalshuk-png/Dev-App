import AppKit
import LocalForgeCore
import SwiftUI

/// The Handoff module. Generates Codex/Claude prompts, fix proposals, and a
/// comprehensive handoff pack — all locally, from the project's real state.
/// Every artefact and every handoff section has its own copy button.
struct HandoffView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var selectedArtefact: PromptForgeEngine.Artefact = .comprehensiveHandoff

    private let engine = PromptForgeEngine()

    var body: some View {
        if let project = store.selectedProject, let snapshot = store.selectedSnapshot {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(project: project, snapshot: snapshot)
                    picker
                    blurb
                    artefactPreview(snapshot: snapshot, project: project)
                    if selectedArtefact == .comprehensiveHandoff {
                        sectionPack(snapshot: snapshot)
                    }
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView(
                "No project to hand off",
                systemImage: "paperplane",
                description: Text("Open a project so LocalForge can synthesise a handoff from its real state.")
            )
        }
    }

    // MARK: - Header & controls

    private func header(project: ProjectContext, snapshot: RepoSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Handoff — \(project.name)")
                .font(.system(size: 30, weight: .bold))
            Text("Local synthesis from this project's real state. Nothing leaves your machine.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Tag(text: snapshot.identity.kind.rawValue, color: snapshot.identity.kind.tint)
                Tag(text: "Reality \(snapshot.reality.score)%", color: realityColor(snapshot.reality.score))
                Tag(text: "\(snapshot.verificationSummary.verified) verified / \(snapshot.verificationSummary.total) tracked", color: .green)
                if snapshot.verificationSummary.failed > 0 {
                    Tag(text: "\(snapshot.verificationSummary.failed) failed", color: .red)
                }
            }
        }
    }

    private var picker: some View {
        Picker("Artefact", selection: $selectedArtefact) {
            ForEach(PromptForgeEngine.Artefact.allCases, id: \.self) { artefact in
                Label(artefact.rawValue, systemImage: artefact.symbolName).tag(artefact)
            }
        }
        .pickerStyle(.segmented)
    }

    private var blurb: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: selectedArtefact.symbolName)
                .foregroundStyle(.blue)
                .font(.title3)
                .frame(width: 24)
            Text(selectedArtefact.blurb)
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Preview & per-section pack

    private func artefactPreview(snapshot: RepoSnapshot, project: ProjectContext) -> some View {
        let text = engine.generate(selectedArtefact, snapshot: snapshot, knowledge: store.knowledgeNotes(for: project.id), evidence: store.evidence(for: project.id), risks: store.risks(for: project.id), decisions: store.decisions(for: project.id), architecture: store.architecture(for: project.id), assumptions: store.assumptions(for: project.id))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(selectedArtefact.rawValue)
                    .font(.title3.weight(.semibold))
                Spacer()
                Text("\(text.count) chars · \(wordCount(text)) words")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Button {
                    copy(text)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderedProminent)
            }
            ScrollView {
                Text(text)
                    .font(.system(.body, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
            }
            .frame(minHeight: 280, maxHeight: 480)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func sectionPack(snapshot: RepoSnapshot) -> some View {
        let pid = store.selectedProjectID ?? UUID()
        let sections = engine.handoffSections(snapshot: snapshot, knowledge: store.knowledgeNotes(for: pid), evidence: store.evidence(for: pid), risks: store.risks(for: pid), decisions: store.decisions(for: pid), architecture: store.architecture(for: pid), assumptions: store.assumptions(for: pid))
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Section Pack — copy any single section")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    let all = sections.map { "## \($0.title)\n\($0.body)" }.joined(separator: "\n\n")
                    copy(all)
                } label: {
                    Label("Copy All Sections", systemImage: "square.on.square")
                }
            }
            ForEach(sections) { section in
                HandoffSectionCard(section: section, onCopy: { copy($0) })
            }
        }
    }

    // MARK: - Helpers

    private func copy(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private func realityColor(_ score: Int) -> Color {
        switch score {
        case 70...: .green
        case 45..<70: .yellow
        default: .orange
        }
    }
}

private struct HandoffSectionCard: View {
    var section: HandoffSection
    var onCopy: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(section.title)
                    .font(.headline)
                Spacer()
                Button {
                    onCopy(section.body)
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                .buttonStyle(.borderless)
            }
            Text(section.body)
                .font(.system(.callout, design: .monospaced))
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct Tag: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
