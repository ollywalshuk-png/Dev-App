import LocalForgeCore
import SwiftUI

struct RecommendationsView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var approvalNote = ""

    var body: some View {
        if let project = store.selectedProject {
            let records = store.recommendations(for: project.id)
            VStack(alignment: .leading, spacing: 16) {
                header(project, records: records)
                ExplanationCard(
                    title: "Recommendations",
                    what: "Recommendations are LocalForge's safe suggestions based on local evidence. They explain a possible improvement before any change is made.",
                    why: "Large or risky projects need context before action. A recommendation should show the target, impact, evidence, warning, and suggested adjustment.",
                    next: "Run the code-size scan, review each recommendation, then acknowledge, approve, reject, or mark it complete.",
                    safety: "Approval here records intent only. LocalForge does not rewrite source files, run fixes, commit, push, delete, or merge from this screen.",
                    example: "Example: a Swift file over 1,750 lines is flagged with a refactor suggestion, but no automatic split is performed.",
                    symbol: "exclamationmark.bubble",
                    tint: .orange
                )
                warningBanner
                if records.isEmpty {
                    ContentUnavailableView(
                        "No recommendations yet",
                        systemImage: "checkmark.shield",
                        description: Text("Run the repo-scoped code-size scan to find source files over 1,750 lines. Empty means no LocalForge recommendations have been recorded yet, not that the project is fully healthy.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 180)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
                } else {
                    summary(records)
                    ForEach(records) { record in
                        RecommendationCard(
                            record: record,
                            note: $approvalNote,
                            onState: { state in
                                store.updateRecommendationState(
                                    id: record.id,
                                    state: state,
                                    for: project.id,
                                    note: approvalNote
                                )
                                approvalNote = ""
                            }
                        )
                    }
                }
            }
        } else {
            ContentUnavailableView("Open a project", systemImage: "exclamationmark.bubble", description: Text("Select a project before reviewing recommendations."))
        }
    }

    private func header(_ project: ProjectContext, records: [RecommendationRecord]) -> some View {
        HStack(alignment: .center) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Recommendations — \(project.name)")
                    .font(.title2.weight(.semibold))
                Text("Repo-scoped, evidence-backed suggestions. No automatic fixes.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                store.runCodeSizeRecommendationScan(for: project.id)
            } label: {
                Label("Scan Code Size", systemImage: "doc.text.magnifyingglass")
            }
            .help("Read-only scan for source files over 1,750 lines")
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var warningBanner: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 4) {
                Text("Approval-gated by design")
                    .font(.headline)
                Text("A recommendation may describe source-file risk, but this screen only records review decisions. Any future mutating action must show its own target, diff or preview, warning, rollback note, and one-action approval.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func summary(_ records: [RecommendationRecord]) -> some View {
        HStack(spacing: 10) {
            StatCell(label: "Open", value: "\(records.filter { $0.approvalState == .open }.count)", color: .orange)
            StatCell(label: "Approved", value: "\(records.filter { $0.approvalState == .approved }.count)", color: .blue)
            StatCell(label: "Rejected", value: "\(records.filter { $0.approvalState == .rejected }.count)", color: .red)
            StatCell(label: "Complete", value: "\(records.filter { $0.approvalState == .completed }.count)", color: .green)
        }
    }
}

private struct RecommendationCard: View {
    var record: RecommendationRecord
    @Binding var note: String
    var onState: (RecommendationApprovalState) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: record.sourceFilesAffected ? "doc.badge.gearshape" : "lightbulb")
                    .foregroundStyle(severityColor)
                    .frame(width: 22)
                VStack(alignment: .leading, spacing: 4) {
                    Text(record.title)
                        .font(.headline)
                    Text(record.summary)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text(record.approvalState.rawValue)
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(stateColor.opacity(0.16), in: Capsule())
                    .foregroundStyle(stateColor)
            }

            VStack(alignment: .leading, spacing: 6) {
                DetailRow(label: "Target", value: record.targetPath)
                DetailRow(label: "Risk", value: record.severity.rawValue)
                DetailRow(label: "Evidence", value: record.evidenceSummary)
                DetailRow(label: "Impact", value: record.impact)
                DetailRow(label: "Suggested adjustment", value: record.suggestedAdjustment)
                DetailRow(label: "Warning", value: record.safetyWarning)
                DetailRow(label: "Rollback", value: record.rollbackNote)
            }

            TextField("Optional approval/rejection note", text: $note)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Acknowledge") { onState(.acknowledged) }
                Button("Approve") { onState(.approved) }
                Button("Reject") { onState(.rejected) }
                Spacer()
                Button("Mark Complete") { onState(.completed) }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var severityColor: Color {
        switch record.severity {
        case .info: .gray
        case .advisory: .blue
        case .warning: .orange
        case .high: .red
        case .critical: .purple
        }
    }

    private var stateColor: Color {
        switch record.approvalState {
        case .open: .orange
        case .acknowledged: .blue
        case .approved: .green
        case .rejected: .red
        case .completed: .green
        }
    }
}

private struct DetailRow: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value.isEmpty ? "Not recorded" : value)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
