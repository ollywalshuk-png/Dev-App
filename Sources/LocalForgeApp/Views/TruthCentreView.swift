import AppKit
import LocalForgeCore
import SwiftUI

/// Phase 7.5 — Truth Centre.
/// One screen with three tabs:
///   - Workspace summary (across every project) + Register Health card
///   - Evidence Explorer (filters across confidence/area/project)
///   - Dependency Map (tree of verification dependencies, coloured by state)
struct TruthCentreView: View {
    @ObservedObject var store: WorkspaceStore

    enum Tab: String, CaseIterable, Identifiable {
        case workspace = "Workspace Truth"
        case evidence = "Evidence Explorer"
        case dependencies = "Dependency Map"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .workspace: "rectangle.grid.2x2"
            case .evidence: "magnifyingglass.circle"
            case .dependencies: "point.3.connected.trianglepath.dotted"
            }
        }
    }
    @State private var tab: Tab = .workspace

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            header
            ExplanationCard(
                title: "Truth and Evidence",
                what: "Truth Centre shows the evidence, register coverage, reality breakdown, and dependency map behind LocalForge's claims.",
                why: "Evidence is proof. LocalForge uses it to decide whether an area is verified, failed, unknown, or risky.",
                next: "Open Evidence Explorer to inspect proof, or use Dependency Map to find what is blocking release.",
                safety: "This screen reads LocalForge records only. It does not change your project or repository.",
                symbol: "checkmark.shield",
                tint: .indigo
            )
            Picker("", selection: $tab) {
                ForEach(Tab.allCases) { Label($0.rawValue, systemImage: $0.symbol).tag($0) }
            }
            .pickerStyle(.segmented)

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .workspace:    WorkspaceTruthTab(store: store)
                    case .evidence:     EvidenceExplorerTab(store: store)
                    case .dependencies: DependencyMapTab(store: store)
                    }
                }
                .padding(.top, 4)
            }
        }
        .padding(20)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Truth Centre")
                .font(.system(size: 30, weight: .bold))
            Text("What is actually true across this workspace, where the evidence is, and how the pieces connect.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Workspace Truth tab

private struct WorkspaceTruthTab: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        let t = store.workspaceTruth
        VStack(alignment: .leading, spacing: 14) {
            if let snapshot = store.selectedSnapshot {
                truthScorePanel(snapshot: snapshot)
                truthDebtGatePanel(snapshot: snapshot)
                evidenceInspectionPanel(snapshot: snapshot)
                stressPanel(snapshot: snapshot)
                realityBreakdownCard(snapshot: snapshot)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 280), spacing: 12)], spacing: 12) {
                    confidenceCard
                    registerHealthCard
                }
            } else {
                EmptyTruthPanel(
                    title: t.totalProjects == 0 ? "No truth records yet" : "No active project selected",
                    message: t.totalProjects == 0
                        ? "Open a repository to create the first local truth ledger. The score stays empty until LocalForge has a project, a mission, verification areas, and evidence to read."
                        : "Select a project to see its Reality score, confidence, register coverage, and stress gaps.",
                    symbol: t.totalProjects == 0 ? "folder.badge.plus" : "scope",
                    color: .indigo
                )
            }
            portfolioSnapshot(summary: t)
        }
    }

    private func truthScorePanel(snapshot: RepoSnapshot) -> some View {
        let projectID = store.selectedProjectID
        let evidence = store.evidence(for: projectID)
        let risks = store.risks(for: projectID)
        let assumptions = store.assumptions(for: projectID)
        let summary = snapshot.verificationSummary
        let confidence = store.selectedConfidence
        let health = store.selectedRegisterHealth
        let registerCoverage = registerCoverageScore(health)
        let strongEvidence = evidence.filter { isStrongEvidence($0.classification) }.count
        let openBlockers = risks.filter(\.isReleaseBlocking).count
        let staleVerified = staleVerifiedCount(snapshot)
        let activeAssumptions = assumptions.filter { $0.status == .active }.count
        let scoreColor = realityColor(snapshot.reality.score)

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Label("Selected Project Truth", systemImage: "checkmark.shield")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(store.selectedProject?.name ?? snapshot.project.name)
                        .font(.system(size: 24, weight: .bold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                        .truncationMode(.middle)
                    Text(snapshot.reality.currentState)
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        Pill(text: "Confidence \(confidence.score)%", color: confidenceColor(confidence.score))
                        Pill(text: confidence.label, color: confidenceColor(confidence.score))
                        Pill(text: "\(summary.verified)/\(summary.total) verified", color: summary.failed > 0 ? .orange : .green)
                    }
                }
                Spacer(minLength: 12)
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(snapshot.reality.score)%")
                        .font(.system(size: 46, weight: .bold).monospacedDigit())
                        .foregroundStyle(scoreColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.65)
                    Text("Reality Score")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text("Last scan \(snapshot.scannedAt.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            ScoreTrack(value: snapshot.reality.score, color: scoreColor)
            HStack(alignment: .center, spacing: 10) {
                Label {
                    Text("Local-only brief from this workspace's evidence, registers, and latest scan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.doc")
                        .foregroundStyle(.indigo)
                }
                Spacer(minLength: 12)
                Button {
                    copyTruthBrief(snapshot: snapshot)
                } label: {
                    Label("Copy Truth Brief", systemImage: "doc.on.doc")
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                .help("Copy the Reality score, confidence, evidence, blockers, score pressure, and next action")
            }
            .padding(10)
            .background(Color.indigo.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                TruthMetric(label: "Strong Evidence", value: "\(strongEvidence)", detail: "Observed, measured, verified", symbol: "doc.text.magnifyingglass", color: strongEvidence > 0 ? .green : .orange)
                TruthMetric(label: "Open Blockers", value: "\(openBlockers)", detail: "Release-blocking risks", symbol: "exclamationmark.octagon", color: openBlockers > 0 ? .red : .gray)
                TruthMetric(label: "Unknown Areas", value: "\(summary.unknown)", detail: "In verification ledger", symbol: "questionmark.circle", color: summary.unknown > 0 ? .orange : .gray)
                TruthMetric(label: "Register Cover", value: "\(registerCoverage)%", detail: "Average truth coverage", symbol: "rectangle.grid.2x2", color: coverageColor(registerCoverage))
                TruthMetric(label: "Stale Verified", value: "\(staleVerified)", detail: "Needs re-check", symbol: "clock.badge.exclamationmark", color: staleVerified > 0 ? .orange : .gray)
                TruthMetric(label: "Assumptions", value: "\(activeAssumptions)", detail: "Still active", symbol: "lightbulb", color: activeAssumptions > 0 ? .orange : .gray)
            }
            TruthStatusLine(
                title: trustStatement(snapshot: snapshot, evidenceCount: evidence.count, blockers: openBlockers),
                detail: snapshot.reality.nextAction,
                symbol: openBlockers > 0 || summary.failed > 0 ? "exclamationmark.triangle" : "arrow.right.circle",
                color: openBlockers > 0 || summary.failed > 0 ? .orange : .blue
            )
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func truthDebtGatePanel(snapshot: RepoSnapshot) -> some View {
        let projectID = store.selectedProjectID
        let report = TruthDebtEngine().report(
            snapshot: snapshot,
            evidence: store.evidence(for: projectID),
            risks: store.risks(for: projectID),
            assumptions: store.assumptions(for: projectID)
        )
        let topGates = Array(report.gates.prefix(4))
        let statusColor = truthDebtStatusColor(report.status)

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Truth Debt / Release-Claim Gate")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Read-only gate check from mission, verification, evidence, risks, assumptions, and contradictions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 12)
                TruthHealthBadge(text: report.status.rawValue, color: statusColor)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 10)], spacing: 10) {
                TruthMetric(
                    label: "Blockers",
                    value: "\(report.blockers.count)",
                    detail: "Stop release-ready claims",
                    symbol: "exclamationmark.octagon",
                    color: report.blockers.isEmpty ? .gray : .red
                )
                TruthMetric(
                    label: "Caveats",
                    value: "\(report.caveats.count)",
                    detail: "Require caveated claims",
                    symbol: "exclamationmark.triangle",
                    color: report.caveats.isEmpty ? .gray : .orange
                )
                TruthMetric(
                    label: "Top Gates",
                    value: "\(topGates.count)",
                    detail: report.gates.isEmpty ? "No gates detected" : "Sorted by impact",
                    symbol: "list.bullet.rectangle",
                    color: report.gates.isEmpty ? .green : .indigo
                )
            }

            TruthStatusLine(
                title: report.headline,
                detail: truthDebtReleaseClaimDetail(report),
                symbol: truthDebtStatusSymbol(report.status),
                color: statusColor
            )

            if topGates.isEmpty {
                EmptyTruthPanel(
                    title: "Release claim is defensible",
                    message: "The TruthDebtEngine did not find blocker or caveat gates for the selected project's current records.",
                    symbol: "shield.checkered",
                    color: .green
                )
            } else {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Top Gates")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(topGates) { gate in
                        TruthDebtGateRow(gate: gate)
                    }
                    if report.gates.count > topGates.count {
                        Text("+ \(report.gates.count - topGates.count) more gate\(report.gates.count - topGates.count == 1 ? "" : "s") in the full report.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func evidenceInspectionPanel(snapshot: RepoSnapshot) -> some View {
        let projectID = store.selectedProjectID
        let evidence = store.evidence(for: projectID)
        let strong = strongestEvidence(evidence)
        let weak = weakestEvidence(evidence)
        let pressure = evidenceAreaPressure(snapshot: snapshot, evidence: evidence)
        let breakdown = store.selectedRealityBreakdown
        let positives = Array(breakdown.positives.sorted { $0.delta > $1.delta }.prefix(3))
        let negatives = Array(breakdown.negatives.sorted { $0.delta < $1.delta }.prefix(3))

        return VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Evidence Inspection")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Local provenance only: stored evidence records, linked registers, verification areas, and the latest scan.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                TruthHealthBadge(
                    text: "\(strong.count) strong / \(weak.count) weak",
                    color: weak.isEmpty ? .green : .orange
                )
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                EvidenceSummaryColumn(
                    title: "Strongest Evidence",
                    subtitle: "Verified, measured, and observed proof.",
                    records: Array(strong.prefix(3)),
                    color: strong.isEmpty ? .gray : .green,
                    emptyMessage: "No strong evidence is recorded yet."
                )
                EvidenceSummaryColumn(
                    title: "Weakest Evidence",
                    subtitle: "Inferred, assumed, and unknown proof to challenge.",
                    records: Array(weak.prefix(3)),
                    color: weak.isEmpty ? .gray : .orange,
                    emptyMessage: "No weak evidence is recorded."
                )
            }

            if !pressure.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Area Pressure")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                    ForEach(Array(pressure.prefix(4))) { item in
                        EvidenceAreaPressureRow(summary: item)
                    }
                }
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 260), spacing: 12)], spacing: 12) {
                ScorePressureColumn(
                    title: "Raises Score",
                    contributions: positives,
                    color: .green,
                    emptyMessage: "No positive score pressure is recorded."
                )
                ScorePressureColumn(
                    title: "Reduces Score",
                    contributions: negatives,
                    color: negatives.isEmpty ? .gray : .red,
                    emptyMessage: "No negative score pressure is recorded."
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func realityBreakdownCard(snapshot: RepoSnapshot) -> some View {
        let breakdown = store.selectedRealityBreakdown
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("Reality Breakdown").font(.system(size: 18, weight: .semibold))
                    Text("Attribution behind the score. Baseline and deltas explain pressure; the engine still owns the final percentage.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(snapshot.reality.score)%")
                        .font(.system(size: 22, weight: .bold).monospacedDigit())
                        .foregroundStyle(realityColor(snapshot.reality.score))
                    Text("final")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 132), spacing: 10)], spacing: 10) {
                TruthMetric(label: "Baseline", value: "\(breakdown.baseline)", detail: "Starting posture", symbol: "equal.circle", color: .blue)
                TruthMetric(label: "Lift", value: "+\(breakdown.positives.reduce(0) { $0 + $1.delta })", detail: "\(breakdown.positives.count) positive inputs", symbol: "arrow.up.circle", color: .green)
                TruthMetric(label: "Pressure", value: "\(breakdown.negatives.reduce(0) { $0 + $1.delta })", detail: "\(breakdown.negatives.count) deductions", symbol: "arrow.down.circle", color: breakdown.negatives.isEmpty ? .gray : .red)
            }
            if !breakdown.positives.isEmpty {
                ContributionGroup(title: "Evidence raising the score", contributions: breakdown.positives, color: .green)
            }
            if !breakdown.negatives.isEmpty {
                ContributionGroup(title: "Risks reducing the score", contributions: breakdown.negatives, color: .red)
            }
            if breakdown.contributions.isEmpty {
                EmptyTruthPanel(
                    title: "No score inputs yet",
                    message: "Start with a mission, verification areas, and at least one evidence record. Until then the Reality score is intentionally cautious.",
                    symbol: "tray",
                    color: .gray
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var confidenceCard: some View {
        let c = store.selectedConfidence
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Confidence").font(.system(size: 18, weight: .semibold))
                    Text("How well LocalForge can trust what it knows, separate from whether the project is healthy.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Text("\(c.score)%")
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(confidenceColor(c.score))
                Text(c.label).font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(confidenceColor(c.score).opacity(0.16), in: Capsule())
                    .foregroundStyle(confidenceColor(c.score))
            }
            Text(c.summary)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ForEach(c.contributions) { item in
                ContributionRow(label: item.label, delta: item.delta)
            }
            if c.contributions.isEmpty {
                Text("No confidence inputs yet. Add evidence and update verification records to make this defensible.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var registerHealthCard: some View {
        let h = store.selectedRegisterHealth
        let cover = registerCoverageScore(h)
        return VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Register Health").font(.system(size: 18, weight: .semibold))
                    Text("Where the truth ledger is strong or thin.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(cover)%")
                    .font(.system(size: 22, weight: .bold).monospacedDigit())
                    .foregroundStyle(coverageColor(cover))
            }
            CoverageBar(label: "Evidence", value: h.evidenceCoverage)
            CoverageBar(label: "Risks", value: h.riskCoverage)
            CoverageBar(label: "Decisions", value: h.decisionCoverage)
            CoverageBar(label: "Architecture", value: h.architectureCoverage)
            CoverageBar(label: "Assumptions", value: h.assumptionCoverage)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func portfolioSnapshot(summary t: WorkspaceTruthSummary) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("Workspace Truth Ledger")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("\(t.totalProjects) project\(t.totalProjects == 1 ? "" : "s")")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                Stat(label: "Verified Records", value: "\(t.verifiedRecords)", color: .green)
                Stat(label: "Evidence Records", value: "\(t.evidenceRecords)", color: .indigo)
                Stat(label: "Open Risks", value: "\(t.openRisks)", color: t.openRisks > 0 ? .red : .gray)
                Stat(label: "Active Assumptions", value: "\(t.activeAssumptions)", color: t.activeAssumptions > 0 ? .orange : .gray)
                Stat(label: "Critical Failures", value: "\(t.criticalFailures)", color: t.criticalFailures > 0 ? .red : .gray)
                Stat(label: "Decisions", value: "\(t.decisionRecords)", color: .purple)
                Stat(label: "Architecture", value: "\(t.architectureItems)", color: .teal)
                Stat(label: "Stale Verified", value: "\(t.staleVerifications)", color: t.staleVerifications > 0 ? .orange : .gray)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func stressPanel(snapshot: RepoSnapshot) -> some View {
        let projectID = store.selectedProjectID
        let evidence = store.evidence(for: projectID)
        let risks = store.risks(for: projectID)
        let assumptions = store.assumptions(for: projectID)
        let summary = snapshot.verificationSummary
        let openBlockers = risks.filter(\.isReleaseBlocking).count
        let staleVerified = staleVerifiedCount(snapshot)
        let activeAssumptions = assumptions.filter { $0.status == .active }.count
        let zeroFiles = snapshot.summary.totalFiles == 0
        let noVerification = summary.total == 0
        let noEvidence = evidence.isEmpty
        let failed = summary.failed

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Stress Readout", systemImage: "waveform.path.ecg")
                    .font(.system(size: 18, weight: .semibold))
                Spacer()
                TruthHealthBadge(text: stressBadgeText(blockers: openBlockers, failed: failed, unknown: summary.unknown, noEvidence: noEvidence), color: stressColor(blockers: openBlockers, failed: failed, unknown: summary.unknown, noEvidence: noEvidence))
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 220), spacing: 10)], spacing: 10) {
                StressItem(
                    title: noVerification ? "Verification ledger is empty" : "Verification ledger is active",
                    detail: noVerification ? "No areas can be defended yet. Seed verification areas before trusting the percentage." : "\(summary.total) areas tracked: \(summary.verified) verified, \(failed) failed, \(summary.unknown) unknown.",
                    symbol: noVerification ? "tray" : "checklist",
                    color: noVerification ? .orange : .green
                )
                StressItem(
                    title: noEvidence ? "Evidence is missing" : "Evidence is on file",
                    detail: noEvidence ? "The score can describe state, but confidence stays weak until proof is captured." : "\(evidence.count) evidence record\(evidence.count == 1 ? "" : "s") available for audit.",
                    symbol: noEvidence ? "doc.badge.clock" : "doc.text.magnifyingglass",
                    color: noEvidence ? .orange : .green
                )
                StressItem(
                    title: openBlockers == 0 ? "No release blockers recorded" : "\(openBlockers) release blocker\(openBlockers == 1 ? "" : "s")",
                    detail: openBlockers == 0 ? "Open risks do not currently block release by severity." : "Open critical or high-likelihood risks are suppressing trust.",
                    symbol: openBlockers == 0 ? "shield.checkered" : "exclamationmark.octagon",
                    color: openBlockers == 0 ? .green : .red
                )
                StressItem(
                    title: staleVerified == 0 ? "Verified records are fresh enough" : "\(staleVerified) stale verification\(staleVerified == 1 ? "" : "s")",
                    detail: staleVerified == 0 ? "No verified record is currently stale or expired." : "Re-run or refresh these areas before treating them as release proof.",
                    symbol: staleVerified == 0 ? "clock" : "clock.badge.exclamationmark",
                    color: staleVerified == 0 ? .green : .orange
                )
                StressItem(
                    title: activeAssumptions == 0 ? "No active assumptions" : "\(activeAssumptions) active assumption\(activeAssumptions == 1 ? "" : "s")",
                    detail: activeAssumptions == 0 ? "No unresolved assumption is pulling confidence down." : "Convert assumptions into evidence or verification tasks.",
                    symbol: activeAssumptions == 0 ? "checkmark.circle" : "lightbulb",
                    color: activeAssumptions == 0 ? .green : .orange
                )
                StressItem(
                    title: zeroFiles ? "Scan returned zero files" : "Scan has repository evidence",
                    detail: zeroFiles ? "Refresh folder access or rescan; a zero-file scan is not a trustworthy product read." : "\(snapshot.summary.totalFiles) files observed in the approved folder.",
                    symbol: zeroFiles ? "lock.trianglebadge.exclamationmark" : "folder",
                    color: zeroFiles ? .red : .blue
                )
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private func confidenceColor(_ s: Int) -> Color {
        switch s { case 80...: .green; case 55..<80: .blue; case 30..<55: .orange; default: .red }
    }

    private func realityColor(_ s: Int) -> Color {
        switch s { case 75...: .green; case 55..<75: .blue; case 35..<55: .orange; default: .red }
    }

    private func coverageColor(_ s: Int) -> Color {
        switch s { case 80...: .green; case 50..<80: .blue; case 25..<50: .orange; default: .red }
    }

    private func registerCoverageScore(_ h: RegisterHealth) -> Int {
        let average = (h.evidenceCoverage + h.riskCoverage + h.decisionCoverage + h.architectureCoverage + h.assumptionCoverage) / 5
        return Int((average * 100).rounded())
    }

    private func staleVerifiedCount(_ snapshot: RepoSnapshot) -> Int {
        snapshot.verification.filter {
            $0.state == .verified && ($0.age == .stale || $0.age == .expired)
        }.count
    }

    private func isStrongEvidence(_ classification: EvidenceClassification) -> Bool {
        classification == .observed || classification == .measured || classification == .verified
    }

    private func strongestEvidence(_ evidence: [EvidenceRecord]) -> [EvidenceRecord] {
        evidence
            .filter { isStrongEvidence($0.classification) }
            .sorted {
                let left = evidenceStrengthRank($0.classification)
                let right = evidenceStrengthRank($1.classification)
                if left == right { return $0.createdAt > $1.createdAt }
                return left > right
            }
    }

    private func weakestEvidence(_ evidence: [EvidenceRecord]) -> [EvidenceRecord] {
        evidence
            .filter { !isStrongEvidence($0.classification) }
            .sorted {
                let left = evidenceStrengthRank($0.classification)
                let right = evidenceStrengthRank($1.classification)
                if left == right { return $0.createdAt < $1.createdAt }
                return left < right
            }
    }

    private func evidenceStrengthRank(_ classification: EvidenceClassification) -> Int {
        switch classification {
        case .verified: 5
        case .measured: 4
        case .observed: 3
        case .inferred: 2
        case .assumed: 1
        case .unknown: 0
        }
    }

    private func evidenceAreaPressure(snapshot: RepoSnapshot, evidence: [EvidenceRecord]) -> [EvidenceAreaPressure] {
        let grouped = Dictionary(grouping: evidence, by: \.area)
        let areas = Set(grouped.keys).union(snapshot.verification.map(\.area))

        return areas.map { area in
            let records = grouped[area] ?? []
            let strongCount = records.filter { isStrongEvidence($0.classification) }.count
            let weakCount = records.count - strongCount
            let state = snapshot.verification.first { $0.area == area }?.state
            let priority = snapshot.applicability.first { $0.area == area }?.priority
            return EvidenceAreaPressure(
                area: area,
                strongCount: strongCount,
                weakCount: weakCount,
                totalCount: records.count,
                state: state,
                priority: priority
            )
        }
        .sorted {
            let left = areaPressureScore($0)
            let right = areaPressureScore($1)
            if left == right { return $0.area < $1.area }
            return left > right
        }
    }

    private func areaPressureScore(_ pressure: EvidenceAreaPressure) -> Int {
        var score = 0
        switch pressure.state {
        case .failed:
            score += 50
        case .unknown:
            score += 35
        case .inProgress:
            score += 20
        case .verified:
            score += 0
        case nil:
            score += 15
        }

        if pressure.totalCount == 0 { score += 25 }
        if pressure.strongCount == 0 { score += 12 }
        score += pressure.weakCount * 6

        switch pressure.priority {
        case .critical:
            score += 12
        case .high:
            score += 8
        case .medium:
            score += 4
        case .low, nil:
            score += 0
        }
        return score
    }

    private func trustStatement(snapshot: RepoSnapshot, evidenceCount: Int, blockers: Int) -> String {
        if snapshot.verificationSummary.total == 0 {
            return "Truth is not stress-testable yet: no verification areas are tracked."
        }
        if evidenceCount == 0 {
            return "Truth is provisional: verification exists, but evidence is not captured yet."
        }
        if blockers > 0 {
            return "Truth is actionable: blockers are visible and should drive the next release decision."
        }
        return "Truth is audit-ready enough to inspect, challenge, and improve."
    }

    private func truthDebtStatusColor(_ status: TruthDebtStatus) -> Color {
        switch status {
        case .blocked:
            .red
        case .caveated:
            .orange
        case .defensible:
            .green
        }
    }

    private func truthDebtStatusSymbol(_ status: TruthDebtStatus) -> String {
        switch status {
        case .blocked:
            "lock.shield"
        case .caveated:
            "exclamationmark.shield"
        case .defensible:
            "checkmark.shield"
        }
    }

    private func truthDebtReleaseClaimDetail(_ report: TruthDebtReport) -> String {
        switch report.status {
        case .blocked:
            "Release-ready claims are blocked until the listed Critical/High gates are resolved."
        case .caveated:
            "No blocker is present, but release claims should carry the listed caveats."
        case .defensible:
            "No Truth Debt gate currently prevents a defensible release-ready claim."
        }
    }

    private func stressBadgeText(blockers: Int, failed: Int, unknown: Int, noEvidence: Bool) -> String {
        if blockers > 0 || failed > 0 { return "High Pressure" }
        if noEvidence || unknown > 0 { return "Needs Proof" }
        return "Stable"
    }

    private func stressColor(blockers: Int, failed: Int, unknown: Int, noEvidence: Bool) -> Color {
        if blockers > 0 || failed > 0 { return .red }
        if noEvidence || unknown > 0 { return .orange }
        return .green
    }

    private func copyTruthBrief(snapshot: RepoSnapshot) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(truthBriefMarkdown(snapshot: snapshot), forType: .string)
    }

    private func truthBriefMarkdown(snapshot: RepoSnapshot) -> String {
        let projectID = store.selectedProjectID
        let evidence = store.evidence(for: projectID)
        let risks = store.risks(for: projectID)
        let assumptions = store.assumptions(for: projectID)
        let summary = snapshot.verificationSummary
        let confidence = store.selectedConfidence
        let health = store.selectedRegisterHealth
        let breakdown = store.selectedRealityBreakdown
        let strongEvidence = evidence.filter { isStrongEvidence($0.classification) }.count
        let openBlockers = risks.filter(\.isReleaseBlocking).count
        let activeAssumptions = assumptions.filter { $0.status == .active }.count
        let staleVerified = staleVerifiedCount(snapshot)
        let registerCoverage = registerCoverageScore(health)
        let positivePressure = markdownList(
            breakdown.positives.prefix(5).map { "\($0.label) (+\($0.delta))" },
            empty: "None recorded"
        )
        let negativePressure = markdownList(
            breakdown.negatives.prefix(5).map { "\($0.label) (\($0.delta))" },
            empty: "None recorded"
        )
        let strongest = markdownList(
            strongestEvidence(evidence).prefix(5).map { "\($0.classification.rawValue): \($0.summary) (\($0.area))" },
            empty: "None recorded"
        )
        let weakest = markdownList(
            weakestEvidence(evidence).prefix(5).map { "\($0.classification.rawValue): \($0.summary) (\($0.area))" },
            empty: "None recorded"
        )

        return """
        # LocalForge Truth Brief

        Project: \(store.selectedProject?.name ?? snapshot.project.name)
        Generated: \(Date().formatted(date: .abbreviated, time: .shortened))
        Last scan: \(snapshot.scannedAt.formatted(date: .abbreviated, time: .shortened))
        Provenance: LocalForge local records only. No project files or repository state are changed by copying this brief.

        ## Scores

        - Reality: \(snapshot.reality.score)% - \(snapshot.reality.currentState)
        - Confidence: \(confidence.score)% - \(confidence.label)
        - Register coverage: \(registerCoverage)%
        - Verification: \(summary.verified) verified, \(summary.inProgress) in progress, \(summary.failed) failed, \(summary.unknown) unknown
        - Evidence: \(evidence.count) total, \(strongEvidence) strong

        ## Stress Flags

        - Release blockers: \(openBlockers)
        - Failed verification areas: \(summary.failed)
        - Unknown verification areas: \(summary.unknown)
        - Stale verified areas: \(staleVerified)
        - Active assumptions: \(activeAssumptions)

        ## Evidence At A Glance

        Strongest:
        \(strongest)

        Weakest:
        \(weakest)

        ## Score Pressure

        Positive:
        \(positivePressure)

        Negative:
        \(negativePressure)

        ## Top Risks

        \(markdownList(snapshot.reality.topRisks.prefix(5), empty: "None recorded"))

        ## Unverified In-Scope Areas

        \(markdownList(snapshot.reality.unverified.prefix(8), empty: "None recorded"))

        ## Next Action

        \(snapshot.reality.nextAction)

        Safety: This brief is copied from LocalForge's local records only. It does not change the project or repository.
        """
    }

    private func markdownList<S: Sequence>(_ items: S, empty: String) -> String where S.Element == String {
        let values = Array(items)
        guard !values.isEmpty else { return "- \(empty)" }
        return values.map { "- \($0)" }.joined(separator: "\n")
    }
}

