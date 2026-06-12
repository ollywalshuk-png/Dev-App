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
                    trustScanOverview
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
            if !report.isEmpty {
                HStack(spacing: 6) {
                    Label("\(affectedProjectCount(report.issues)) projects affected", systemImage: "folder.badge.gearshape")
                    Text("·")
                        .foregroundStyle(.tertiary)
                    if let leadingCategory {
                        Text("Top area: \(leadingCategory.rawValue)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
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

    private var trustScanOverview: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 158), spacing: 8)], spacing: 8) {
            ForEach(HealthIssueCategory.allCases, id: \.self) { category in
                let issues = report.issues(for: category)
                Button {
                    selectedCategory = selectedCategory == category ? nil : category
                } label: {
                    WorkspaceHealthCategorySummary(
                        category: category,
                        issueCount: issues.count,
                        projectCount: affectedProjectCount(issues),
                        criticalCount: issues.filter { $0.severity == .critical }.count,
                        highCount: issues.filter { $0.severity == .high }.count,
                        isSelected: selectedCategory == category
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var leadingCategory: HealthIssueCategory? {
        HealthIssueCategory.allCases
            .map { category in (category: category, count: report.issues(for: category).count) }
            .filter { $0.count > 0 }
            .max { $0.count < $1.count }?
            .category
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
            return sortedIssues(report.issues(for: cat))
        }
        return sortedIssues(report.issues)
    }

    private var visibleIssueGroups: [WorkspaceHealthIssueGroup] {
        HealthIssueCategory.allCases.compactMap { category in
            let issues = sortedIssues(report.issues(for: category))
            guard !issues.isEmpty else { return nil }
            return WorkspaceHealthIssueGroup(category: category, issues: issues)
        }
    }

    private var issuesList: some View {
        Group {
            if visibleIssues.isEmpty {
                ContentUnavailableView(
                    selectedCategory == nil ? "No workspace health issues" : "No issues in this category",
                    systemImage: "checkmark.circle",
                    description: Text(selectedCategory == nil ? "Truth, evidence, registers, assumptions, architecture, and dependencies are clear." : "Everything looks healthy here.")
                )
            } else if selectedCategory == nil {
                LazyVStack(alignment: .leading, spacing: 14) {
                    ForEach(visibleIssueGroups) { group in
                        WorkspaceHealthIssueSection(category: group.category, issues: group.issues)
                    }
                }
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

    private func sortedIssues(_ issues: [WorkspaceHealthIssue]) -> [WorkspaceHealthIssue] {
        issues.sorted { lhs, rhs in
            if lhs.severity.sortRank != rhs.severity.sortRank {
                return lhs.severity.sortRank < rhs.severity.sortRank
            }
            if lhs.category.rawValue != rhs.category.rawValue {
                return lhs.category.rawValue < rhs.category.rawValue
            }
            return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
        }
    }

    private func affectedProjectCount(_ issues: [WorkspaceHealthIssue]) -> Int {
        Set(issues.map(\.projectID)).count
    }
}

private struct WorkspaceHealthIssueGroup: Identifiable {
    var category: HealthIssueCategory
    var issues: [WorkspaceHealthIssue]

    var id: HealthIssueCategory { category }
}

private struct WorkspaceHealthCategorySummary: View {
    var category: HealthIssueCategory
    var issueCount: Int
    var projectCount: Int
    var criticalCount: Int
    var highCount: Int
    var isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: category.symbolName)
                    .foregroundStyle(category.tint)
                    .frame(width: 16)
                Text(category.rawValue)
                    .font(.system(size: 12, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
            }
            Text(category.scanCue)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.82)
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Text("\(issueCount)")
                    .font(.system(size: 24, weight: .bold).monospacedDigit())
                    .foregroundStyle(issueCount == 0 ? Color.green : category.tint)
                    .lineLimit(1)
                Text(issueCount == 1 ? "issue" : "issues")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 4) {
                if criticalCount > 0 {
                    severityMiniBadge("C", count: criticalCount, color: .red)
                }
                if highCount > 0 {
                    severityMiniBadge("H", count: highCount, color: .orange)
                }
                if issueCount == 0 {
                    Text("Clear")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                } else {
                    Text("\(projectCount) \(projectCount == 1 ? "project" : "projects")")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .background(
            isSelected ? category.tint.opacity(0.16) : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(isSelected ? category.tint.opacity(0.65) : Color.secondary.opacity(0.18), lineWidth: 1)
        )
    }

    private func severityMiniBadge(_ label: String, count: Int, color: Color) -> some View {
        Text("\(label) \(count)")
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct WorkspaceHealthIssueSection: View {
    var category: HealthIssueCategory
    var issues: [WorkspaceHealthIssue]

    private var criticalCount: Int { issues.filter { $0.severity == .critical }.count }
    private var highCount: Int { issues.filter { $0.severity == .high }.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: category.symbolName)
                    .foregroundStyle(category.tint)
                    .frame(width: 18)
                Text(category.rawValue.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(category.tint)
                Text(category.scanCue)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)
                Spacer(minLength: 8)
                Text("\(issues.count)")
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(.secondary)
                if criticalCount > 0 {
                    sectionBadge("\(criticalCount) critical", color: .red)
                }
                if highCount > 0 {
                    sectionBadge("\(highCount) high", color: .orange)
                }
            }
            ForEach(issues) { issue in
                WorkspaceHealthIssueRow(issue: issue)
            }
        }
    }

    private func sectionBadge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.13), in: Capsule())
            .foregroundStyle(color)
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
                        .foregroundStyle(issue.severity.tint)
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

                    Text(issue.severity.rawValue.uppercased())
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(issue.severity.tint.opacity(0.13), in: Capsule())
                        .foregroundStyle(issue.severity.tint)

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
                        detailBlock(label: issue.category.detailLabel, text: issue.detail)
                    }
                    if !issue.recommendation.isEmpty {
                        detailBlock(label: issue.category.recommendationLabel, text: issue.recommendation)
                    }
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(issue.severity.tint.opacity(0.3), lineWidth: 1)
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

}

