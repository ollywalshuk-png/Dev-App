import LocalForgeCore
import SwiftUI

/// The verification tracker — arguably the most valuable screen. It is not a
/// scanner; it records what has genuinely been verified, per area, by the user.
struct VerificationView: View {
    @ObservedObject var store: WorkspaceStore

    var body: some View {
        if let project = store.selectedProject, let snapshot = store.selectedSnapshot {
            VStack(alignment: .leading, spacing: 16) {
                header(project: project, snapshot: snapshot)
                ExplanationCard(
                    title: "Verification Centre",
                    what: "Verification records say whether an important project area is known to work, failed, in progress, or still unknown.",
                    why: "LocalForge treats unknown as unknown. It only raises confidence when a person or captured command output supports the claim.",
                    next: "Start with critical areas, attach evidence, and update the status with notes and a verifier name.",
                    safety: "Changing verification records updates LocalForge's local truth model only. It does not modify your source files or repository.",
                    example: "Example: mark Build as Verified only after a successful build record is attached as evidence.",
                    symbol: "checkmark.seal",
                    tint: .green
                )
                if snapshot.verification.isEmpty {
                    ContentUnavailableView(
                        "Nothing to verify yet",
                        systemImage: "checklist",
                        description: Text("LocalForge tracks the areas that matter for a \(snapshot.identity.kind.rawValue). None are in scope for this project type.")
                    )
                } else {
                    let priorityByArea = Dictionary(uniqueKeysWithValues: snapshot.applicability.map { ($0.area, $0.priority) })
                    let sorted = snapshot.verification.sorted { lhs, rhs in
                        let lp = priorityByArea[lhs.area] ?? .medium
                        let rp = priorityByArea[rhs.area] ?? .medium
                        if lp != rp { return lp < rp }
                        return lhs.area < rhs.area
                    }
                    let allAreas = snapshot.applicability.map(\.area)
                    let stateByArea = Dictionary(uniqueKeysWithValues: snapshot.verification.map { ($0.area, $0.state) })
                    packsPicker(snapshot: snapshot, projectID: project.id)
                    ForEach(sorted) { record in
                        VStack(alignment: .leading, spacing: 6) {
                            VerificationRow(
                                record: record,
                                priority: priorityByArea[record.area] ?? .medium,
                                allAreas: allAreas,
                                stateByArea: stateByArea
                            ) { updated in
                                store.updateVerification(updated, for: project.id)
                            }
                            EvidencePanel(store: store, projectID: project.id, area: record.area)
                        }
                    }
                    timeline(snapshot)
                }
            }
        } else {
            ContentUnavailableView("Open a project", systemImage: "checklist", description: Text("Select a project to track what has been verified."))
        }
    }