private struct TruthDebtGateRow: View {
    var gate: TruthDebtGate

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: gate.blocksReleaseClaim ? "lock.shield" : "exclamationmark.shield")
                .foregroundStyle(severityColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 7) {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 92), spacing: 6, alignment: .leading)], alignment: .leading, spacing: 6) {
                    TruthDebtTag(text: gate.severity.rawValue, color: severityColor)
                    TruthDebtTag(text: gate.kind.rawValue, color: severityColor)
                    TruthDebtTag(text: gate.area.isEmpty ? "Workspace" : gate.area, color: .blue)
                }
                Text(gate.title)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Action: \(gate.recommendedAction)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(severityColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }

    private var severityColor: Color {
        switch gate.severity {
        case .critical:
            .red
        case .high:
            .orange
        case .medium:
            .blue
        case .low:
            .gray
        }
    }
}

private struct TruthDebtTag: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.7)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct EvidenceAreaPressure: Identifiable {
    var area: String
    var strongCount: Int
    var weakCount: Int
    var totalCount: Int
    var state: VerificationState?
    var priority: VerificationPriority?

    var id: String { area }
}

private struct EvidenceSummaryColumn: View {
    var title: String
    var subtitle: String
    var records: [EvidenceRecord]
    var color: Color
    var emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if records.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(records) { record in
                    EvidenceSummaryRow(record: record)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EvidenceSummaryRow: View {
    var record: EvidenceRecord

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: record.kind.symbolName)
                    .foregroundStyle(classificationColor)
                    .frame(width: 18)
                Text(record.summary)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            HStack(spacing: 6) {
                Pill(text: record.classification.rawValue, color: classificationColor)
                Pill(text: record.area, color: .blue)
                Spacer(minLength: 8)
                Text(record.createdAt.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if !record.body.isEmpty {
                Text(record.body)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(9)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private var classificationColor: Color {
        switch record.classification {
        case .verified, .measured, .observed:
            .green
        case .inferred:
            .blue
        case .assumed:
            .orange
        case .unknown:
            .red
        }
    }
}

private struct EvidenceAreaPressureRow: View {
    var summary: EvidenceAreaPressure

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: summary.state?.symbolName ?? "scope")
                .foregroundStyle(stateColor)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 5) {
                Text(summary.area)
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 6) {
                    Pill(text: summary.state?.rawValue ?? "Untracked", color: stateColor)
                    if let priority = summary.priority {
                        Pill(text: priority.rawValue, color: priorityColor(priority))
                    }
                    Pill(text: "\(summary.totalCount) evidence", color: .indigo)
                }
            }
            Spacer(minLength: 10)
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(summary.strongCount) strong")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(summary.strongCount > 0 ? Color.green : Color.secondary)
                Text("\(summary.weakCount) weak")
                    .font(.caption2)
                    .foregroundStyle(summary.weakCount > 0 ? Color.orange : Color.secondary)
            }
        }
        .padding(9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(stateColor.opacity(0.07), in: RoundedRectangle(cornerRadius: 8))
    }

    private var stateColor: Color {
        switch summary.state {
        case .verified:
            .green
        case .failed:
            .red
        case .inProgress:
            .blue
        case .unknown:
            .orange
        case nil:
            .gray
        }
    }

    private func priorityColor(_ priority: VerificationPriority) -> Color {
        switch priority {
        case .critical:
            .red
        case .high:
            .orange
        case .medium:
            .blue
        case .low:
            .gray
        }
    }
}

