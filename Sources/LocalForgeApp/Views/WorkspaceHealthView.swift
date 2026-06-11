import LocalForgeCore
import SwiftUI

/// Phase 8.5 — Workspace Health Engine surface. Read-only diagnostics that
/// detect truth decay, evidence decay, register decay, assumption decay,
/// architecture drift, and dependency issues.
struct WorkspaceHealthView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var report: WorkspaceHealthReport = WorkspaceHealthReport()
    @State private var selectedCategory: HealthIssueCategory?

    var body: some View {
        if store.projects.isEmpty {
            ContentUnavailableView("No projects", systemImage: "heart.text.square",
                description: Text("Open a project to run workspace health diagnostics."))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    categoryPicker
                    issuesList
                }
                .padding(20)
            }
            .onAppear { refresh() }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workspace Health")
                .font(.system(size: 28, weight: .bold))
            HStack(spacing: 12) {
                if report.criticalCount > 0 {
                    healthBadge("\(report.criticalCount) Critical", color: .red)
                }
                if report.highCount > 0 {
                    healthBadge("\(report.highCount) High", color: .orange)
                }
                let otherCount = report.issues.count - report.criticalCount - report.highCount
                if otherCount > 0 {
                    healthBadge("\(otherCount) Other", color: .yellow)
                }
                if report.isEmpty {
                    healthBadge("All Clear", color: .green)
                }
                Spacer()
                Text("Updated \(report.generatedAt, format: .dateTime.hour().minute())")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Refresh") { refresh() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func healthBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    // MARK: - Category picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                categoryChip(nil, label: "All", count: report.issues.count)
                ForEach(HealthIssueCategory.allCases, id: \.self) { cat in
                    let count = report.issues(for: cat).count
                    if count > 0 {
                        categoryChip(cat, label: cat.rawValue, count: count)
                    }
                }
            }
        }
    }

    private func categoryChip(_ cat: HealthIssueCategory?, label: String, count: Int) -> some View {
        let isSelected = selectedCategory == cat
        return Button {
            selectedCategory = cat
        } label: {
            HStack(spacing: 4) {
                Text(label)
                Text("\(count)")
                    .font(.caption2)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(isSelected ? Color.white.opacity(0.3) : Color.secondary.opacity(0.15))
                    .clipShape(Capsule())
            }
            .font(.caption.weight(isSelected ? .semibold : .regular))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.1))
            .foregroundStyle(isSelected ? .white : .primary)
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Issues list

    private var visibleIssues: [WorkspaceHealthIssue] {
        if let cat = selectedCategory {
            return report.issues(for: cat)
        }
        return report.issues
    }

    private var issuesList: some View {
        Group {
            if visibleIssues.isEmpty {
                ContentUnavailableView(
                    "No issues in this category",
                    systemImage: "checkmark.circle",
                    description: Text("Everything looks healthy here.")
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(visibleIssues) { issue in
                        WorkspaceHealthIssueRow(issue: issue)
                    }
                }
            }
        }
    }

    private func refresh() {
        report = store.workspaceHealthReport
    }
}

private struct WorkspaceHealthIssueRow: View {
    var issue: WorkspaceHealthIssue
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) { expanded.toggle() }
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: issue.severity.symbolName)
                        .foregroundStyle(severityColor(issue.severity))
                        .frame(width: 18)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(issue.title)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(expanded ? nil : 1)
                        HStack(spacing: 6) {
                            Text(issue.category.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(issue.projectName)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: expanded ? "chevron.up" : "chevron.down")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                .padding(12)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if expanded {
                Divider().padding(.horizontal, 12)
                VStack(alignment: .leading, spacing: 8) {
                    if !issue.detail.isEmpty {
                        detailBlock(label: "Detail", text: issue.detail)
                    }
                    if !issue.recommendation.isEmpty {
                        detailBlock(label: "Recommendation", text: issue.recommendation)
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(severityColor(issue.severity).opacity(0.3), lineWidth: 1)
        )
    }

    private func detailBlock(label: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(text)
                .font(.caption)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func severityColor(_ s: HealthIssueSeverity) -> Color {
        switch s {
        case .critical: .red
        case .high: .orange
        case .medium: .yellow
        case .low: .secondary
        }
    }
}
