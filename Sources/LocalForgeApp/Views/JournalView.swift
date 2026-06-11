import AppKit
import LocalForgeCore
import SwiftUI

/// The Project Journal — append-only timeline of meaningful events. Automatic
/// entries arrive from verification changes, mission edits, knowledge notes,
/// and setup; the developer can also write free-form notes.
struct JournalView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var draftSummary = ""
    @State private var draftDetail = ""
    @State private var draftAuthor = ""

    private let engine = JournalEngine()

    var body: some View {
        if let project = store.selectedProject {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(project: project)
                    composer(projectID: project.id)
                    timeline(projectID: project.id)
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView(
                "No active project",
                systemImage: "book.pages",
                description: Text("Open a project to start its journal — institutional memory across sessions.")
            )
        }
    }

    private func header(project: ProjectContext) -> some View {
        let entries = store.journal(for: project.id)
        return VStack(alignment: .leading, spacing: 6) {
            Text("Project Journal — \(project.name)")
                .font(.system(size: 30, weight: .bold))
            Text("Append-only timeline of what happened on this project, and why. When you (or an agent) come back later, the journal already knows.")
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                Tag(text: "\(entries.count) entries", color: .blue)
                if let last = entries.first {
                    Tag(text: "Last: \(formatted(last.occurredAt))", color: .gray)
                }
                Button {
                    copyMarkdown(entries: entries, project: project)
                } label: {
                    Label("Copy Journal (Markdown)", systemImage: "doc.on.doc")
                }
                .controlSize(.small)
            }
        }
    }

    private func composer(projectID: UUID) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Entry")
                .font(.title3.weight(.semibold))
            TextField("Summary (e.g. 'Investigated AUState handling')", text: $draftSummary)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 15))
            TextEditor(text: $draftDetail)
                .font(.system(size: 14))
                .frame(minHeight: 70)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
            HStack {
                TextField("Author", text: $draftAuthor)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 220)
                Spacer()
                Button("Add to Journal") {
                    let summary = draftSummary.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !summary.isEmpty else { return }
                    let entry = JournalEntry(
                        kind: .note,
                        summary: summary,
                        detail: draftDetail.trimmingCharacters(in: .whitespacesAndNewlines),
                        author: draftAuthor.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    store.addJournalEntry(entry, for: projectID)
                    draftSummary = ""
                    draftDetail = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func timeline(projectID: UUID) -> some View {
        let entries = store.journal(for: projectID)
        let grouped = engine.grouped(entries)
        return VStack(alignment: .leading, spacing: 14) {
            Text("Timeline")
                .font(.title3.weight(.semibold))
            if grouped.isEmpty {
                Text("No entries yet. The journal will auto-populate as you change verification, edit mission, or add knowledge notes.")
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(grouped, id: \.day) { bucket in
                    DayBucketView(day: bucket.day, entries: bucket.entries)
                }
            }
        }
    }

    private func copyMarkdown(entries: [JournalEntry], project: ProjectContext) {
        let body = entries.map { entry -> String in
            let date = entry.occurredAt.formatted(date: .abbreviated, time: .shortened)
            let by = entry.author.isEmpty ? "" : " · \(entry.author)"
            let detail = entry.detail.isEmpty ? "" : "\n  \(entry.detail.replacingOccurrences(of: "\n", with: "\n  "))"
            return "- **\(date)** · _[\(entry.kind.rawValue)]_\(by) — \(entry.summary)\(detail)"
        }.joined(separator: "\n")
        let text = "# \(project.name) — Project Journal\n\n\(body.isEmpty ? "(empty)" : body)\n"
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func formatted(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }
}

private struct DayBucketView: View {
    var day: Date
    var entries: [JournalEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(day.formatted(date: .complete, time: .omitted))
                .font(.headline)
                .foregroundStyle(.secondary)
            ForEach(entries) { entry in
                EntryCard(entry: entry)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct EntryCard: View {
    var entry: JournalEntry

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: entry.kind.symbolName)
                .font(.title3)
                .foregroundStyle(kindColor)
                .frame(width: 26)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(entry.summary)
                        .font(.system(size: 16, weight: .semibold))
                    Tag(text: entry.kind.rawValue, color: kindColor)
                    Spacer()
                    Text(entry.occurredAt.formatted(date: .omitted, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                if !entry.detail.isEmpty {
                    Text(entry.detail)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !entry.author.isEmpty {
                    Text("— \(entry.author)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var kindColor: Color {
        switch entry.kind {
        case .verification: .green
        case .mission: .purple
        case .knowledge: .orange
        case .setup: .blue
        case .note: .gray
        case .decision: .indigo
        }
    }
}

private struct Tag: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}
