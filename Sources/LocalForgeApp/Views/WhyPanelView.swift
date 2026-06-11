import LocalForgeCore
import SwiftUI

/// Phase 8.5 — Why Panel. Renders a WhyPanelContent inline with collapsible sections.
/// Every major object can surface "why does this have this state?" in a traceable,
/// auditable panel.
struct WhyPanelView: View {
    var content: WhyPanelContent
    @State private var expandedSections: Set<String> = []

    var body: some View {
        if content.title.isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 0) {
                header
                Divider()
                ForEach(content.sections) { section in
                    sectionView(section)
                    Divider().padding(.leading, 16)
                }
            }
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .onAppear {
                expandedSections = Set(content.sections.prefix(3).map(\.id.uuidString))
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(content.title)
                .font(.system(size: 13, weight: .semibold))
                .lineLimit(2)
            if !content.summary.isEmpty {
                Text(content.summary)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
    }

    private func sectionView(_ section: WhyPanelSection) -> some View {
        let isExpanded = expandedSections.contains(section.id.uuidString)
        return VStack(alignment: .leading, spacing: 0) {
            Button {
                if isExpanded {
                    expandedSections.remove(section.id.uuidString)
                } else {
                    expandedSections.insert(section.id.uuidString)
                }
            } label: {
                HStack {
                    Text(section.title)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(section.items) { row in
                        WhyRowView(row: row)
                    }
                }
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 24))
                .foregroundStyle(.tertiary)
            Text("Select a record to see why.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
    }
}

private struct WhyRowView: View {
    var row: WhyPanelRow

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: row.symbolName)
                .font(.system(size: 11))
                .foregroundStyle(row.isPositive ? Color.green : row.isNegative ? Color.red : Color.secondary)
                .frame(width: 16)

            Text(row.label)
                .font(.system(size: 12))
                .lineLimit(2)
                .foregroundStyle(row.isNegative ? Color.red : Color.primary)

            Spacer()

            if !row.value.isEmpty {
                Text(row.value)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 5)
        .background(row.isPositive ? Color.green.opacity(0.06) : row.isNegative ? Color.red.opacity(0.06) : Color.clear)
    }
}

// MARK: - Convenience wrappers for specific contexts

struct RealityWhyPanel: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        if let pid = store.selectedProjectID {
            WhyPanelView(content: store.whyReality(for: pid))
        } else {
            WhyPanelView(content: .empty)
        }
    }
}

struct ReleaseWhyPanel: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        if let pid = store.selectedProjectID {
            WhyPanelView(content: store.whyRelease(for: pid))
        } else {
            WhyPanelView(content: .empty)
        }
    }
}

struct VerificationWhyPanel: View {
    @ObservedObject var store: WorkspaceStore
    var record: VerificationRecord

    var body: some View {
        if let pid = store.selectedProjectID {
            WhyPanelView(content: store.whyVerification(record, for: pid))
        } else {
            WhyPanelView(content: .empty)
        }
    }
}
