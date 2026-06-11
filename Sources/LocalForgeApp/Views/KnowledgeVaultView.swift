import LocalForgeCore
import SwiftUI

struct KnowledgeVaultView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var title = ""
    @State private var bodyText = ""
    @State private var kind: KnowledgeNoteKind = .knownIssue
    @State private var author = NSFullUserName()

    var body: some View {
        if let project = store.selectedProject {
            VStack(alignment: .leading, spacing: 16) {
                header(project)
                ExplanationCard(
                    title: "Knowledge Vault",
                    what: "Knowledge Vault is the local project notebook for decisions, known issues, architecture notes, release notes, and lessons learned.",
                    why: "It preserves project context between sessions and handoffs, and known issues can inform Reality and release risk.",
                    next: "Record decisions as they are made and add known issues when something is not yet fixed or verified.",
                    safety: "Notes are stored in LocalForge workspace data on this Mac. Saving a note does not edit the repository.",
                    example: "Example: Preset persistence fails after Logic restart, or release requires Developer ID notarisation.",
                    symbol: "archivebox",
                    tint: .purple
                )
                composer(project)
                notes(project)
            }
        } else {
            ContentUnavailableView("Open a project", systemImage: "archivebox", description: Text("Select a project to keep local notes, issues, decisions, and lessons."))
        }
    }

    private func header(_ project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Knowledge Vault — \(project.name)")
                .font(.title2.weight(.semibold))
            Text("A local project notebook. These notes feed known issues into Reality; they do not leave this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func composer(_ project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Add Note")
                .font(.headline)
            TextField("Title", text: $title)
                .textFieldStyle(.roundedBorder)
            Picker("Kind", selection: $kind) {
                ForEach(KnowledgeNoteKind.allCases, id: \.self) { kind in
                    Text(kind.rawValue).tag(kind)
                }
            }
            TextField("Author", text: $author)
                .textFieldStyle(.roundedBorder)
            TextEditor(text: $bodyText)
                .frame(minHeight: 90)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            Button {
                store.addKnowledgeNote(
                    KnowledgeNote(title: title, body: bodyText, kind: kind, author: author),
                    for: project.id
                )
                title = ""
                bodyText = ""
            } label: {
                Label("Save Note", systemImage: "plus")
            }
            .disabled(title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && bodyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func notes(_ project: ProjectContext) -> some View {
        let notes = store.knowledgeNotes(for: project.id)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Notes")
                .font(.headline)
            if notes.isEmpty {
                Text("No project knowledge recorded yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(notes) { note in
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(note.title.isEmpty ? note.kind.rawValue : note.title)
                                .font(.headline)
                            Spacer()
                            Text(note.kind.rawValue)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(.quaternary, in: Capsule())
                        }
                        if !note.body.isEmpty {
                            Text(note.body)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(note.author.isEmpty ? "Unknown" : note.author) · \(note.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    .padding()
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
