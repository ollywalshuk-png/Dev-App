import LocalForgeCore
import SwiftUI

/// Phase 8 — Universal Search. One query across every record type in every
/// open project: missions, verification, evidence, journal, knowledge,
/// decisions, risks, architecture, assumptions. Click a result to jump to the
/// module that owns it.
struct SearchView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var query = ""
    @State private var kindFilter: SearchHitKind? = nil
    @State private var blockingOnly = false
    @FocusState private var searchFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            searchBar
            filterBar
            resultsList
        }
        .padding(20)
        .onAppear { searchFocused = true }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Search")
                .font(.system(size: 30, weight: .bold))
            Text("Everything LocalForge knows, across every project — evidence, risks, decisions, journal, verification.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Search (e.g. 'Preset System', 'AUState', 'corruption')", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 16))
                .focused($searchFocused)
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.tertiary)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var hits: [SearchHit] {
        var results = store.searchWorkspace(query)
        if let kindFilter { results = results.filter { $0.kind == kindFilter } }
        if blockingOnly { results = results.filter { $0.kind != .risk || $0.isReleaseBlocking } }
        return results
    }

    private var filterBar: some View {
        let all = store.searchWorkspace(query)
        let presentKinds = SearchHitKind.allCases.filter { kind in all.contains { $0.kind == kind } }
        return HStack(spacing: 6) {
            FilterChip(label: "All (\(all.count))", isOn: kindFilter == nil) { kindFilter = nil }
            ForEach(presentKinds, id: \.self) { kind in
                let count = all.filter { $0.kind == kind }.count
                FilterChip(label: "\(kind.rawValue) (\(count))", isOn: kindFilter == kind) {
                    kindFilter = kindFilter == kind ? nil : kind
                }
            }
            Spacer()
            Toggle("Release-blocking risks only", isOn: $blockingOnly)
                .toggleStyle(.checkbox)
                .font(.caption)
        }
    }

    @ViewBuilder
    private var resultsList: some View {
        let results = hits
        if query.trimmingCharacters(in: .whitespaces).count < 2 {
            ContentUnavailableView(
                "Search the workspace",
                systemImage: "magnifyingglass",
                description: Text("Type at least two characters. Try an area name, a risk, a decision keyword, or an author.")
            )
        } else if results.isEmpty {
            ContentUnavailableView(
                "No matches",
                systemImage: "questionmark.circle",
                description: Text("Nothing matches \"\(query)\" with the current filters.")
            )
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(results) { hit in
                        SearchHitRow(hit: hit, showProject: store.projects.count > 1) {
                            jump(to: hit)
                        }
                    }
                }
            }
        }
    }

    private func jump(to hit: SearchHit) {
        if let project = store.projects.first(where: { $0.id == hit.projectID }) {
            store.selectProject(project)
        }
        store.selectedModule = module(for: hit.kind)
    }

    private func module(for kind: SearchHitKind) -> WorkspaceModule {
        switch kind {
        case .project: .projects
        case .mission: .mission
        case .verification: .verification
        case .evidence: .truthCentre
        case .journal: .journal
        case .knowledge: .knowledgeVault
        case .decision, .risk, .architecture, .assumption: .registers
        }
    }
}

private struct FilterChip: View {
    var label: String
    var isOn: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.caption.weight(.semibold))
                .padding(.horizontal, 9)
                .padding(.vertical, 4)
                .background(isOn ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.08), in: Capsule())
                .foregroundStyle(isOn ? Color.accentColor : .secondary)
        }
        .buttonStyle(.plain)
    }
}

private struct SearchHitRow: View {
    var hit: SearchHit
    var showProject: Bool
    var onJump: () -> Void

    var body: some View {
        Button(action: onJump) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: hit.kind.symbolName)
                    .foregroundStyle(.blue)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(hit.title)
                            .font(.system(size: 14, weight: .semibold))
                            .lineLimit(1)
                        Chip(text: hit.kind.rawValue, color: .indigo)
                        if hit.isReleaseBlocking {
                            Chip(text: "Release-blocking", color: .red)
                        }
                        if showProject {
                            Chip(text: hit.projectName, color: .blue)
                        }
                        Spacer()
                        if let date = hit.date {
                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Image(systemName: "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                    Text(hit.snippet)
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

private struct Chip: View {
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
