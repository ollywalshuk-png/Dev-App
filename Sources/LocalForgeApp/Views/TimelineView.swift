import LocalForgeCore
import SwiftUI

/// Phase 8 — Timeline Replay. The project's history as a vertical milestone
/// timeline: mission created, verifications changing state, risks raised,
/// decisions recorded, evidence added. Replays oldest → newest by default so
/// you can read a project's life like a story; flip to newest-first to triage.
struct TimelineView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var oldestFirst = true
    @State private var kindFilter: JournalEntryKind? = nil

    var body: some View {
        if let project = store.selectedProject {
            VStack(alignment: .leading, spacing: 14) {
                header(project: project)
                controls
                timeline
            }
            .padding(20)
        } else {
            ContentUnavailableView(
                "No active project",
                systemImage: "timeline.selection",
                description: Text("Open a project to replay its history.")
            )
        }
    }

    private var entries: [JournalEntry] {
        var all = store.journal(for: store.selectedProjectID) // newest-first
        if let kindFilter { all = all.filter { $0.kind == kindFilter } }
        return oldestFirst ? all.reversed() : all
    }

    private func header(project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Timeline — \(project.name)")
                .font(.system(size: 30, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("Replay how this project got to where it is — every mission change, verification, risk, decision, and piece of evidence in order.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var controls: some View {
        HStack(spacing: 8) {
            Picker("", selection: $oldestFirst) {
                Label("Replay (oldest first)", systemImage: "play").tag(true)
                Label("Latest first", systemImage: "clock.arrow.circlepath").tag(false)
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 320)

            Picker("Kind", selection: $kindFilter) {
                Text("All kinds").tag(JournalEntryKind?.none)
                ForEach(JournalEntryKind.allCases, id: \.self) { kind in
                    Label(kind.rawValue, systemImage: kind.symbolName).tag(JournalEntryKind?.some(kind))
                }
            }
            .frame(maxWidth: 220)
            Spacer()
            Text("\(entries.count) event(s)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    @ViewBuilder
    private var timeline: some View {
        let items = entries
        if items.isEmpty {
            ContentUnavailableView(
                "No history yet",
                systemImage: "book.pages",
                description: Text("Events appear automatically as you verify areas, record decisions, raise risks, and add evidence.")
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.element.id) { index, entry in
                        TimelineRow(
                            entry: entry,
                            isFirst: index == 0,
                            isLast: index == items.count - 1,
                            showDateHeader: index == 0 || !Calendar.current.isDate(
                                entry.occurredAt, inSameDayAs: items[index - 1].occurredAt
                            )
                        )
                    }
                }
                .padding(.top, 4)
            }
        }
    }
}

private struct TimelineRow: View {
    var entry: JournalEntry
    var isFirst: Bool
    var isLast: Bool
    var showDateHeader: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if showDateHeader {
                Text(entry.occurredAt.formatted(date: .complete, time: .omitted))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.leading, 44)
                    .padding(.top, isFirst ? 0 : 14)
                    .padding(.bottom, 6)
            }
            HStack(alignment: .top, spacing: 12) {
                // Spine: connector line + kind dot.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Color.secondary.opacity(isFirst && showDateHeader ? 0 : 0.25))
                        .frame(width: 2, height: 8)
                    ZStack {
                        Circle()
                            .fill(color.opacity(0.18))
                            .frame(width: 26, height: 26)
                        Image(systemName: entry.kind.symbolName)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(color)
                    }
                    Rectangle()
                        .fill(Color.secondary.opacity(isLast ? 0 : 0.25))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
                .frame(width: 26)

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(entry.summary)
                            .font(.system(size: 14, weight: .semibold))
                        Text(entry.kind.rawValue)
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(color.opacity(0.14), in: Capsule())
                            .foregroundStyle(color)
                        Spacer()
                        Text(entry.occurredAt.formatted(date: .omitted, time: .shortened))
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    if !entry.detail.isEmpty {
                        Text(entry.detail)
                            .font(.system(size: 13))
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if !entry.author.isEmpty {
                        Text("— \(entry.author)")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 8)
            }
        }
    }

    private var color: Color {
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