private struct ScorePressureColumn: View {
    var title: String
    var contributions: [RealityContribution]
    var color: Color
    var emptyMessage: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)
            if contributions.isEmpty {
                Text(emptyMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(contributions) { item in
                    ContributionRow(label: item.label, delta: item.delta)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ScoreTrack: View {
    var value: Int
    var color: Color

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 5)
                    .fill(Color.secondary.opacity(0.12))
                RoundedRectangle(cornerRadius: 5)
                    .fill(color)
                    .frame(width: max(6, geo.size.width * CGFloat(clampedValue) / 100))
            }
        }
        .frame(height: 10)
        .accessibilityLabel("Reality score")
        .accessibilityValue("\(clampedValue) percent")
    }

    private var clampedValue: Int {
        min(100, max(0, value))
    }
}

private struct TruthMetric: View {
    var label: String
    var value: String
    var detail: String
    var symbol: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                Text(label.uppercased())
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(value)
                    .font(.system(size: 21, weight: .bold).monospacedDigit())
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .topLeading)
        .padding(10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TruthStatusLine: View {
    var title: String
    var detail: String
    var symbol: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct TruthHealthBadge: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct StressItem: View {
    var title: String
    var detail: String
    var symbol: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 74, alignment: .topLeading)
        .padding(10)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ContributionGroup: View {
    var title: String
    var contributions: [RealityContribution]
    var color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title.uppercased())
                .font(.caption2.weight(.bold))
                .tracking(0.5)
                .foregroundStyle(color)
            ForEach(contributions) { item in
                ContributionRow(label: item.label, delta: item.delta)
            }
        }
    }
}

