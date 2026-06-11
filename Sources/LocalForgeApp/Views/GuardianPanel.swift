import AppKit
import LocalForgeCore
import SwiftUI

struct GuardianPanel: View {
    @ObservedObject var store: WorkspaceStore

    private let promptForge = PromptForgeEngine()
    private var recommendation: GuardianRecommendation { store.guardianRecommendation }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Developer Guardian")
                    .font(.title2.weight(.semibold))

                ExplanationCard(
                    title: "Guardian",
                    what: "Guardian turns the current project state into one focused risk, impact, and next action.",
                    why: "It helps you avoid scanning every panel when one failed, stale, or unknown area deserves attention first.",
                    next: recommendation.suggestedAction.isEmpty ? recommendation.nextAction : recommendation.suggestedAction,
                    safety: "Guardian recommends and explains. It does not invent evidence, change files, or run fixes.",
                    symbol: "shield.lefthalf.filled",
                    tint: .blue
                )

                ActiveProjectCard(project: store.selectedProject, snapshot: store.selectedSnapshot)

                Label(recommendation.mode, systemImage: "shield.lefthalf.filled")
                    .font(.callout.weight(.medium))
                    .foregroundStyle(.blue)

                topIssueCard

                if let snapshot = store.selectedSnapshot {
                    verificationStrip(snapshot)
                }

                copyActions

