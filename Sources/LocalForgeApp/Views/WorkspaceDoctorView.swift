import LocalForgeCore
import SwiftUI

/// Phase 8.5 — Workspace Doctor. Read-only integrity diagnostics.
/// Detects broken links, orphan records, duplicates, corrupt relationships.
/// Never auto-fixes.
struct WorkspaceDoctorView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var report: WorkspaceDoctorReport = WorkspaceDoctorReport()

    var body: some View {
        if store.projects.isEmpty {
            ContentUnavailableView("No projects", systemImage: "stethoscope",
                description: Text("Open a project to run workspace integrity diagnostics."))
        } else {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    issuesList
                }
                .padding(20)
            }
            .onAppear { refresh() }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Workspace Doctor")
                .font(.system(size: 28, weight: .bold))
            Text("Read-only integrity diagnostics. Issues are reported — never auto-fixed.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                if report.criticalCount > 0 {
                    badge("\(report.criticalCount) Critical", color: .red)
                }
                let others = report.issues.count - report.criticalCount
                if others > 0 {
                    badge("\(others) Other", color: .orange)
                }
                if report.isEmpty {
                    badge("No issues found", color: .green)
                }
                Spacer()
                Text("Checked \(report.checkedAt, format: .dateTime.hour().minute()) · \(report.projectsChecked) project(s)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Re-diagnose") { refresh() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
    }

    private func badge(_ label: String, color: Color) -> some View {
        Text(label)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.15))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }

    private var issuesList: some View {
        Group {
            if report.isEmpty {
                ContentUnavailableView(
                    "No integrity issues found",
                    systemImage: "checkmark.shield",
                    description: Text("Your workspace looks clean across \(report.projectsChecked) project(s).")
                )
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(report.issues) { issue in
                        DoctorIssueRow(issue: issue)
                    }
                }
            }
        }
    }

    private func refresh() {
        report = store.workspaceDoctorReport
    }
}

private struct DoctorIssueRow: View {
    var issue: WorkspaceDoctorIssue
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
                            Text(issue.kind.rawValue)
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
                    labeled("Impact", issue.impact)
                    labeled("Recommendation", issue.recommendation)
                }
                .padding(12)
            }
        }
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(severityColor(issue.severity).opacity(0.25), lineWidth: 1)
        )
    }

    private func labeled(_ label: String, _ text: String) -> some View {
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
