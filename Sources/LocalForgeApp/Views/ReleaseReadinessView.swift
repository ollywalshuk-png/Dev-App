import AppKit
import LocalForgeCore
import SwiftUI

/// Phase 6.5 — Release Readiness board. Pure read of verification records,
/// grouped by priority. No automation, no scanning.
struct ReleaseReadinessView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        if let project = store.selectedProject, let board = store.releaseBoard {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(project: project, board: board)
                    ExplanationCard(
                        title: "Release Readiness",
                        what: "Release Readiness combines build, test, verification, evidence, signing, and risk state into a release-focused board.",
                        why: "A project can compile and still be unsafe to ship if critical areas are unknown, failed, blocked, or missing evidence.",
                        next: board.status == .ready ? "Review the release brief and keep evidence attached before distribution." : "Work through critical and high-priority rows first, then attach or promote supporting evidence.",
                        safety: "This screen is read-only. It summarises records already stored in LocalForge and does not notarise, upload, sign, or change the project.",
                        example: "Example: Build passed, but preset restore remains unknown, so release confidence stays limited.",
                        symbol: "flag.checkered",
                        tint: .orange
                    )
                    truthDebtPanel(project: project)
                    if board.rows.isEmpty {
                        ContentUnavailableView(
                            "No in-scope areas",
                            systemImage: "flag.checkered",
                            description: Text("Set the project mission and run the Setup Wizard so LocalForge knows what to release-check.")
                        )
                    } else {
                        ForEach(board.rowsByPriority, id: \.priority) { group in
                            if !group.rows.isEmpty {
                                prioritySection(priority: group.priority, rows: group.rows)
                            }
                        }
                        copyButton(project: project, board: board)
                    }
                }
                .padding(20)
            }
        } else {
            ContentUnavailableView(
                "No project selected",
                systemImage: "flag.checkered",
                description: Text("Open a project to see its release readiness.")
            )
        }
    }

    private func truthDebtPanel(project: ProjectContext) -> some View {
        let report = truthDebtReport(for: project)
        let status = report?.status ?? .defensible
        let color = truthDebtColor(status)
        let nextAction = report?.nextActions.first ?? "Keep release evidence fresh before making or distributing a release-ready claim."

        return HStack(alignment: .center, spacing: 12) {
            Image(systemName: truthDebtSymbol(status))
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text("TruthDebtEngine")
                        .font(.caption.weight(.bold))
                        .tracking(0.8)
                        .foregroundStyle(.secondary)
                    Text("Release Claim")
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(color.opacity(0.16), in: Capsule())
                        .foregroundStyle(color)
                }
                Text(report?.headline ?? "No truth debt gates detected for the current records.")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Next: \(nextAction)")
                    .font(.system(size: 13))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            CountTag(label: "Blockers", count: report?.blockers.count ?? 0, color: .red)
            CountTag(label: "Caveats", count: report?.caveats.count ?? 0, color: .orange)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func truthDebtReport(for project: ProjectContext) -> TruthDebtReport? {
        guard let snapshot = store.selectedSnapshot else { return nil }
        return TruthDebtEngine().report(
            snapshot: snapshot,
            evidence: store.evidence(for: project.id),
            risks: store.risks(for: project.id),
            assumptions: store.assumptions(for: project.id)
        )
    }

    private func truthDebtColor(_ status: TruthDebtStatus) -> Color {
        switch status {
        case .blocked: .red
        case .caveated: .orange
        case .defensible: .green
        }
    }

    private func truthDebtSymbol(_ status: TruthDebtStatus) -> String {
        switch status {
        case .blocked: "exclamationmark.triangle.fill"
        case .caveated: "exclamationmark.circle.fill"
        case .defensible: "checkmark.shield.fill"
        }
    }

    private func header(project: ProjectContext, board: ReleaseReadinessBoard) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Release Readiness — \(project.name)")
                .font(.system(size: 30, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(board.headline)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 8) {
                StatusBadge(status: board.status)
                CountTag(label: "Verified", count: board.counts.verified, color: .green)
                CountTag(label: "Failed", count: board.counts.failed, color: .red)
                CountTag(label: "In Progress", count: board.counts.inProgress, color: .blue)
                CountTag(label: "Unknown", count: board.counts.unknown, color: .gray)
                if board.criticalRemaining > 0 {
                    CountTag(label: "Critical Open", count: board.criticalRemaining, color: .red)
                }
                if board.highRemaining > 0 {
                    CountTag(label: "High Open", count: board.highRemaining, color: .orange)
                }
            }
        }
    }

    private func prioritySection(priority: VerificationPriority, rows: [ReleaseAreaStatus]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: priority.symbolName)
                    .foregroundStyle(priorityColor(priority))
                Text(priority.rawValue.uppercased())
                    .font(.caption.weight(.bold))
                    .tracking(0.8)
                    .foregroundStyle(priorityColor(priority))
                Spacer()
                Text("\(rows.filter { $0.state == .verified }.count)/\(rows.count) verified")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            ForEach(rows) { row in
                Row(row: row)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func copyButton(project: ProjectContext, board: ReleaseReadinessBoard) -> some View {
        HStack {
            Spacer()
            Button {
                copyMarkdown(project: project, board: board)
            } label: {
                Label("Copy Release Brief", systemImage: "doc.on.doc")
            }
        }
    }

    private func copyMarkdown(project: ProjectContext, board: ReleaseReadinessBoard) {
        var lines: [String] = []
        lines.append("# Release Readiness — \(project.name)")
        lines.append("")
        lines.append("**Status:** \(board.status.rawValue)")
        lines.append("**Summary:** \(board.headline)")
        lines.append("")
        for group in board.rowsByPriority where !group.rows.isEmpty {
            lines.append("## \(group.priority.rawValue)")
            for row in group.rows {
                let symbol: String
                switch row.state {
                case .verified: symbol = "✓"
                case .failed: symbol = "✗"
                case .inProgress: symbol = "↻"
                case .unknown: symbol = "?"
                }
                var line = "- \(symbol) \(row.area)"
                if !row.ageDescription.isEmpty { line += " — \(row.ageDescription)" }
                if !row.blockedBy.isEmpty { line += " · blocked by \(row.blockedBy.joined(separator: ", "))" }
                lines.append(line)
            }
            lines.append("")
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(lines.joined(separator: "\n"), forType: .string)
    }

    private func priorityColor(_ p: VerificationPriority) -> Color {
        switch p {
        case .critical: .red
        case .high: .orange
        case .medium: .blue
        case .low: .gray
        }
    }
}

private struct Row: View {
    var row: ReleaseAreaStatus

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: row.state.symbolName)
                .foregroundStyle(stateColor)
                .font(.title3)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(row.area)
                        .font(.system(size: 16, weight: .semibold))
                    Text(row.state.rawValue)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(stateColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(stateColor)
                    if !row.ageDescription.isEmpty, row.state == .verified {
                        Text(row.ageDescription)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                if !row.blockedBy.isEmpty {
                    Text("Blocked by: \(row.blockedBy.joined(separator: ", "))")
                        .font(.system(size: 13))
                        .foregroundStyle(.orange)
                }
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
    }

    private var stateColor: Color {
        switch row.state {
        case .verified: .green
        case .failed: .red
        case .inProgress: .blue
        case .unknown: .gray
        }
    }
}

private struct StatusBadge: View {
    var status: ReleaseReadinessStatus

    private var color: Color {
        switch status {
        case .ready: .green
        case .readyWithCaveats: .blue
        case .notReady: .orange
        case .blocked: .red
        case .unknown: .gray
        }
    }

    var body: some View {
        Text(status.rawValue.uppercased())
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct CountTag: View {
    var label: String
    var count: Int
    var color: Color

    var body: some View {
        HStack(spacing: 4) {
            Text("\(count)")
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 5)
        .background(color.opacity(0.14), in: Capsule())
    }
}
