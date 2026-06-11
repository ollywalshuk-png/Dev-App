import LocalForgeCore
import SwiftUI

struct WorkspaceDashboard: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if store.projects.isEmpty {
                EmptyWorkspacePanel {
                    store.openRepositoryPanel()
                }
                ExplanationCard(
                    title: "Suggested first workflow",
                    what: "LocalForge starts with one approved project folder and builds a local picture of its mission, verification, evidence, risks, and release state.",
                    why: "A build tracker is only useful when it knows which project you mean and can separate facts from guesses.",
                    next: "Open a repository, complete the Project Setup Wizard, then verify one important area.",
                    safety: "Opening a repository grants read access to that folder only. LocalForge does not upload source code or modify the project during the scan.",
                    example: "Project -> Mission -> Verification -> Evidence -> Reality -> Release -> Handoff",
                    symbol: "map",
                    tint: .green
                )
                SystemSafetyPanel()
            } else {
                if store.projects.count > 1 {
                    CrossProjectInsightsPanel(insights: store.workspaceInsights, store: store)
                }
                if store.selectedProject != nil {
                    CommandCentreView(store: store)
                    if let snapshot = store.selectedSnapshot {
                        ApplicabilityPanel(items: snapshot.applicability)
                    }
                }
                ProjectListPanel(store: store)
                WorkspaceCountsRow(counts: store.workspaceCounts, scanMode: store.scanMode)
                PosturePanel()
                SystemSafetyPanel()
            }
        }
    }
}

private struct CrossProjectInsightsPanel: View {
    var insights: WorkspaceInsights
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        let truth = store.workspaceTruth
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Portfolio")
                    .font(.system(size: 22, weight: .semibold))
                Spacer()
                Button {
                    store.selectedModule = .search
                } label: {
                    Label("Search everything", systemImage: "magnifyingglass")
                        .font(.caption)
                }
                Text("Across \(insights.totalProjects) projects")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                StatCell(label: "Projects", value: "\(insights.totalProjects)", color: .blue)
                StatCell(label: "Healthy", value: "\(insights.healthyCount)", color: .green)
                StatCell(label: "Attention", value: "\(insights.attentionCount)", color: .orange)
                StatCell(label: "Blocked", value: "\(insights.blockedCount)", color: insights.blockedCount > 0 ? .red : .gray)
                StatCell(label: "Open Risks", value: "\(truth.openRisks)", color: truth.openRisks > 0 ? .red : .gray)
                StatCell(label: "Critical Risks", value: "\(truth.criticalOpenRisks)", color: truth.criticalOpenRisks > 0 ? .red : .gray)
                StatCell(label: "Evidence", value: "\(truth.evidenceRecords)", color: .indigo)
                StatCell(label: "Journal", value: "\(truth.journalEntries)", color: .teal)
                StatCell(label: "Assumptions", value: "\(truth.activeAssumptions)", color: truth.activeAssumptions > 0 ? .orange : .gray)
                StatCell(label: "Stale Verified", value: "\(truth.staleVerifications)", color: truth.staleVerifications > 0 ? .orange : .gray)
            }
            HStack(spacing: 10) {
                InsightTile(title: "Highest Risk", project: insights.highestRisk, color: .red, jumpTo: store)
                InsightTile(title: "Most Complete", project: insights.mostComplete, color: .green, jumpTo: store)
                InsightTile(title: "Least Verified", project: insights.leastVerified, color: .orange, jumpTo: store)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct InsightTile: View {
    var title: String
    var project: ProjectInsightSummary?
    var color: Color
    @ObservedObject var jumpTo: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            if let project {
                Button {
                    if let p = jumpTo.projects.first(where: { $0.id == project.id }) {
                        jumpTo.selectProject(p)
                    }
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(project.name)
                            .font(.system(size: 17, weight: .semibold))
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                        HStack(spacing: 8) {
                            Text("Reality \(project.realityScore)%")
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(color.opacity(0.16), in: Capsule())
                                .foregroundStyle(color)
                            Text("\(project.verified)/\(project.totalTracked) verified")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(project.topRisk)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .buttonStyle(.plain)
            } else {
                Text("Not enough data")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .topLeading)
        .padding(10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct WorkspaceCountsRow: View {
    var counts: WorkspaceCounts
    var scanMode: ScanMode

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 150), spacing: 12)], spacing: 12) {
            MetricTile(title: "Projects", value: "\(counts.total)", symbol: "folder")
            MetricTile(title: "Healthy", value: "\(counts.healthy)", symbol: "checkmark.seal", color: .green)
            MetricTile(title: "Warnings", value: "\(counts.warning)", symbol: "exclamationmark.triangle", color: .yellow)
            MetricTile(title: "Critical", value: "\(counts.critical)", symbol: "xmark.octagon", color: .red)
            MetricTile(title: "Active Scans", value: "\(counts.activeScans)", symbol: "dot.radiowaves.left.and.right", color: .blue)
            MetricTile(title: "Scan Mode", value: scanMode.rawValue, symbol: "slider.horizontal.3")
        }
    }
}

