import LocalForgeCore
import SwiftUI

/// Phase 8.5 — Global Command Palette (⌘K).
/// Keyboard-first fuzzy search across all projects, records, and actions.
struct CommandPaletteView: View {
    @ObservedObject var store: WorkspaceStore
    @Binding var isPresented: Bool
    @State private var query = ""
    @State private var selected: CommandPaletteItem?
    @FocusState private var searchFocused: Bool

    private var items: [CommandPaletteItem] {
        store.commandPaletteItems(query: query)
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            Divider()
            if items.isEmpty {
                emptyState
            } else {
                resultsList
            }
        }
        .frame(width: 580, height: min(CGFloat(items.count) * 46 + 58, 480))
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .onAppear {
            query = ""
            selected = nil
            searchFocused = true
        }
    }

    // MARK: - Search bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
                .font(.system(size: 16))
            TextField("Search projects, verifications, risks, decisions…", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 15))
                .focused($searchFocused)
                .onSubmit { activateSelected() }
            if !query.isEmpty {
                Button {
                    query = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: - Results list

    private var resultsList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(items) { item in
                        CommandPaletteRow(item: item, isSelected: selected?.id == item.id)
                            .id(item.id)
                            .contentShape(Rectangle())
                            .onTapGesture { activate(item) }
                            .onHover { hovering in if hovering { selected = item } }
                    }
                }
            }
            .onChange(of: selected) { _, newSelected in
                if let id = newSelected?.id {
                    withAnimation(.none) { proxy.scrollTo(id, anchor: .center) }
                }
            }
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(.tertiary)
            Text(query.isEmpty ? "Type to search" : "No results for \"\(query)\"")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
    }

    // MARK: - Activation

    private func activateSelected() {
        if let item = selected ?? items.first {
            activate(item)
        }
    }

    private func activate(_ item: CommandPaletteItem) {
        isPresented = false
        guard let action = item.actionKind else { return }
        switch action {
        case .openProject:
            if let pid = item.projectID, let project = store.projects.first(where: { $0.id == pid }) {
                store.selectProject(project)
            }
        case .openVerification:
            if let pid = item.projectID, let project = store.projects.first(where: { $0.id == pid }) {
                store.selectProject(project)
                store.selectedModule = .verification
            }
        case .openEvidence:
            if let pid = item.projectID, let project = store.projects.first(where: { $0.id == pid }) {
                store.selectProject(project)
                store.selectedModule = .registers
            }
        case .openRisk:
            if let pid = item.projectID, let project = store.projects.first(where: { $0.id == pid }) {
                store.selectProject(project)
                store.selectedModule = .registers
            }
        case .openDecision:
            if let pid = item.projectID, let project = store.projects.first(where: { $0.id == pid }) {
                store.selectProject(project)
                store.selectedModule = .registers
            }
        case .openArchitecture:
            if let pid = item.projectID, let project = store.projects.first(where: { $0.id == pid }) {
                store.selectProject(project)
                store.selectedModule = .registers
            }
        case .openAssumption:
            if let pid = item.projectID, let project = store.projects.first(where: { $0.id == pid }) {
                store.selectProject(project)
                store.selectedModule = .registers
            }
        case .openTimeline:
            store.selectedModule = .timeline
        case .openReport:
            store.selectedModule = .reports
        case .generateHandoff:
            store.selectedModule = .handoff
        case .openJournal:
            store.selectedModule = .journal
        case .openTruthCentre:
            store.selectedModule = .truthCentre
        case .openReleaseReadiness:
            store.selectedModule = .releaseReadiness
        case .openWorkspaceHealth:
            store.selectedModule = .workspaceHealth
        case .openWorkspaceDoctor:
            store.selectedModule = .workspaceDoctor
        case .openBackupCentre:
            store.selectedModule = .backupCentre
        case .openUtilityCentre:
            store.selectedModule = .utilityCentre
        }
    }
}

private struct CommandPaletteRow: View {
    var item: CommandPaletteItem
    var isSelected: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: item.kind.symbolName)
                .frame(width: 20)
                .foregroundStyle(isSelected ? .white : .secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(1)
                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let actionKind = item.actionKind {
                Text(actionKind.rawValue)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background((isSelected ? Color.white.opacity(0.2) : Color.secondary.opacity(0.15)))
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(isSelected ? .white.opacity(0.9) : .secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor : Color.clear)
        .contentShape(Rectangle())
    }
}
