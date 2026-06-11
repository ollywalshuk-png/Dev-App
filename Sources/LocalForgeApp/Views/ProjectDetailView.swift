import LocalForgeCore
import SwiftUI

struct ProjectDetailView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        if let project = store.selectedProject {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 10) {
                            Text(project.name)
                                .font(.title2.weight(.semibold))
                            if let snapshot = store.selectedSnapshot {
                                ProjectKindBadge(identity: snapshot.identity)
                                HealthPill(health: ProjectHealth.resolve(project: project, snapshot: snapshot))
                            }
                        }
                        Text(project.rootURL.path)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                    Spacer()
                    Button(role: .destructive) {
                        store.revoke(project)
                    } label: {
                        Label("Remove Access", systemImage: "xmark.circle")
                    }
                }

                AccessStateView(project: project)

                if let snapshot = store.selectedSnapshot {
                    IdentityCard(identity: snapshot.identity)
                    MissionCard(mission: snapshot.mission, reality: snapshot.reality)
                    GitCard(git: snapshot.git)
                    SnapshotSummaryView(snapshot: snapshot)
                    FindingsView(findings: snapshot.findings)
                    EvidenceView(evidence: snapshot.evidence)
                } else {
                    ContentUnavailableView("No Scan Yet", systemImage: "hourglass", description: Text("Run a read-only scan to populate project truth."))
                }
            }
        } else {
            ContentUnavailableView("Open Repository", systemImage: "folder.badge.plus", description: Text("LocalForge analyses only folders you explicitly approve."))
        }
    }
}

private struct IdentityCard: View {
    var identity: ProjectIdentity

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Project Recognition", systemImage: "sparkle.magnifyingglass")
                    .font(.headline)
                Spacer()
                Text(identity.confidence.rawValue)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            HStack(spacing: 10) {
                Image(systemName: identity.kind.symbolName)
                    .font(.title)
                    .foregroundStyle(identity.kind.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(identity.kind.rawValue)
                        .font(.title3.weight(.semibold))
                    if !identity.ecosystems.isEmpty {
                        Text(identity.ecosystems.joined(separator: " · "))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            Text(identity.detail)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if !identity.markers.isEmpty {
                Text("Markers: \(identity.markers.joined(separator: ", "))")
                    .font(.caption.monospaced())
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct MissionCard: View {
    var mission: MissionProfile
    var reality: RealityAssessment

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Mission & Reality", systemImage: "scope")
                    .font(.headline)
                Spacer()
                RealityScoreBadge(score: reality.score)
                    .scaleEffect(0.7)
                    .frame(width: 64, height: 64)
            }
            Text(mission.statedMission)
                .font(.title3.weight(.semibold))
            Text("\(mission.rationale) [\(mission.confidence.rawValue)]")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()
            EvidenceBucket(title: "Known facts", items: reality.knownFacts, color: .green)
            EvidenceBucket(title: "Unverified (in scope)", items: reality.unverified, color: .orange)
            EvidenceBucket(title: "Assumptions", items: reality.assumptions, color: .blue)
            EvidenceBucket(title: "Unknowns", items: reality.unknowns, color: .gray)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EvidenceBucket: View {
    var title: String
    var items: [String]
    var color: Color

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(title) (\(items.count))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(color)
                ForEach(items.prefix(6), id: \.self) { item in
                    Text("• \(item)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct GitCard: View {
    var git: GitStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Git (read-only)", systemImage: "arrow.branch")
                .font(.headline)

            if git.isRepository {
                Grid(alignment: .leading, horizontalSpacing: 24, verticalSpacing: 8) {
                    GridRow {
                        GitCell(label: "Branch", value: git.branchDisplay)
                        GitCell(label: "Working tree", value: git.workingTreeSummary)
                    }
                    GridRow {
                        if git.hasUpstream {
                            GitCell(label: "Upstream", value: "\(git.ahead) ahead, \(git.behind) behind")
                        } else {
                            GitCell(label: "Upstream", value: "none tracked")
                        }
                        if let hash = git.lastCommitShortHash {
                            GitCell(label: "Last commit", value: "\(hash) \(git.lastCommitRelative ?? "")")
                        }
                    }
                }
                if let subject = git.lastCommitSubject {
                    Text("“\(subject)”\(git.lastCommitAuthor.map { " — \($0)" } ?? "")")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            } else {
                Text(git.note ?? "This folder is not a Git working tree.")
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct GitCell: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
        }
    }
}

private struct AccessStateView: View {
    var project: ProjectContext

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(project.permission.state.rawValue, systemImage: project.bookmarkStatus.requiresAttention ? "exclamationmark.triangle" : "lock.open")
                    .font(.headline)
                    .foregroundStyle(project.bookmarkStatus.requiresAttention ? .orange : .green)
                Spacer()
                Text(project.bookmarkStatus.displayName)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
            Text(project.permission.description)
                .foregroundStyle(.secondary)
            Text("LocalForge will observe and report only. It will not modify this repository in V1.")
                .foregroundStyle(.secondary)
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SnapshotSummaryView: View {
    var snapshot: RepoSnapshot

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 10) {
            GridRow {
                SummaryCell(label: "Files", value: "\(snapshot.summary.totalFiles)")
                SummaryCell(label: "Source", value: "\(snapshot.summary.sourceFiles)")
                SummaryCell(label: "Tests", value: "\(snapshot.summary.testFiles)")
                SummaryCell(label: "Docs", value: "\(snapshot.summary.documentationFiles)")
                SummaryCell(label: "Large", value: "\(snapshot.summary.largeFiles)")
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct SummaryCell: View {
    var label: String
    var value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.semibold))
        }
        .frame(minWidth: 92, alignment: .leading)
    }
}

private struct FindingsView: View {
    var findings: [Finding]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Findings")
                .font(.title3.weight(.semibold))
            ForEach(findings) { finding in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(finding.title)
                            .font(.headline)
                        Spacer()
                        Text(finding.evidenceClassification.rawValue)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.quaternary, in: Capsule())
                    }
                    Text(finding.detail)
                        .foregroundStyle(.secondary)
                    Text("\(finding.category.rawValue) / \(finding.severity.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

private struct EvidenceView: View {
    var evidence: [Evidence]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Evidence")
                .font(.title3.weight(.semibold))
            ForEach(evidence) { item in
                HStack(alignment: .top) {
                    Image(systemName: "checkmark.seal")
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.title)
                        Text("\(item.classification.rawValue): \(item.detail)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