    private func header(project: ProjectContext, snapshot: RepoSnapshot) -> some View {
        let s = snapshot.verificationSummary
        return VStack(alignment: .leading, spacing: 10) {
            Text("Verification — \(project.name)")
                .font(.title2.weight(.semibold))
            Text("Record what you have actually verified. This drives the reality score; unknown never counts as healthy.")
                .font(.caption)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                CountChip(label: "Verified", count: s.verified, color: .green)
                CountChip(label: "In Progress", count: s.inProgress, color: .blue)
                CountChip(label: "Failed", count: s.failed, color: .red)
                CountChip(label: "Unknown", count: s.unknown, color: .gray)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private func packsPicker(snapshot: RepoSnapshot, projectID: UUID) -> some View {
        let packs = store.verificationPacks(for: snapshot.identity.kind)
        if !packs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "shippingbox.and.arrow.backward")
                        .foregroundStyle(.purple)
                    Text("Verification Packs")
                        .font(.headline)
                    Spacer()
                    Text("One-click area + dependency seed")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                ForEach(packs) { pack in
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(pack.name)
                                .font(.system(size: 14, weight: .semibold))
                            Text(pack.blurb)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("Areas: \(pack.areas.map(\.area).joined(separator: ", "))")
                                .font(.caption2.monospaced())
                                .foregroundStyle(.tertiary)
                                .lineLimit(2)
                        }
                        Spacer()
                        Button("Apply Pack") {
                            store.applyVerificationPack(pack, for: projectID)
                        }
                        .controlSize(.regular)
                    }
                    .padding(10)
                    .background(Color.purple.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }

    private func timeline(_ snapshot: RepoSnapshot) -> some View {
        let records = VerificationEngine().timeline(snapshot.verification)
        return VStack(alignment: .leading, spacing: 10) {
            Text("Verification Timeline")
                .font(.title3.weight(.semibold))
            ForEach(records) { record in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: record.state.symbolName)
                        .foregroundStyle(color(record.state))
                        .frame(width: 22)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(record.area)
                            .font(.headline)
                        Text(record.state.rawValue)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(color(record.state))
                        if !record.note.isEmpty {
                            Text(record.note)
                                .foregroundStyle(.secondary)
                        }
                        Text("\(record.verifiedBy.isEmpty ? "Unknown verifier" : record.verifiedBy) · \(record.updatedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }
                .padding()
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func color(_ state: VerificationState) -> Color {
        switch state {
        case .verified: .green
        case .inProgress: .blue
        case .failed: .red
        case .unknown: .gray
        }
    }
}

private struct PriorityChip: View {
    var priority: VerificationPriority

    private var color: Color {
        switch priority {
        case .critical: .red
        case .high: .orange
        case .medium: .blue
        case .low: .gray
        }
    }

    var body: some View {
        Label(priority.rawValue, systemImage: priority.symbolName)
            .font(.caption.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct AgeChip: View {
    var age: VerificationAge
    var description: String

    private var color: Color {
        switch age {
        case .fresh: .green
        case .recent: .mint
        case .ageing: .yellow
        case .stale: .orange
        case .expired: .red
        case .never: .gray
        }
    }

    var body: some View {
        Label(description.isEmpty ? age.rawValue : description, systemImage: "clock")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}

private struct CountChip: View {
    var label: String
    var count: Int
    var color: Color

    var body: some View {
        HStack(spacing: 6) {
            Text("\(count)")
                .font(.headline.weight(.bold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 7)
        .background(color.opacity(0.16), in: Capsule())
    }
}

private struct VerificationRow: View {
    var record: VerificationRecord
    var priority: VerificationPriority
    var allAreas: [String]
    var stateByArea: [String: VerificationState]
    var onChange: (VerificationRecord) -> Void

    @State private var note: String
    @State private var verifiedBy: String
    @State private var dependsOnText: String

    init(
        record: VerificationRecord,
        priority: VerificationPriority,
        allAreas: [String] = [],
        stateByArea: [String: VerificationState] = [:],
        onChange: @escaping (VerificationRecord) -> Void
    ) {
        self.record = record
        self.priority = priority
        self.allAreas = allAreas
        self.stateByArea = stateByArea
        self.onChange = onChange
        _note = State(initialValue: record.note)
        _verifiedBy = State(initialValue: record.verifiedBy)
        _dependsOnText = State(initialValue: record.dependsOn.joined(separator: ", "))
    }

    private var blockers: [String] {
        record.dependsOn.compactMap { dep in
            let s = stateByArea[dep] ?? .unknown
            return s == .verified ? nil : "\(dep) (\(s.rawValue))"
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: record.state.symbolName)
                .foregroundStyle(color(record.state))
                .font(.title2)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(record.area)
                        .font(.system(size: 18, weight: .semibold))
                    PriorityChip(priority: priority)
                    if record.state == .verified {
                        AgeChip(age: record.age, description: record.ageDescription)
                    }
                    Spacer()
                    Picker("", selection: stateBinding) {
                        ForEach(VerificationState.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 160)
                }
                TextField("Evidence / note (optional)", text: $note, onCommit: commit)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                TextField("Verified by", text: $verifiedBy, onCommit: commit)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 14))
                TextField("Depends on (comma-separated area names)", text: $dependsOnText, onCommit: commit)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                if !blockers.isEmpty {
                    Label("Blocked by: \(blockers.joined(separator: ", "))", systemImage: "arrow.triangle.branch")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                if record.state != .unknown {
                    Text("Last updated \(record.updatedAt.formatted(date: .abbreviated, time: .shortened)) — \(record.ageDescription)")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(12)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private var parsedDependsOn: [String] {
        dependsOnText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    private var stateBinding: Binding<VerificationState> {
        Binding(
            get: { record.state },
            set: { newState in
                onChange(VerificationRecord(
                    id: record.id,
                    area: record.area,
                    state: newState,
                    note: note,
                    verifiedBy: verifiedBy,
                    updatedAt: Date(),
                    dependsOn: parsedDependsOn
                ))
            }
        )
    }

    private func commit() {
        onChange(VerificationRecord(
            id: record.id,
            area: record.area,
            state: record.state,
            note: note,
            verifiedBy: verifiedBy,
            updatedAt: Date(),
            dependsOn: parsedDependsOn
        ))
    }

    private func color(_ state: VerificationState) -> Color {
        switch state {
        case .verified: .green
        case .inProgress: .blue
        case .failed: .red
        case .unknown: .gray
        }
    }
}