private struct ApplicabilityPanel: View {
    var items: [ApplicabilityItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What Matters Here")
                .font(.title2.weight(.semibold))
            Text("Which checks are in scope for this project type. LocalForge will not flag areas marked Not Applicable.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 8)], spacing: 8) {
                ForEach(items) { item in
                    HStack {
                        Text(item.area)
                            .font(.callout)
                        Spacer()
                        Text(item.status.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(color(item.status))
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(color(item.status).opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func color(_ status: ApplicabilityStatus) -> Color {
        switch status {
        case .required: .red
        case .expected: .orange
        case .optional: .blue
        case .unknown: .gray
        case .notApplicable: Color(nsColor: .tertiaryLabelColor)
        }
    }
}

private struct EmptyWorkspacePanel: View {
    var openRepository: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Open your first repository", systemImage: "folder.badge.plus")
                .font(.title2.weight(.semibold))
            Text("LocalForge analyses only folders you explicitly open. Pick a project's root folder and LocalForge will recognise what it is, read its Git state, and remember it for next launch.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                StepRow(number: 1, text: "Click **Open Repository** and choose the project's root folder (the one containing the .xcodeproj, Package.swift, or .git).")
                StepRow(number: 2, text: "LocalForge auto-detects the project type — Xcode app, Swift package, AUv3 plugin, Node, Python, and more.")
                StepRow(number: 3, text: "The active project shows in the sidebar and tab strip. Switch projects there; each keeps its own isolated state.")
            }

            HStack {
                Button(action: openRepository) {
                    Label("Open Repository", systemImage: "folder.badge.plus")
                }
                .buttonStyle(.borderedProminent)
                Text("Read-only scan · no cloud · no telemetry.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Text("LocalForge will not run builds, change code, commit, push, delete files, or scan your whole disk from this step.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct StepRow: View {
    var number: Int
    var text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(number)")
                .font(.caption.weight(.bold))
                .frame(width: 20, height: 20)
                .background(Color.accentColor.opacity(0.2), in: Circle())
            Text(.init(text))
                .font(.callout)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct ProjectListPanel: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Approved Projects")
                    .font(.title2.weight(.semibold))
                Spacer()
                Button {
                    store.openRepositoryPanel()
                } label: {
                    Label("Add", systemImage: "plus")
                }
            }

            if store.projects.isEmpty {
                Text("No approved folders yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.projects) { project in
                    let snapshot = store.snapshots[project.id]
                    let kind = snapshot?.identity.kind ?? .unidentified
                    Button {
                        store.selectProject(project)
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: kind.symbolName)
                                .font(.title3)
                                .foregroundStyle(kind.tint)
                                .frame(width: 28)
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 8) {
                                    Text(project.name)
                                        .font(.headline)
                                    if let snapshot {
                                        ProjectKindBadge(identity: snapshot.identity, compact: true)
                                    }
                                }
                                Text(project.rootURL.path)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                if let snapshot {
                                    GitChip(git: snapshot.git)
                                }
                            }
                            Spacer()
                            VStack(alignment: .trailing, spacing: 5) {
                                HealthPill(health: ProjectHealth.resolve(project: project, snapshot: snapshot))
                                Text(project.bookmarkStatus.displayName)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding()
                        .background(project.id == store.selectedProjectID ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct PosturePanel: View {
    private let cards: [(String, String, String, Color)] = [
        ("Repository", "Read-only Git intelligence", "arrow.branch", .green),
        ("Build", "Foundation — not yet analysed", "hammer", .gray),
        ("Verification", "Unknown is never shown green", "checkmark.seal", .gray),
        ("Security", "Redaction on reports", "lock.shield", .green),
        ("Privacy", "Local-first, opt-in only", "hand.raised", .green),
        ("Commercial", "No mandatory runtime cost", "checkmark.circle", .green)
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Posture")
                .font(.title2.weight(.semibold))
            Text("Honest V1 status. Foundation cards are stubs surfaced openly, not faked.")
                .font(.caption)
                .foregroundStyle(.secondary)
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 200), spacing: 12)], spacing: 12) {
                ForEach(cards, id: \.0) { card in
                    VStack(alignment: .leading, spacing: 6) {
                        Label(card.0, systemImage: card.2)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(card.3)
                        Text(card.1)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SystemSafetyPanel: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("System Safety")
                .font(.title2.weight(.semibold))
            SafetyRow(title: "Default mode", value: "Read-only", symbol: "eye")
            SafetyRow(title: "Cloud AI", value: "Off by default", symbol: "icloud.slash")
            SafetyRow(title: "Telemetry", value: "Off by default", symbol: "antenna.radiowaves.left.and.right.slash")
            SafetyRow(title: "Heavy scans", value: "Manual", symbol: "hand.raised")
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MetricTile: View {
    var title: String
    var value: String
    var symbol: String
    var color: Color = .blue

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: symbol)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, minHeight: 86, alignment: .leading)
        .padding()
        .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SafetyRow: View {
    var title: String
    var value: String
    var symbol: String

    var body: some View {
        HStack {
            Label(title, systemImage: symbol)
            Spacer()
            Text(value)
                .foregroundStyle(.secondary)
        }
    }
}
