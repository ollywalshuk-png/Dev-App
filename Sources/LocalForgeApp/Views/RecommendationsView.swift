import LocalForgeCore
import Foundation
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
                    why: "Large, risky, or security-sensitive projects need context before action. A recommendation should show the target, impact, evidence, warning, and suggested adjustment.",
                    next: "Run a manual scan, review each recommendation, then acknowledge, approve, reject, or mark it complete.",
                    safety: "Approval here records intent only. LocalForge does not rewrite source files, run fixes, commit, push, delete, rotate credentials, upload content, or merge from this screen.",
                    example: "Example: a Swift file over 1,750 lines is flagged with a refactor suggestion, or a possible secret pattern is flagged with a redacted preview. No automatic change is performed.",
                    symbol: "exclamationmark.bubble",
                    tint: .orange
                )
                warningBanner
                if records.isEmpty {
                    ContentUnavailableView(
                        "No recommendations yet",
                        systemImage: "checkmark.shield",
                        description: Text("Run a repo-scoped code-size scan or local secret scan. Empty means no LocalForge recommendations have been recorded yet, not that the project is fully healthy.")
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
                Text("Repo-scoped, evidence-backed suggestions. Manual scans only, no automatic fixes.")
                    .foregroundStyle(.secondary)
            }
            Spacer()
            HStack(spacing: 8) {
                Button {
                    store.runSecretRecommendationScan(for: project.id)
                } label: {
                    Label("Scan Secrets", systemImage: "lock.shield")
                }
                .help("Read-only local scan for potential secret patterns. Values are redacted and not stored.")

                Button {
                    store.runCodeSizeRecommendationScan(for: project.id)
                } label: {
                    Label("Scan Code Size", systemImage: "doc.text.magnifyingglass")
                }
                .help("Read-only scan for source files over 1,750 lines")
            }
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
                Text("A recommendation may describe source-file or secret-pattern risk, but this screen only records review decisions. Secret scan findings store locations and redacted previews only. Any future mutating action must show its own target, diff or preview, warning, rollback note, and one-action approval.")
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func summary(_ records: [RecommendationRecord]) -> some View {
        let evidenceBacked = records.filter { $0.isEvidenceBacked }.count
        let missingLinks = records.filter { !$0.hasEvidenceLinks }.count
        let stale = records.filter { $0.isStaleForReview }.count

        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
            StatCell(label: "Open", value: "\(records.filter { $0.approvalState == .open }.count)", color: .orange)
            StatCell(label: "Advisory", value: "\(records.count)", color: .blue)
            StatCell(label: "Evidence", value: "\(evidenceBacked)", color: .indigo)
            StatCell(label: "No Links", value: "\(missingLinks)", color: missingLinks > 0 ? .orange : .gray)
            StatCell(label: "Stale", value: "\(stale)", color: stale > 0 ? .orange : .gray)
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
                Image(systemName: symbolName)
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

            trustStrip

            VStack(alignment: .leading, spacing: 6) {
                DetailRow(label: "Category", value: record.category.rawValue)
                DetailRow(label: "Target", value: record.targetPath)
                DetailRow(label: "Risk", value: record.severity.rawValue)
                DetailRow(label: "Confidence", value: record.confidencePercentLabel)
                DetailRow(label: "Evidence", value: record.evidenceSummary)
                DetailRow(label: "Evidence link", value: record.evidenceLinkLabel)
                DetailRow(label: "Impact", value: record.impact)
                DetailRow(label: "Suggested adjustment", value: record.suggestedAdjustment)
                DetailRow(label: "Warning", value: record.safetyWarning)
                DetailRow(label: "Rollback", value: record.rollbackNote)
                DetailRow(label: "Review age", value: "\(record.createdDateLabel); \(record.updatedAgeLabel)")
            }

            TextField("Optional review note", text: $note)
                .textFieldStyle(.roundedBorder)

            HStack {
                Button("Acknowledge") { onState(.acknowledged) }
                    .help("Records that this local recommendation has been seen.")
                Button("Approve Review") { onState(.approved) }
                    .help("Records approval intent only. No automated fix is run.")
                Button("Reject Review") { onState(.rejected) }
                    .help("Records a review decision only. No source file is changed.")
                Spacer()
                Button("Mark Review Complete") { onState(.completed) }
                    .help("Marks the recommendation review complete. This does not apply a patch.")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var trustStrip: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 8)], alignment: .leading, spacing: 8) {
            TrustBadge(label: "Local record", systemImage: "folder", color: .teal)
            TrustBadge(label: "Advisory only", systemImage: "lightbulb", color: .blue)
            TrustBadge(label: "No auto-fix", systemImage: "hand.raised", color: .orange)
            TrustBadge(label: record.evidenceBadgeLabel, systemImage: record.evidenceBadgeSymbol, color: record.evidenceBadgeColor)
            TrustBadge(label: record.stalenessBadgeLabel, systemImage: record.stalenessBadgeSymbol, color: record.stalenessBadgeColor)
            TrustBadge(label: record.sourceTargetLabel, systemImage: "doc.text", color: record.sourceFilesAffected ? .purple : .gray)
        }
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

    private var symbolName: String {
        if record.category == .safety {
            return "lock.shield"
        }
        return record.sourceFilesAffected ? "doc.badge.gearshape" : "lightbulb"
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

private struct TrustBadge: View {
    var label: String
    var systemImage: String
    var color: Color

    var body: some View {
        Label(label, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
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
            Text(displayValue)
                .font(.callout)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var displayValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Not recorded" : value
    }
}

private extension RecommendationRecord {
    var hasEvidenceSummary: Bool {
        !evidenceSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var hasEvidenceLinks: Bool {
        !relatedEvidenceIDs.isEmpty
    }

    var isEvidenceBacked: Bool {
        hasEvidenceSummary || hasEvidenceLinks
    }

    var isStaleForReview: Bool {
        guard approvalState != .completed, approvalState != .rejected else { return false }
        return ageInDays(since: updatedAt) >= 30
    }

    var confidencePercentLabel: String {
        let normalized = min(max(confidence, 0), 1)
        return "\(Int((normalized * 100).rounded()))%"
    }

    var evidenceLinkLabel: String {
        switch relatedEvidenceIDs.count {
        case 0:
            return "No related evidence record linked"
        case 1:
            return "1 related evidence record"
        default:
            return "\(relatedEvidenceIDs.count) related evidence records"
        }
    }

    var evidenceBadgeLabel: String {
        if hasEvidenceLinks {
            return "Evidence linked"
        }
        if hasEvidenceSummary {
            return "No evidence link"
        }
        return "Missing evidence"
    }

    var evidenceBadgeSymbol: String {
        if hasEvidenceLinks {
            return "link"
        }
        if hasEvidenceSummary {
            return "doc.text"
        }
        return "exclamationmark.triangle"
    }

    var evidenceBadgeColor: Color {
        if hasEvidenceLinks {
            return .green
        }
        if hasEvidenceSummary {
            return .orange
        }
        return .red
    }

    var stalenessBadgeLabel: String {
        if isStaleForReview {
            return "Stale \(ageToken)"
        }
        return "Updated \(ageToken)"
    }

    var stalenessBadgeSymbol: String {
        isStaleForReview ? "clock.badge.exclamationmark" : "clock"
    }

    var stalenessBadgeColor: Color {
        isStaleForReview ? .orange : .gray
    }

    var sourceTargetLabel: String {
        sourceFilesAffected ? "Source target" : "No source target"
    }

    var createdDateLabel: String {
        "Created \(DateFormatter.localizedString(from: createdAt, dateStyle: .medium, timeStyle: .short))"
    }

    var updatedAgeLabel: String {
        "updated \(ageToken)"
    }

    private var ageToken: String {
        let days = ageInDays(since: updatedAt)
        switch days {
        case 0:
            return "today"
        case 1:
            return "1d ago"
        case 2..<30:
            return "\(days)d ago"
        case 30..<365:
            return "\(max(1, days / 30))mo ago"
        default:
            return "\(max(1, days / 365))y ago"
        }
    }

    private func ageInDays(since date: Date) -> Int {
        let seconds = max(0, Date().timeIntervalSince(date))
        return Int(seconds / 86_400)
    }
}