private struct EmptyTruthPanel: View {
    var title: String
    var message: String
    var symbol: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                Text(message)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct ContributionRow: View {
    var label: String
    var delta: Int
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundStyle(.primary)
            Spacer()
            Text(delta > 0 ? "+\(delta)" : "\(delta)")
                .font(.system(size: 13, weight: .semibold).monospacedDigit())
                .foregroundStyle(delta >= 0 ? .green : .red)
        }
        .padding(.horizontal, 10).padding(.vertical, 6)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct CoverageBar: View {
    var label: String
    var value: Double

    private var color: Color {
        switch value { case 0.8...: .green; case 0.5..<0.8: .blue; case 0.2..<0.5: .orange; default: .red }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Text(label).font(.system(size: 13, weight: .medium))
                Spacer()
                Text("\(Int(value * 100))%")
                    .font(.system(size: 13, weight: .bold).monospacedDigit())
                    .foregroundStyle(color)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4).fill(Color.secondary.opacity(0.12))
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(width: max(4, geo.size.width * value))
                }
            }
            .frame(height: 8)
        }
    }
}

private struct Stat: View {
    var label: String; var value: String; var color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label.uppercased())
                .font(.caption2.weight(.bold)).tracking(0.5)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(color.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Evidence Explorer tab

private struct EvidenceExplorerTab: View {
    @ObservedObject var store: WorkspaceStore
    @State private var classificationFilter: EvidenceClassification? = nil
    @State private var areaFilter: String = ""
    @State private var authorFilter: String = ""
    @State private var search: String = ""
    @State private var sort: EvidenceSort = .newest
    @State private var sinceEnabled = false
    @State private var sinceDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()

    enum EvidenceSort: String, CaseIterable, Identifiable {
        case newest = "Newest"
        case oldest = "Oldest"
        case confidence = "Highest confidence"
        case mostLinked = "Most linked"
        var id: String { rawValue }
    }

    var body: some View {
        let pid = store.selectedProjectID
        let all = store.evidence(for: pid)
        let filtered = arrange(filter(all), projectID: pid)

        VStack(alignment: .leading, spacing: 12) {
            summaryStrip(all: all)
            filters
            if filtered.isEmpty {
                Text(pid == nil ? "Open a project to browse its evidence."
                                 : "No evidence matches these filters yet.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            } else {
                ForEach(filtered) { record in
                    EvidenceListRow(
                        record: record,
                        related: pid.map { store.relatedRecords(for: .evidence(record.id), projectID: $0) } ?? RelatedRecords()
                    )
                }
            }
        }
    }

    private func filter(_ records: [EvidenceRecord]) -> [EvidenceRecord] {
        records.filter { record in
            (classificationFilter == nil || record.classification == classificationFilter!) &&
            (areaFilter.isEmpty || record.area.localizedCaseInsensitiveContains(areaFilter)) &&
            (authorFilter.isEmpty || record.author.localizedCaseInsensitiveContains(authorFilter)) &&
            (!sinceEnabled || record.createdAt >= sinceDate) &&
            (search.isEmpty || record.summary.localizedCaseInsensitiveContains(search) ||
                              record.body.localizedCaseInsensitiveContains(search))
        }
    }

    private func arrange(_ records: [EvidenceRecord], projectID: UUID?) -> [EvidenceRecord] {
        switch sort {
        case .newest:
            records.sorted { $0.createdAt > $1.createdAt }
        case .oldest:
            records.sorted { $0.createdAt < $1.createdAt }
        case .confidence:
            records.sorted { rank($0.classification) > rank($1.classification) }
        case .mostLinked:
            records.sorted { linkCount($0, projectID) > linkCount($1, projectID) }
        }
    }

    private func rank(_ c: EvidenceClassification) -> Int {
        switch c { case .verified: 5; case .measured: 4; case .observed: 3; case .inferred: 2; case .assumed: 1; case .unknown: 0 }
    }

    private func linkCount(_ record: EvidenceRecord, _ projectID: UUID?) -> Int {
        guard let projectID else { return 0 }
        return store.relatedRecords(for: .evidence(record.id), projectID: projectID).totalCount
    }

    private func summaryStrip(all: [EvidenceRecord]) -> some View {
        let obs = all.filter { $0.classification == .observed }.count
        let meas = all.filter { $0.classification == .measured }.count
        let ver = all.filter { $0.classification == .verified }.count
        let unk = all.filter { $0.classification == .unknown }.count
        return LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
            Stat(label: "Total", value: "\(all.count)", color: .blue)
            Stat(label: "Observed", value: "\(obs)", color: .green)
            Stat(label: "Measured", value: "\(meas)", color: .teal)
            Stat(label: "Verified", value: "\(ver)", color: .green)
            Stat(label: "Unknown", value: "\(unk)", color: unk > 0 ? .red : .gray)
        }
    }

    private var filters: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Picker("Confidence", selection: $classificationFilter) {
                    Text("All").tag(EvidenceClassification?.none)
                    ForEach(EvidenceClassification.allCases, id: \.self) {
                        Text($0.rawValue).tag(EvidenceClassification?.some($0))
                    }
                }
                .frame(maxWidth: 220)
                TextField("Area filter", text: $areaFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 180)
                TextField("Author", text: $authorFilter)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 140)
                TextField("Search summary/body", text: $search)
                    .textFieldStyle(.roundedBorder)
                Button("Reset") {
                    classificationFilter = nil; areaFilter = ""; authorFilter = ""; search = ""
                    sinceEnabled = false; sort = .newest
                }
            }
            HStack(spacing: 8) {
                Picker("Sort", selection: $sort) {
                    ForEach(EvidenceSort.allCases) { Text($0.rawValue).tag($0) }
                }
                .frame(maxWidth: 260)
                Toggle("Since", isOn: $sinceEnabled)
                    .toggleStyle(.checkbox)
                DatePicker("", selection: $sinceDate, displayedComponents: .date)
                    .labelsHidden()
                    .disabled(!sinceEnabled)
                Spacer()
            }
        }
    }
}