private extension HealthIssueSeverity {
    var tint: Color {
        switch self {
        case .critical: .red
        case .high: .orange
        case .medium: .yellow
        case .low: .secondary
        }
    }

    var sortRank: Int {
        switch self {
        case .critical: 0
        case .high: 1
        case .medium: 2
        case .low: 3
        }
    }
}

private extension HealthIssueCategory {
    var symbolName: String {
        switch self {
        case .truthDecay: "checkmark.shield"
        case .evidenceDecay: "doc.text.magnifyingglass"
        case .registerDecay: "rectangle.grid.2x2"
        case .assumptionDecay: "lightbulb"
        case .architectureDrift: "building.columns"
        case .dependencyIssues: "point.3.connected.trianglepath.dotted"
        }
    }

    var tint: Color {
        switch self {
        case .truthDecay: .indigo
        case .evidenceDecay: .blue
        case .registerDecay: .teal
        case .assumptionDecay: .orange
        case .architectureDrift: .purple
        case .dependencyIssues: .red
        }
    }

    var scanCue: String {
        switch self {
        case .truthDecay: "Claim vs ledger"
        case .evidenceDecay: "Proof freshness"
        case .registerDecay: "Coverage gaps"
        case .assumptionDecay: "Unverified assumptions"
        case .architectureDrift: "Design vs code"
        case .dependencyIssues: "Blocked dependencies"
        }
    }

    var detailLabel: String {
        switch self {
        case .truthDecay: "Truth Signal"
        case .evidenceDecay: "Evidence Gap"
        case .registerDecay: "Register Gap"
        case .assumptionDecay: "Assumption Risk"
        case .architectureDrift: "Drift Signal"
        case .dependencyIssues: "Dependency Block"
        }
    }

    var recommendationLabel: String {
        switch self {
        case .truthDecay: "Next Check"
        case .evidenceDecay: "Evidence Action"
        case .registerDecay: "Register Action"
        case .assumptionDecay: "Assumption Action"
        case .architectureDrift: "Architecture Action"
        case .dependencyIssues: "Dependency Action"
        }
    }
}
