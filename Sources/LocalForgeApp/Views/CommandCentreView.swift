import AppKit
import LocalForgeCore
import SwiftUI

/// The command-centre hero. Answers "what is actually true about this software,
/// and what should happen next?" rather than showing raw repository metrics.
struct CommandCentreView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var showingMissionEditor = false

    private var project: ProjectContext? { store.selectedProject }
    private var snapshot: RepoSnapshot? { store.selectedSnapshot }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            if let snapshot {
                commandCentreGuide(snapshot)
                cockpitStrip(snapshot)
                infoGrid(snapshot)
                statsStrip(snapshot)
                missionDetail(snapshot)
                verificationStrip(snapshot)
                buildVerificationNudge(snapshot)
                VerificationChainView(chain: snapshot.reality.chain)
                risks(snapshot.reality)
                nextAction(snapshot.reality)
            } else if let project {
                VStack(alignment: .leading, spacing: 10) {
                    Label("Scanning \(project.name)…", systemImage: "hourglass")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                    ExplanationCard(
                        title: "What happens during scan",
                        what: "LocalForge reads project metadata, project type markers, Git state, and existing LocalForge records.",
                        why: "The scan creates the starting point for mission, verification, evidence, and release tracking.",
                        next: "Wait for the scan to finish. If it returns no files, refresh repository access.",
                        safety: "Scanning is read-only and limited to the approved project folder.",
                        symbol: "eye",
                        tint: .blue
                    )
                }
            }
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showingMissionEditor) {
            if let project, let snapshot {
                MissionEditorView(
                    identity: snapshot.identity,
                    inferred: snapshot.mission,
                    existing: snapshot.userMission,
                    onSave: { mission in
                        store.setMission(mission, for: project.id)
                        showingMissionEditor = false
                    },
                    onCancel: { showingMissionEditor = false }
                )
            }
        }
    }

    private func commandCentreGuide(_ snapshot: RepoSnapshot) -> some View {
        let recordedUnverified = recordedButUnverifiedCount(snapshot)
        return ExplanationCard(
            title: "Command Centre",
            what: "This is the project control room: mission, verification, evidence, reality, risk, release state, and next action in one place.",
            why: "LocalForge avoids guessing. It shows what is verified, what failed, what is unknown, and what has only been recorded but not promoted to verification.",
            next: snapshot.userMission == nil ? "Define the project mission so every recommendation is contextual." : snapshot.reality.nextAction,
            safety: "This dashboard is read-only. It does not change your source code or repository.",
            example: "Recorded but unverified: \(recordedUnverified). These records help, but they do not make an area verified until linked or promoted as evidence.",
            symbol: "rectangle.3.group",
            tint: .blue
        )
    }

    /// Header is two rows on narrow windows: the title + reality badge on top,
    /// the action buttons + phase chip below. Title scales down before it ever
    /// wraps — no more one-letter-per-line layouts.
    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 14) {
                titleBlock
                    .layoutPriority(1)
                Spacer(minLength: 8)
                if let snapshot {
                    RealityScoreBadge(score: snapshot.reality.score)
                        .fixedSize()
                }
            }
            if let snapshot {
                accessAlertIfNeeded
                headerActions(snapshot: snapshot)
            }
        }
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("CURRENT PROJECT")
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: (snapshot?.identity.kind ?? .unidentified).symbolName)
                    .font(.system(size: 30))
                    .foregroundStyle((snapshot?.identity.kind ?? .unidentified).tint)
                    .frame(width: 36, height: 36)
                    .fixedSize()
                Text(project?.name ?? "—")
                    .font(.system(size: 36, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.4)
                    .truncationMode(.middle)
                    .allowsTightening(true)
                if let snapshot {
                    ProjectKindBadge(identity: snapshot.identity)
                        .fixedSize()
                }
            }
            if let snapshot, let phase = snapshot.userMission?.currentPhase, !phase.isEmpty {
                Text("Phase · \(phase)")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private func headerActions(snapshot: RepoSnapshot) -> some View {
        HStack(spacing: 8) {
            Button {
                showingMissionEditor = true
            } label: {
                Label(snapshot.userMission == nil ? "Define Mission" : "Edit Mission", systemImage: "scope")
            }
            Button {
                copyBrief(snapshot)
            } label: {
                Label("Copy Brief", systemImage: "doc.on.doc")
            }
            .help("Copy a reality brief for handoff to an agent or teammate")
            Button {
                store.selectedModule = .handoff
            } label: {
                Label("Open Handoff", systemImage: "paperplane")
            }
            Spacer()
        }
        .controlSize(.regular)
    }

    @ViewBuilder
    private var accessAlertIfNeeded: some View {
        if let project, project.bookmarkStatus.requiresAttention {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "lock.trianglebadge.exclamationmark")
                    .font(.title3)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Repository access needs refreshing")
                        .font(.system(size: 15, weight: .semibold))
                    Text("LocalForge could not resolve a security-scoped bookmark for this folder, so the scan returned 0 files. Re-open the repository to grant access.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button("Re-open…") {
                    store.openRepositoryPanel()
                }
                .controlSize(.regular)
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.14), in: RoundedRectangle(cornerRadius: 10))
        }
    }

    private func infoGrid(_ snapshot: RepoSnapshot) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 12)], spacing: 12) {
            InfoCell(label: "Project Type", value: snapshot.identity.kind.rawValue, tag: snapshot.identity.confidence.rawValue)
            InfoCell(label: "Mission", value: snapshot.mission.statedMission, tag: snapshot.mission.confidence.rawValue)
            InfoCell(
                label: "Current Phase",
                value: snapshot.userMission?.currentPhase.isEmpty == false ? snapshot.userMission!.currentPhase : "Not set",
                tag: snapshot.userMission == nil ? "undefined" : "defined"
            )
        }
    }

    /// Phase 6.5 Cockpit — every meaningful number visible at once. Reality,
    /// verification breakdown, knowledge, journal, last verification, release.
    /// Phase 7.5 adds the truth row: Confidence, Evidence, Open Risks, Truth Cover.
    private func cockpitStrip(_ snapshot: RepoSnapshot) -> some View {
        let s = snapshot.verificationSummary
        let notesCount = store.knowledgeNotes(for: store.selectedProjectID ?? UUID()).count
        let journalCount = store.journal(for: store.selectedProjectID).count
        let lastVerified = snapshot.verification.filter { $0.state == .verified }.map(\.updatedAt).max()
        let board = store.releaseBoard
        let confidence = store.selectedConfidence
        let evidenceCount = store.evidence(for: store.selectedProjectID).count
        let openRisks = store.risks(for: store.selectedProjectID).filter { $0.status == .open || $0.status == .monitoring }.count
        let health = store.selectedRegisterHealth
        let truthCover = Int((health.evidenceCoverage + health.riskCoverage + health.decisionCoverage
            + health.architectureCoverage + health.assumptionCoverage) / 5 * 100)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 128), spacing: 10)], spacing: 10) {
            StatCell(label: "Reality", value: "\(snapshot.reality.score)%", color: realityColor(snapshot.reality.score))
            StatCell(label: "Confidence", value: "\(confidence.score)%", color: confidenceColor(confidence.score))
            StatCell(label: "Verified", value: "\(s.verified)", color: .green)
            StatCell(label: "Failed", value: "\(s.failed)", color: s.failed > 0 ? .red : .gray)
            StatCell(label: "In Progress", value: "\(s.inProgress)", color: .blue)
            StatCell(label: "Unknown", value: "\(s.unknown)", color: .gray)
            StatCell(label: "Recorded", value: "\(recordedButUnverifiedCount(snapshot))", color: .orange)
            StatCell(label: "Evidence", value: "\(evidenceCount)", color: .indigo)
            StatCell(label: "Open Risks", value: "\(openRisks)", color: openRisks > 0 ? .red : .gray)
            StatCell(label: "Truth Cover", value: "\(truthCover)%", color: truthCover >= 60 ? .green : .orange)
            StatCell(label: "Knowledge", value: "\(notesCount)", color: .orange)
            StatCell(label: "Journal", value: "\(journalCount)", color: .indigo)
            StatCell(label: "Last Verified", value: lastVerified.map { relative($0) } ?? "—", color: .blue)
            StatCell(label: "Release", value: board?.status.rawValue ?? "—", color: releaseColor(board?.status))
        }
    }

    private func recordedButUnverifiedCount(_ snapshot: RepoSnapshot) -> Int {
        let projectID = store.selectedProjectID
        let verifiedAreas = Set(snapshot.verification.filter { $0.state == .verified }.map { $0.area.lowercased() })
        let buildRecorded = store.buildHistory(for: projectID).filter { record in
            record.result == .success && !record.linkedVerificationAreas.contains { verifiedAreas.contains($0.lowercased()) }
        }.count
        let testRecorded = store.testRecords(for: projectID).filter { record in
            record.outcome == .passed && !verifiedAreas.contains(record.linkedVerificationArea.lowercased())
        }.count
        return buildRecorded + testRecorded
    }

    private func confidenceColor(_ score: Int) -> Color {
        switch score {
        case 80...: .green
        case 55..<80: .blue
        case 30..<55: .orange
        default: .red
        }
    }

    private func realityColor(_ score: Int) -> Color {
        switch score {
        case 70...: .green
        case 45..<70: .yellow
        default: .orange
        }
    }

    private func releaseColor(_ status: ReleaseReadinessStatus?) -> Color {
        switch status {
        case .ready: .green
        case .readyWithCaveats: .blue
        case .notReady: .orange
        case .blocked: .red
        case .unknown, .none: .gray
        }
    }

    private func relative(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "just now" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86_400 { return "\(seconds / 3600)h ago" }
        let days = seconds / 86_400
        if days == 1 { return "yesterday" }
        if days <= 30 { return "\(days)d ago" }
        return "\(days / 30)mo ago"
    }

    /// Dense numeric strip — answers "how big, how recent, how covered?" at a glance.
    private func statsStrip(_ snapshot: RepoSnapshot) -> some View {
        let s = snapshot.summary
        let v = snapshot.verificationSummary
        let inScopeCount = snapshot.applicability.filter { $0.status.inScope }.count
        let coveragePct = v.total == 0 ? 0 : Int((Double(v.verified) / Double(max(1, v.total))) * 100)
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 110), spacing: 10)], spacing: 10) {
            StatCell(label: "Files", value: "\(s.totalFiles)", color: .blue)
            StatCell(label: "Source", value: "\(s.sourceFiles)", color: .blue)
            StatCell(label: "Tests", value: "\(s.testFiles)", color: .indigo)
            StatCell(label: "Docs", value: "\(s.documentationFiles)", color: .teal)
            StatCell(label: "Large >25MB", value: "\(s.largeFiles)", color: s.largeFiles > 0 ? .orange : .gray)
            StatCell(label: "In Scope", value: "\(inScopeCount)", color: .purple)
            StatCell(label: "Coverage", value: "\(coveragePct)%", color: coveragePct >= 70 ? .green : .orange)
            StatCell(label: "Scanned", value: scannedAgo(snapshot.scannedAt), color: .gray)
        }
    }

    private func scannedAgo(_ date: Date) -> String {
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3600 { return "\(seconds / 60)m ago" }
        if seconds < 86_400 { return "\(seconds / 3600)h ago" }
        return "\(seconds / 86_400)d ago"
    }

    @ViewBuilder
    private func missionDetail(_ snapshot: RepoSnapshot) -> some View {
        if let mission = snapshot.userMission, !mission.goals.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Label("Goals", systemImage: "target")
                    .font(.headline)
                ForEach(mission.goals, id: \.self) { goal in
                    Text("• \(goal)")
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        } else if snapshot.userMission == nil {
            HStack(spacing: 8) {
                Image(systemName: "lightbulb")
                    .foregroundStyle(.yellow)
                Text("Mission is inferred. Define it to make every screen contextual to what \(project?.name ?? "this project") is actually trying to be.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func verificationStrip(_ snapshot: RepoSnapshot) -> some View {
        let s = snapshot.verificationSummary
        return HStack(spacing: 10) {
            Label("Verification", systemImage: "checklist")
                .font(.headline)
            VerificationCountBadge(count: s.verified, label: "Verified", color: .green)
            VerificationCountBadge(count: s.inProgress, label: "In Progress", color: .blue)
            VerificationCountBadge(count: s.failed, label: "Failed", color: .red)
            VerificationCountBadge(count: s.unknown, label: "Unknown", color: .gray)
            Spacer()
            Button {
                store.selectedModule = .verification
            } label: {
                Label("Track", systemImage: "arrow.right")
            }
            .buttonStyle(.borderless)
        }
    }

    @ViewBuilder
    private func buildVerificationNudge(_ snapshot: RepoSnapshot) -> some View {
        let projectID = store.selectedProjectID
        let successfulBuilds = store.buildHistory(for: projectID).filter { $0.result == .success }
        let buildVerified = snapshot.verification.contains {
            $0.area.localizedCaseInsensitiveContains("build") && $0.state == .verified
        }
        if !successfulBuilds.isEmpty && !buildVerified {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "hammer.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.orange)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Build success recorded, but Build verification still needs evidence.")
                        .font(.body.weight(.semibold))
                    Text("LocalForge records builds separately. Promote or attach build evidence before treating Build as verified.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    store.selectedModule = .buildHistory
                } label: {
                    Label("Open Build History", systemImage: "arrow.right")
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.orange.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    private func risks(_ reality: RealityAssessment) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Top Risks", systemImage: "exclamationmark.triangle")
                .font(.headline)
            if reality.topRisks.isEmpty {
                Text("No in-scope risks identified.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(reality.topRisks, id: \.self) { risk in
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "circle.fill")
                            .font(.system(size: 6))
                            .foregroundStyle(.orange)
                            .padding(.top, 6)
                        Text(risk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func nextAction(_ reality: RealityAssessment) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "arrow.forward.circle.fill")
                .font(.title2)
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text("Next Recommended Action")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(reality.nextAction)
                    .font(.body.weight(.medium))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.12), in: RoundedRectangle(cornerRadius: 8))
    }

    private func copyBrief(_ snapshot: RepoSnapshot) {
        let r = snapshot.reality
        let goals = snapshot.userMission?.goals ?? []
        let brief = """
        LocalForge Reality Brief — \(project?.name ?? "Project")
        Type: \(snapshot.identity.kind.rawValue) [\(snapshot.identity.confidence.rawValue)]
        Mission: \(snapshot.mission.statedMission)
        \(snapshot.userMission?.currentPhase.isEmpty == false ? "Phase: \(snapshot.userMission!.currentPhase)\n" : "")State: \(r.currentState)
        Reality score: \(r.score)%
        Verification: \(snapshot.verificationSummary.verified) verified, \(snapshot.verificationSummary.failed) failed, \(snapshot.verificationSummary.unknown) unknown
        \(goals.isEmpty ? "" : "\nGoals:\n\(goals.map { "- \($0)" }.joined(separator: "\n"))")
        Top risks:
        \(r.topRisks.isEmpty ? "- None" : r.topRisks.map { "- \($0)" }.joined(separator: "\n"))

        Unverified (in scope):
        \(r.unverified.isEmpty ? "- None" : r.unverified.map { "- \($0)" }.joined(separator: "\n"))

        Next action: \(r.nextAction)
        """
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(brief, forType: .string)
    }
}

private struct VerificationCountBadge: View {
    var count: Int
    var label: String
    var color: Color

    var body: some View {
        HStack(spacing: 5) {
            Text("\(count)")
                .font(.subheadline.weight(.bold))
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

private struct InfoCell: View {
    var label: String
    var value: String
    var tag: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.6)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.semibold))
                .lineLimit(2)
                .minimumScaleFactor(0.7)
                .textSelection(.enabled)
            Text(tag)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 7)
                .padding(.vertical, 3)
                .background(.quaternary, in: Capsule())
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
        .padding(14)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

/// Compact numeric tile used by the Command Centre stats strip.
struct StatCell: View {
    var label: String
    var value: String
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 7))
    }
}