private struct EvidenceListRow: View {
    var record: EvidenceRecord
    var related: RelatedRecords = RelatedRecords()
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: record.kind.symbolName).foregroundStyle(.blue).frame(width: 22)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(record.summary).font(.system(size: 14, weight: .semibold))
                    Pill(text: record.area, color: .blue)
                    Pill(text: record.kind.rawValue, color: .indigo)
                    Pill(text: record.classification.rawValue, color: confidenceColor(record.classification))
                    Spacer()
                    Text(record.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2).foregroundStyle(.tertiary)
                }
                if !record.body.isEmpty {
                    Text(record.body)
                        .font(.system(size: 13)).foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !record.attachmentPath.isEmpty {
                    Text("📎 \(record.attachmentPath)").font(.caption2.monospaced()).foregroundStyle(.tertiary)
                }
                RelatedRecordsStrip(related: related)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func confidenceColor(_ c: EvidenceClassification) -> Color {
        switch c { case .observed, .measured, .verified: .green; case .inferred: .blue; case .assumed: .orange; case .unknown: .red }
    }
}

private struct Pill: View {
    var text: String; var color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule()).foregroundStyle(color)
    }
}

// MARK: - Dependency Map tab

private struct DependencyMapTab: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        if let snapshot = store.selectedSnapshot {
            let priorityByArea = Dictionary(uniqueKeysWithValues: snapshot.applicability.map { ($0.area, $0.priority) })
            let stateByArea = Dictionary(uniqueKeysWithValues: snapshot.verification.map { ($0.area, $0.state) })
            VStack(alignment: .leading, spacing: 10) {
                Text("Verification dependency graph — coloured by state, indented by depth.")
                    .font(.callout).foregroundStyle(.secondary)
                ForEach(roots(in: snapshot)) { record in
                    DependencyNode(
                        record: record,
                        all: snapshot.verification,
                        stateByArea: stateByArea,
                        priorityByArea: priorityByArea,
                        depth: 0,
                        visited: []
                    )
                }
                if snapshot.verification.isEmpty {
                    Text("No verification records yet — open the Verification module to seed some.")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
        } else {
            Text("Open a project to see its dependency map.")
                .font(.callout).foregroundStyle(.secondary)
        }
    }