                safetyState

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .frame(minWidth: 320, idealWidth: 360, maxWidth: 400, maxHeight: .infinity, alignment: .topLeading)
    }

    // MARK: - Top issue (Top Issue · Status · Evidence · Impact · Suggested Action)

    private var topIssueCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Circle()
                    .fill(riskColor(recommendation.riskLevel))
                    .frame(width: 10, height: 10)
                Text("Top Issue")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(recommendation.riskLevel.rawValue.uppercased())
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(riskColor(recommendation.riskLevel).opacity(0.18), in: Capsule())
                    .foregroundStyle(riskColor(recommendation.riskLevel))
            }
            Text(recommendation.topIssue)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if !recommendation.area.isEmpty || !recommendation.status.isEmpty || recommendation.priority != nil {
                HStack(spacing: 6) {
                    if !recommendation.area.isEmpty { Tag(text: recommendation.area, color: .blue) }
                    if !recommendation.status.isEmpty { Tag(text: recommendation.status, color: riskColor(recommendation.riskLevel)) }
                    if let p = recommendation.priority {
                        Tag(text: p.rawValue, color: priorityColor(p))
                    }
                    if !recommendation.verifiedBy.isEmpty { Tag(text: "by \(recommendation.verifiedBy)", color: .gray) }
                }
            }

            DetailBlock(label: "Evidence", value: recommendation.evidence)
            if !recommendation.impact.isEmpty {
                DetailBlock(label: "Impact", value: recommendation.impact)
            }
            if let observed = recommendation.lastObservedAt {
                DetailBlock(label: "Last Observed", value: observed.formatted(date: .abbreviated, time: .shortened), compact: true)
            }
            if !recommendation.blockedBy.isEmpty {
                DetailBlock(label: "Blocked By", value: recommendation.blockedBy.joined(separator: " · "))
            }
            DetailBlock(label: "Suggested Action", value: recommendation.suggestedAction.isEmpty ? recommendation.nextAction : recommendation.suggestedAction)
            HStack(spacing: 12) {
                DetailBlock(label: "Confidence", value: recommendation.confidence.rawValue, compact: true)
                if recommendation.estimatedEffortMinutes > 0 {
                    DetailBlock(label: "Estimated Effort", value: "\(recommendation.estimatedEffortMinutes) min", compact: true)
                }
            }
            if !recommendation.recentActivity.isEmpty || recommendation.linkedJournalCount > 0 || recommendation.linkedNotesCount > 0 {
                Divider().padding(.vertical, 2)
                HStack(spacing: 8) {
                    Text("LATEST ACTIVITY")
                        .font(.caption2.weight(.bold))
                        .tracking(0.6)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if recommendation.linkedJournalCount > 0 {
                        Text("\(recommendation.linkedJournalCount) journal · \(recommendation.linkedNotesCount) note")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                if recommendation.recentActivity.isEmpty {
                    Text("No journal entries reference this area yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(recommendation.recentActivity.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(.tertiary)
                                .padding(.top, 6)
                            Text(line)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func verificationStrip(_ snapshot: RepoSnapshot) -> some View {
        let s = snapshot.verificationSummary
        return VStack(alignment: .leading, spacing: 6) {
            Text("Verification")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            HStack(spacing: 6) {
                MiniCount(count: s.verified, label: "✓", color: .green)
                MiniCount(count: s.inProgress, label: "↻", color: .blue)
                MiniCount(count: s.failed, label: "✕", color: .red)
                MiniCount(count: s.unknown, label: "?", color: .gray)
                Spacer()
                Button {
                    store.selectedModule = .verification
                } label: {
                    Image(systemName: "arrow.right.circle")
                }
                .buttonStyle(.borderless)
                .help("Open Verification")
            }
        }
        .padding(10)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var copyActions: some View {
        VStack(spacing: 6) {
            Button {
                copyRecommendation()
            } label: {
                Label("Copy Guardian Summary", systemImage: "doc.on.doc")
                    .frame(maxWidth: .infinity)
            }
            Button {
                copyFixProposal()
            } label: {
                Label("Copy Fix Proposal", systemImage: "wrench.and.screwdriver")
                    .frame(maxWidth: .infinity)
            }
            .disabled(store.selectedSnapshot == nil)
            Button {
                store.selectedModule = .handoff
            } label: {
                Label("Open Handoff Pack", systemImage: "paperplane")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.selectedSnapshot == nil)
        }
    }

    private var safetyState: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Safety State")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            SafetyLine(text: "Read-only recommendations", symbol: "eye")
            SafetyLine(text: "Local-first", symbol: "checkmark.circle")
            SafetyLine(text: "No telemetry by default", symbol: "checkmark.circle")
            SafetyLine(text: "No cloud AI by default", symbol: "checkmark.circle")
            SafetyLine(text: "No source upload by default", symbol: "checkmark.circle")
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Actions

    private func copyRecommendation() {
        let text = """
        LocalForge Guardian
        Mode: \(recommendation.mode)
        Top Issue: \(recommendation.topIssue)
        Area: \(recommendation.area)
        Status: \(recommendation.status)
        Risk: \(recommendation.riskLevel.rawValue)
        Confidence: \(recommendation.confidence.rawValue)
        Evidence: \(recommendation.evidence)
        Impact: \(recommendation.impact)
        Suggested Action: \(recommendation.suggestedAction.isEmpty ? recommendation.nextAction : recommendation.suggestedAction)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func copyFixProposal() {
        guard let snapshot = store.selectedSnapshot, let id = store.selectedProjectID else { return }
        let text = promptForge.generate(.fixProposal, snapshot: snapshot, knowledge: store.knowledgeNotes(for: id), evidence: store.evidence(for: id))
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }

    private func priorityColor(_ p: VerificationPriority) -> Color {
        switch p {
        case .critical: .red
        case .high: .orange
        case .medium: .blue
        case .low: .gray
        }
    }

    private func riskColor(_ level: RiskLevel) -> Color {
        switch level {
        case .healthy: .green
        case .info: .blue
        case .warning: .orange
        case .critical: .red
        case .unknown: .gray
        }
    }
}

// MARK: - Components

private struct ActiveProjectCard: View {
    var project: ProjectContext?
    var snapshot: RepoSnapshot?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let project {
                HStack(spacing: 8) {
                    Image(systemName: (snapshot?.identity.kind ?? .unidentified).symbolName)
                        .foregroundStyle((snapshot?.identity.kind ?? .unidentified).tint)
                    Text(project.name)
                        .font(.title3.weight(.semibold))
                        .lineLimit(1)
                }
                if let snapshot {
                    Text(snapshot.mission.statedMission)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 6) {
                        HealthPill(health: ProjectHealth.resolve(project: project, snapshot: snapshot))
                        Text("Reality \(snapshot.reality.score)%")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                    GitChip(git: snapshot.git)
                } else {
                    Text("Scanning…")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("No active project", systemImage: "folder.badge.questionmark")
                    .font(.headline)
                Text("Open a repository to give the Guardian something to watch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.accentColor.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct DetailBlock: View {
    var label: String
    var value: String
    var compact: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .foregroundStyle(.tertiary)
                .tracking(0.6)
            Text(value)
                .font(compact ? .callout : .body)
                .textSelection(.enabled)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct MiniCount: View {
    var count: Int
    var label: String
    var color: Color

    var body: some View {
        HStack(spacing: 3) {
            Text(label).font(.caption.weight(.bold)).foregroundStyle(color)
            Text("\(count)").font(.caption.weight(.bold))
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.14), in: Capsule())
    }
}

private struct Tag: View {
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

private struct SafetyLine: View {
    var text: String
    var symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption)
            .foregroundStyle(.secondary)
    }
}