struct RealityScoreBadge: View {
    var score: Int

    private var color: Color {
        switch score {
        case 70...: .green
        case 45..<70: .yellow
        default: .orange
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            Text("\(score)")
                .font(.system(size: 46, weight: .bold, design: .rounded))
            Text("REALITY")
                .font(.caption.weight(.bold))
                .tracking(1)
                .foregroundStyle(.secondary)
        }
        .frame(width: 108, height: 108)
        .background(color.opacity(0.16), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(color.opacity(0.5), lineWidth: 1.5))
    }
}

struct VerificationChainView: View {
    var chain: [VerificationStageStatus]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Verification Status", systemImage: "checkmark.seal")
                .font(.headline)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(chain) { item in
                        HStack(spacing: 4) {
                            Image(systemName: symbol(item.state))
                                .foregroundStyle(color(item.state))
                            Text(item.stage.rawValue)
                                .font(.caption)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(color(item.state).opacity(0.14), in: Capsule())
                        if item.stage != chain.last?.stage {
                            Image(systemName: "chevron.compact.right")
                                .foregroundStyle(.tertiary)
                        }
                    }
                }
            }
        }
    }

    private func symbol(_ state: StageState) -> String {
        switch state {
        case .reached: "checkmark.circle.fill"
        case .notReached: "xmark.circle.fill"
        case .unknown: "questionmark.circle"
        }
    }

    private func color(_ state: StageState) -> Color {
        switch state {
        case .reached: .green
        case .notReached: .red
        case .unknown: .gray
        }
    }
}