    /// Roots = records that no other record depends on. Falls back to records
    /// without any dependencies if every record is depended-upon (no cycles up).
    private func roots(in snapshot: RepoSnapshot) -> [VerificationRecord] {
        let allDependants = Set(snapshot.verification.flatMap(\.dependsOn))
        let withoutParents = snapshot.verification.filter { !allDependants.contains($0.area) }
        return withoutParents.isEmpty ? snapshot.verification.filter { $0.dependsOn.isEmpty } : withoutParents
    }
}

private struct DependencyNode: View {
    var record: VerificationRecord
    var all: [VerificationRecord]
    var stateByArea: [String: VerificationState]
    var priorityByArea: [String: VerificationPriority]
    var depth: Int
    var visited: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                ForEach(0..<depth, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 1).fill(Color.secondary.opacity(0.3)).frame(width: 2, height: 18)
                }
                if depth > 0 {
                    Image(systemName: "arrow.turn.down.right").foregroundStyle(.secondary)
                }
                Image(systemName: record.state.symbolName).foregroundStyle(stateColor)
                Text(record.area).font(.system(size: 15, weight: .semibold))
                if let p = priorityByArea[record.area] {
                    Pill(text: p.rawValue, color: priorityColor(p))
                }
                Pill(text: record.state.rawValue, color: stateColor)
                Spacer()
            }
            ForEach(children) { child in
                DependencyNode(
                    record: child,
                    all: all,
                    stateByArea: stateByArea,
                    priorityByArea: priorityByArea,
                    depth: depth + 1,
                    visited: visited.union([record.area])
                )
            }
        }
        .padding(.vertical, 2)
    }

    private var children: [VerificationRecord] {
        // A "child" in the tree is anything THIS area depends on.
        // Cycle-safe via `visited`.
        guard !visited.contains(record.area) else { return [] }
        return record.dependsOn.compactMap { dep in
            all.first { $0.area == dep }
        }
    }

    private var stateColor: Color {
        switch record.state {
        case .verified: .green
        case .failed: .red
        case .inProgress: .blue
        case .unknown: .gray
        }
    }

    private func priorityColor(_ p: VerificationPriority) -> Color {
        switch p { case .critical: .red; case .high: .orange; case .medium: .blue; case .low: .gray }
    }
}
