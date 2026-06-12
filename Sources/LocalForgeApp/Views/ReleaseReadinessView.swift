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
                        next: board.status == .ready ? "Treat this as a local-evidence summary, then review the release brief and keep evidence attached before distribution." : "Work through critical and high-priority rows first, then attach or promote supporting evidence.",
                        safety: "This screen is read-only. It summarises records already stored in LocalForge and does not notarise, upload, sign, or change the project.",
                        example: "Example: Build passed, but preset restore remains unknown, so release confidence stays limited.",
                        symbol: "flag.checkered",
                        tint: .orange
                    )
                    truthDebtPanel(project: project)
                    releaseTrustCuePanel(board: board)
                    if board.rows.isEmpty {
                        ContentUnavailableView(
                            "No in-scope areas",
                            systemImage: "flag.checkered",
                            description: Text("Set the project mission and run the Setup Wizard so LocalForge knows what to release-check.")
                        )
                    } else {
                        ForEach(board.rowsByPriority, id: \.priority) { group in
                            if !group.rows.isEmpty {
                                prioritySection(priority: group.priority, rows: group.rows, board: board)
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
        let blockerPreview: [TruthDebtGate] = Array((report?.blockers ?? []).prefix(2))
        let caveatPreview: [TruthDebtGate] = Array((report?.caveats ?? []).prefix(2))

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
                if !blockerPreview.isEmpty || !caveatPreview.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach(blockerPreview) { gate in
                            GateSnippet(label: "Blocker", text: gate.title, color: .red)
                        }
                        ForEach(caveatPreview) { gate in
                            GateSnippet(label: "Caveat", text: gate.title, color: .orange)
                        }
                    }
                    .padding(.top, 2)
                }
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
        let columns = [GridItem(.adaptive(minimum: 104), spacing: 8, alignment: .leading)]

        return VStack(alignment: .leading, spacing: 10) {
            Text("Release Readiness — \(project.name)")
                .font(.system(size: 30, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(board.headline)
                .font(.system(size: 15))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            LazyVGrid(columns: columns, alignment: .leading, spacing: 8) {
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
                if !board.riskBlockers.isEmpty {
                    CountTag(label: "Risk Blockers", count: board.riskBlockers.count, color: .red)
                }
            }
            Text("Local evidence only. This board does not approve, notarise, sign, upload, or ship a release.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func releaseTrustCuePanel(board: ReleaseReadinessBoard) -> some View {
        let blockerItems = board.blockers.map { "Verification: \($0)" } + board.riskBlockers.map { "Risk: \($0)" }
        let caveatItems = Array(board.caveats.prefix(3))
        let evidenceGapRows = evidenceGapRows(in: board)
        let evidenceGapItems = evidenceGapRows.prefix(3).map { "\($0.area) is \($0.state.rawValue)" }
        let columns = [GridItem(.adaptive(minimum: 138), spacing: 12, alignment: .leading)]

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Local Trust Cues")
                    .font(.system(size: 16, weight: .semibold))
                Spacer(minLength: 12)
                Text("Evidence-bound")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: columns, alignment: .leading, spacing: 10) {
                TrustCueMetric(
                    title: "Critical gates",
                    value: gateValue(board.criticalRemaining),
                    detail: board.criticalRemaining == 0 ? "Clear in local records" : "Need verified evidence",
                    symbol: board.criticalRemaining == 0 ? "checkmark.shield" : "exclamationmark.octagon",
                    color: board.criticalRemaining == 0 ? .green : .red
                )
                TrustCueMetric(
                    title: "High gates",
                    value: gateValue(board.highRemaining),
                    detail: board.highRemaining == 0 ? "Clear in local records" : "Need verified evidence",
                    symbol: board.highRemaining == 0 ? "checkmark.shield" : "exclamationmark.triangle",
                    color: board.highRemaining == 0 ? .green : .orange
                )
                TrustCueMetric(
                    title: "Evidence gaps",
                    value: "\(evidenceGapRows.count)",
                    detail: evidenceGapRows.isEmpty ? "No Unknown/In Progress rows" : "Unknown/In Progress rows",
                    symbol: evidenceGapRows.isEmpty ? "checkmark.circle" : "questionmark.circle",
                    color: evidenceGapRows.isEmpty ? .green : .gray
                )
                TrustCueMetric(
                    title: "Blockers",
                    value: "\(blockerItems.count)",
                    detail: blockerItems.isEmpty ? "None in local records" : "Verification or risk",
                    symbol: blockerItems.isEmpty ? "checkmark.circle" : "exclamationmark.octagon",
                    color: blockerItems.isEmpty ? .green : .red
                )
                TrustCueMetric(
                    title: "Caveats",
                    value: "\(board.caveats.count)",
                    detail: board.caveats.isEmpty ? "No caveats recorded" : "Require qualified claims",
                    symbol: board.caveats.isEmpty ? "checkmark.circle" : "exclamationmark.triangle",
                    color: board.caveats.isEmpty ? .green : .orange
                )
            }

            if !blockerItems.isEmpty || !caveatItems.isEmpty || !evidenceGapItems.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    if !blockerItems.isEmpty {
                        TrustCueList(title: "Blockers to resolve", items: blockerItems, color: .red, symbol: "exclamationmark.octagon.fill")
                    }
                    if !caveatItems.isEmpty {
                        TrustCueList(title: "Caveats to carry", items: caveatItems, color: .orange, symbol: "exclamationmark.triangle.fill")
                    }
                    if !evidenceGapItems.isEmpty {
                        TrustCueList(title: "Evidence gaps", items: evidenceGapItems, color: .gray, symbol: "questionmark.circle.fill")
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func evidenceGapRows(in board: ReleaseReadinessBoard) -> [ReleaseAreaStatus] {
        board.rows.filter { $0.state == .unknown || $0.state == .inProgress }
    }

    private func gateValue(_ count: Int) -> String {
        count == 0 ? "Clear" : "\(count) Open"
    }

    private func prioritySection(priority: VerificationPriority, rows: [ReleaseAreaStatus], board: ReleaseReadinessBoard) -> some View {
        let openGateCount = criticalHighOpenCount(for: priority, board: board)

        return VStack(alignment: .leading, spacing: 8) {
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
            if let openGateCount {
                GateStatusLine(priority: priority, openCount: openGateCount, color: openGateCount == 0 ? .green : priorityColor(priority))
            }
            ForEach(rows) { row in
                Row(row: row)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func criticalHighOpenCount(for priority: VerificationPriority, board: ReleaseReadinessBoard) -> Int? {
        switch priority {
        case .critical: board.criticalRemaining
        case .high: board.highRemaining
        case .medium, .low: nil
        }
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
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(row.area)
                        .font(.system(size: 16, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(row.state.rawValue)
                        .font(.caption.weight(.bold))
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(stateColor.opacity(0.16), in: Capsule())
                        .foregroundStyle(stateColor)
                    if row.state == .failed {
                        CuePill(text: "Blocker", color: .red)
                    }
                    if gateIsOpen {
                        CuePill(text: "\(row.priority.rawValue) gate open", color: priorityColor)
                    }
                    if hasEvidenceGap {
                        CuePill(text: "Evidence gap", color: .gray)
                    }
                    if !row.blockedBy.isEmpty {
                        CuePill(text: "Dependency blocked", color: .orange)
                    }
                    if !row.ageDescription.isEmpty, row.state == .verified {
                        Text(row.ageDescription)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                if hasEvidenceGap {
                    Text("Local records show \(row.state.rawValue.lowercased()), not verified release evidence.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !row.blockedBy.isEmpty {
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Image(systemName: "arrow.triangle.branch")
                            .font(.caption)
                        Text("Blocked by: \(row.blockedBy.joined(separator: ", "))")
                            .font(.system(size: 13))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .foregroundStyle(.orange)
                }
                if row.state == .failed {
                    Text("Failed local verification blocks a release-ready claim for this area.")
                        .font(.system(size: 13))
                        .foregroundStyle(.red)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer()
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(rowBackground, in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            RoundedRectangle(cornerRadius: 8)
                .stroke(rowBorderColor.opacity(rowBorderOpacity), lineWidth: 1)
        }
    }

    private var gateIsOpen: Bool {
        (row.priority == .critical || row.priority == .high) && (row.state != .verified || !row.blockedBy.isEmpty)
    }

    private var hasEvidenceGap: Bool {
        row.state == .unknown || row.state == .inProgress
    }

    private var priorityColor: Color {
        switch row.priority {
        case .critical: .red
        case .high: .orange
        case .medium: .blue
        case .low: .gray
        }
    }

    private var rowBackground: Color {
        if row.state == .failed { return Color.red.opacity(0.07) }
        if !row.blockedBy.isEmpty { return Color.orange.opacity(0.07) }
        if gateIsOpen { return priorityColor.opacity(0.06) }
        if hasEvidenceGap { return Color.secondary.opacity(0.07) }
        return Color.secondary.opacity(0.06)
    }

    private var rowBorderColor: Color {
        if row.state == .failed { return .red }
        if !row.blockedBy.isEmpty { return .orange }
        if gateIsOpen { return priorityColor }
        return .secondary
    }

    private var rowBorderOpacity: Double {
        if row.state == .failed || !row.blockedBy.isEmpty || gateIsOpen { return 0.36 }
        return 0
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

private struct GateStatusLine: View {
    var priority: VerificationPriority
    var openCount: Int
    var color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: openCount == 0 ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.caption)
                .foregroundStyle(color)
            Text(message)
                .font(.caption.weight(.semibold))
                .foregroundStyle(color)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 5)
        .background(color.opacity(0.12), in: Capsule())
    }

    private var message: String {
        if openCount == 0 {
            return "\(priority.rawValue) gate clear in local records."
        }
        return "\(openCount) \(priority.rawValue) gate\(openCount == 1 ? "" : "s") need verified, fresh, unblocked evidence."
    }
}

private struct GateSnippet: View {
    var label: String
    var text: String
    var color: Color

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(color)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }
}

private struct TrustCueMetric: View {
    var title: String
    var value: String
    var detail: String
    var symbol: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(value)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }
}

private struct TrustCueList: View {
    var title: String
    var items: [String]
    var color: Color
    var symbol: String

    var body: some View {
        let visibleItems = Array(items.prefix(3))

        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Image(systemName: symbol)
                    .font(.caption)
                    .foregroundStyle(color)
                Text(title)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(color)
            }
            ForEach(visibleItems, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle()
                        .fill(color.opacity(0.75))
                        .frame(width: 4, height: 4)
                    Text(item)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
            }
            if items.count > visibleItems.count {
                Text("+ \(items.count - visibleItems.count) more")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }
}

private struct CuePill: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text.uppercased())
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
            .lineLimit(1)
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
        Text("LOCAL \(status.rawValue.uppercased())")
            .font(.caption.weight(.bold))
            .tracking(0.8)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
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
