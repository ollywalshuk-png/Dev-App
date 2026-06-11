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
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 10)], spacing: 10) {
                Stat(label: "Projects", value: "\(t.totalProjects)", color: .blue)
                Stat(label: "Verified Records", value: "\(t.verifiedRecords)", color: .green)
                Stat(label: "Evidence Records", value: "\(t.evidenceRecords)", color: .indigo)
                Stat(label: "Open Risks", value: "\(t.openRisks)", color: t.openRisks > 0 ? .red : .gray)
                Stat(label: "Active Assumptions", value: "\(t.activeAssumptions)", color: t.activeAssumptions > 0 ? .orange : .gray)
                Stat(label: "Critical Failures", value: "\(t.criticalFailures)", color: t.criticalFailures > 0 ? .red : .gray)
                Stat(label: "Decisions", value: "\(t.decisionRecords)", color: .purple)
                Stat(label: "Architecture", value: "\(t.architectureItems)", color: .teal)
                Stat(label: "Stale Verified", value: "\(t.staleVerifications)", color: t.staleVerifications > 0 ? .orange : .gray)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))

            if let snapshot = store.selectedSnapshot {
                realityBreakdownCard(snapshot: snapshot)
                confidenceCard
                registerHealthCard
            } else {
                Text("Open a project to see its Reality breakdown, Confidence, and Register Health.")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .padding(12)
                    .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private func realityBreakdownCard(snapshot: RepoSnapshot) -> some View {
        let breakdown = store.selectedRealityBreakdown
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Reality Breakdown").font(.system(size: 18, weight: .semibold))
                Spacer()
                Text("\(snapshot.reality.score)%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.green)
            }
            ForEach(breakdown.contributions) { c in
                ContributionRow(label: c.label, delta: c.delta)
            }
            if breakdown.contributions.isEmpty {
                Text("Nothing tracked yet — start with a Mission and verification areas.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var confidenceCard: some View {
        let c = store.selectedConfidence
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Confidence").font(.system(size: 18, weight: .semibold))
                    Text(c.summary).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Text("\(c.score)%")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(confidenceColor(c.score))
                Text(c.label).font(.caption.weight(.semibold))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(confidenceColor(c.score).opacity(0.16), in: Capsule())
                    .foregroundStyle(confidenceColor(c.score))
            }
            ForEach(c.contributions) { item in
                ContributionRow(label: item.label, delta: item.delta)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
    }

    private var registerHealthCard: some View {
        let h = store.selectedRegisterHealth
        return VStack(alignment: .leading, spacing: 10) {
            Text("Register Health").font(.system(size: 18, weight: .semibold))
            Text("Tells you where truth is weak — low coverage means LocalForge can't fully back its claims.")
                .font(.caption).foregroundStyle(.secondary)
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

    private func confidenceColor(_ s: Int) -> Color {
        switch s { case 80...: .green; case 55..<80: .blue; case 30..<55: .orange; default: .red }
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
