import AppKit
import LocalForgeCore
import SwiftUI

/// Phase 7 — the four registers in a single tabbed view.
/// Decisions · Architecture · Risks · Assumptions.
struct RegistersView: View {
    @ObservedObject var store: WorkspaceStore
    enum Tab: String, CaseIterable, Identifiable {
        case decisions = "Decisions"
        case architecture = "Architecture"
        case risks = "Risks"
        case assumptions = "Assumptions"
        var id: String { rawValue }
        var symbol: String {
            switch self {
            case .decisions: "signpost.right"
            case .architecture: "square.3.layers.3d"
            case .risks: "exclamationmark.shield"
            case .assumptions: "questionmark.diamond"
            }
        }
    }
    @State private var tab: Tab = .decisions

    var body: some View {
        if let project = store.selectedProject {
            VStack(alignment: .leading, spacing: 14) {
                header(project: project)
                Picker("", selection: $tab) {
                    ForEach(Tab.allCases) { t in
                        Label(t.rawValue, systemImage: t.symbol).tag(t)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        switch tab {
                        case .decisions:    DecisionsTab(store: store, projectID: project.id)
                        case .architecture: ArchitectureTab(store: store, projectID: project.id)
                        case .risks:        RisksTab(store: store, projectID: project.id)
                        case .assumptions:  AssumptionsTab(store: store, projectID: project.id)
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
        } else {
            ContentUnavailableView("No active project", systemImage: "list.bullet.rectangle",
                description: Text("Open a project to track its decisions, architecture, risks, and assumptions."))
        }
    }

    private func header(project: ProjectContext) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Registers — \(project.name)")
                .font(.system(size: 30, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text("Why we made the choices we did · what we built · what could go wrong · what we currently believe.")
                .font(.system(size: 14))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Decisions

private struct DecisionsTab: View {
    @ObservedObject var store: WorkspaceStore
    var projectID: UUID
    @State private var draftTitle = ""
    @State private var draftDecision = ""
    @State private var draftReason = ""
    @State private var draftAlternatives = ""
    @State private var draftAuthor = ""
    @State private var draftStatus: DecisionStatus = .accepted

    var body: some View {
        let items = store.decisions(for: projectID)
        VStack(alignment: .leading, spacing: 10) {
            composer
            if items.isEmpty {
                EmptyState(text: "Record why decisions were made. Six months later you'll be grateful.")
            }
            ForEach(items) { d in
                Card {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text(d.title)
                                .font(.system(size: 16, weight: .semibold))
                            Tag(text: d.status.rawValue, color: color(d.status))
                            Spacer()
                            Text(d.updatedAt.formatted(date: .abbreviated, time: .omitted))
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                            linkMenu(for: d)
                            Button(role: .destructive) { store.removeDecision(id: d.id, for: projectID) } label: { Image(systemName: "trash") }
                                .buttonStyle(.borderless)
                        }
                        if !d.decision.isEmpty { Field("Decision", value: d.decision) }
                        if !d.reason.isEmpty { Field("Reason", value: d.reason) }
                        if !d.alternativesConsidered.isEmpty { Field("Alternatives", value: d.alternativesConsidered) }
                        if !d.tradeOffs.isEmpty { Field("Trade-offs", value: d.tradeOffs) }
                        if !d.author.isEmpty {
                            Text("— \(d.author)")
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        RelatedRecordsStrip(related: store.relatedRecords(for: .decision(d.id), projectID: projectID))
                    }
                }
            }
        }
    }

    private var composer: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add Decision").font(.system(size: 15, weight: .semibold))
                TextField("Title (e.g. 'Use AUState for preset persistence')", text: $draftTitle).textFieldStyle(.roundedBorder)
                TextField("Decision (what we chose)", text: $draftDecision).textFieldStyle(.roundedBorder)
                TextField("Reason (why)", text: $draftReason).textFieldStyle(.roundedBorder)
                TextField("Alternatives considered", text: $draftAlternatives).textFieldStyle(.roundedBorder)
                HStack {
                    TextField("Author", text: $draftAuthor).textFieldStyle(.roundedBorder).frame(maxWidth: 180)
                    Picker("", selection: $draftStatus) {
                        ForEach(DecisionStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().frame(maxWidth: 160)
                    Spacer()
                    Button("Save") {
                        let title = draftTitle.trimmingCharacters(in: .whitespaces); guard !title.isEmpty else { return }
                        store.addDecision(.init(title: title, decision: draftDecision, reason: draftReason, alternativesConsidered: draftAlternatives, status: draftStatus, author: draftAuthor), for: projectID)
                        draftTitle = ""; draftDecision = ""; draftReason = ""; draftAlternatives = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draftTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func linkMenu(for d: DecisionRecord) -> some View {
        TruthLinkMenu(sections: [
            LinkSection(
                label: "Evidence", symbol: "paperclip",
                candidates: store.evidence(for: projectID).map { LinkCandidate(id: $0.id, title: $0.summary) },
                isLinked: { d.linkedEvidenceIDs.contains($0) },
                toggle: { id in
                    var copy = d; copy.linkedEvidenceIDs = toggledLink(copy.linkedEvidenceIDs, id)
                    store.updateDecision(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Risks", symbol: "exclamationmark.shield",
                candidates: store.risks(for: projectID).map { LinkCandidate(id: $0.id, title: $0.title) },
                isLinked: { d.linkedRiskIDs.contains($0) },
                toggle: { id in
                    var copy = d; copy.linkedRiskIDs = toggledLink(copy.linkedRiskIDs, id)
                    store.updateDecision(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Architecture", symbol: "square.3.layers.3d",
                candidates: store.architecture(for: projectID).map { LinkCandidate(id: $0.id, title: $0.name) },
                isLinked: { d.linkedArchitectureIDs.contains($0) },
                toggle: { id in
                    var copy = d; copy.linkedArchitectureIDs = toggledLink(copy.linkedArchitectureIDs, id)
                    store.updateDecision(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Verification", symbol: "checkmark.seal",
                candidates: (store.selectedSnapshot?.verification ?? []).map { LinkCandidate(id: $0.id, title: $0.area) },
                isLinked: { d.linkedVerificationIDs.contains($0) },
                toggle: { id in
                    var copy = d; copy.linkedVerificationIDs = toggledLink(copy.linkedVerificationIDs, id)
                    store.updateDecision(copy, for: projectID)
                }
            )
        ])
    }

    private func color(_ status: DecisionStatus) -> Color {
        switch status {
        case .proposed: .blue; case .accepted: .green; case .rejected: .red
        case .superseded: .orange; case .deprecated: .gray; case .needsReview: .yellow
        }
    }
}

// MARK: - Architecture

private struct ArchitectureTab: View {
    @ObservedObject var store: WorkspaceStore
    var projectID: UUID
    @State private var draftName = ""
    @State private var draftPurpose = ""
    @State private var draftDeps = ""
    @State private var draftAreas = ""
    @State private var draftType: SubsystemType = .unknown
    @State private var draftStatus: ArchitectureStatus = .live

    var body: some View {
        let items = store.architecture(for: projectID)
        VStack(alignment: .leading, spacing: 10) {
            composer
            if items.isEmpty {
                EmptyState(text: "Track subsystems and their relationships. Maps directly onto Verification dependencies.")
            }
            ForEach(items) { a in
                Card {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(a.name).font(.system(size: 16, weight: .semibold))
                            Tag(text: a.subsystemType.rawValue, color: .indigo)
                            Tag(text: a.status.rawValue, color: color(a.status))
                            Spacer()
                            linkMenu(for: a)
                            Button(role: .destructive) { store.removeArchitectureItem(id: a.id, for: projectID) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }
                        if !a.purpose.isEmpty { Field("Purpose", value: a.purpose) }
                        if !a.dependencies.isEmpty { Field("Depends on", value: a.dependencies.joined(separator: ", ")) }
                        if !a.linkedVerificationAreas.isEmpty { Field("Verification areas", value: a.linkedVerificationAreas.joined(separator: ", ")) }
                        if !a.notes.isEmpty { Field("Notes", value: a.notes) }
                        RelatedRecordsStrip(related: store.relatedRecords(for: .architecture(a.id), projectID: projectID))
                    }
                }
            }
        }
    }

    private var composer: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add Architecture Item").font(.system(size: 15, weight: .semibold))
                TextField("Name (e.g. 'Preset System')", text: $draftName).textFieldStyle(.roundedBorder)
                TextField("Purpose", text: $draftPurpose).textFieldStyle(.roundedBorder)
                TextField("Dependencies (comma-separated)", text: $draftDeps).textFieldStyle(.roundedBorder)
                TextField("Verification areas (comma-separated)", text: $draftAreas).textFieldStyle(.roundedBorder)
                HStack {
                    Picker("", selection: $draftType) {
                        ForEach(SubsystemType.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().frame(maxWidth: 200)
                    Picker("", selection: $draftStatus) {
                        ForEach(ArchitectureStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden().frame(maxWidth: 160)
                    Spacer()
                    Button("Save") {
                        let name = draftName.trimmingCharacters(in: .whitespaces); guard !name.isEmpty else { return }
                        store.addArchitectureItem(.init(name: name, subsystemType: draftType, purpose: draftPurpose, status: draftStatus,
                            dependencies: lines(draftDeps), linkedVerificationAreas: lines(draftAreas)), for: projectID)
                        draftName = ""; draftPurpose = ""; draftDeps = ""; draftAreas = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draftName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func linkMenu(for a: ArchitectureItem) -> some View {
        TruthLinkMenu(sections: [
            LinkSection(
                label: "Evidence", symbol: "paperclip",
                candidates: store.evidence(for: projectID).map { LinkCandidate(id: $0.id, title: $0.summary) },
                isLinked: { a.linkedEvidenceIDs.contains($0) },
                toggle: { id in
                    var copy = a; copy.linkedEvidenceIDs = toggledLink(copy.linkedEvidenceIDs, id)
                    store.updateArchitectureItem(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Risks", symbol: "exclamationmark.shield",
                candidates: store.risks(for: projectID).map { LinkCandidate(id: $0.id, title: $0.title) },
                isLinked: { a.linkedRiskIDs.contains($0) },
                toggle: { id in
                    var copy = a; copy.linkedRiskIDs = toggledLink(copy.linkedRiskIDs, id)
                    store.updateArchitectureItem(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Decisions", symbol: "signpost.right",
                candidates: store.decisions(for: projectID).map { LinkCandidate(id: $0.id, title: $0.title) },
                isLinked: { a.linkedDecisionIDs.contains($0) },
                toggle: { id in
                    var copy = a; copy.linkedDecisionIDs = toggledLink(copy.linkedDecisionIDs, id)
                    store.updateArchitectureItem(copy, for: projectID)
                }
            )
        ])
    }

    private func lines(_ text: String) -> [String] {
        text.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
    }
    private func color(_ s: ArchitectureStatus) -> Color {
        switch s { case .planned: .blue; case .inProgress: .yellow; case .live: .green; case .failing: .red; case .needsReview: .orange; case .deprecated: .gray }
    }
}

// MARK: - Risks

private struct RisksTab: View {
    @ObservedObject var store: WorkspaceStore
    var projectID: UUID
    @State private var draftTitle = ""
    @State private var draftDesc = ""
    @State private var draftMit = ""
    @State private var draftLikelihood: RiskLikelihood = .medium
    @State private var draftImpact: RiskImpact = .medium
    @State private var draftStatus: RiskStatus = .open

    var body: some View {
        let items = store.risks(for: projectID)
        VStack(alignment: .leading, spacing: 10) {
            composer
            if items.isEmpty {
                EmptyState(text: "Future risk lives here. Observed failures live in Verification.")
            }
            ForEach(items) { r in
                Card {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(r.title).font(.system(size: 16, weight: .semibold))
                            Tag(text: r.impact.rawValue, color: impactColor(r.impact))
                            Tag(text: r.likelihood.rawValue, color: .blue)
                            Tag(text: r.status.rawValue, color: statusColor(r.status))
                            if r.isReleaseBlocking { Tag(text: "Release-blocking", color: .red) }
                            Spacer()
                            linkMenu(for: r)
                            Button(role: .destructive) { store.removeRisk(id: r.id, for: projectID) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }
                        if !r.description.isEmpty { Field("Description", value: r.description) }
                        if !r.mitigation.isEmpty { Field("Mitigation", value: r.mitigation) }
                        if !r.contingency.isEmpty { Field("Contingency", value: r.contingency) }
                        RelatedRecordsStrip(related: store.relatedRecords(for: .risk(r.id), projectID: projectID))
                    }
                }
            }
        }
    }

    private var composer: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add Risk").font(.system(size: 15, weight: .semibold))
                TextField("Title (e.g. 'Preset corruption')", text: $draftTitle).textFieldStyle(.roundedBorder)
                TextField("Description", text: $draftDesc).textFieldStyle(.roundedBorder)
                TextField("Mitigation", text: $draftMit).textFieldStyle(.roundedBorder)
                HStack {
                    Picker("", selection: $draftLikelihood) {
                        ForEach(RiskLikelihood.allCases, id: \.self) { Text("Lik: \($0.rawValue)").tag($0) }
                    }.labelsHidden()
                    Picker("", selection: $draftImpact) {
                        ForEach(RiskImpact.allCases, id: \.self) { Text("Imp: \($0.rawValue)").tag($0) }
                    }.labelsHidden()
                    Picker("", selection: $draftStatus) {
                        ForEach(RiskStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden()
                    Spacer()
                    Button("Save") {
                        let title = draftTitle.trimmingCharacters(in: .whitespaces); guard !title.isEmpty else { return }
                        store.addRisk(.init(title: title, description: draftDesc, likelihood: draftLikelihood, impact: draftImpact, status: draftStatus, mitigation: draftMit), for: projectID)
                        draftTitle = ""; draftDesc = ""; draftMit = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draftTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func linkMenu(for r: RiskRecord) -> some View {
        TruthLinkMenu(sections: [
            LinkSection(
                label: "Evidence", symbol: "paperclip",
                candidates: store.evidence(for: projectID).map { LinkCandidate(id: $0.id, title: $0.summary) },
                isLinked: { r.linkedEvidenceIDs.contains($0) },
                toggle: { id in
                    var copy = r; copy.linkedEvidenceIDs = toggledLink(copy.linkedEvidenceIDs, id)
                    store.updateRisk(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Decisions", symbol: "signpost.right",
                candidates: store.decisions(for: projectID).map { LinkCandidate(id: $0.id, title: $0.title) },
                isLinked: { r.linkedDecisionIDs.contains($0) },
                toggle: { id in
                    var copy = r; copy.linkedDecisionIDs = toggledLink(copy.linkedDecisionIDs, id)
                    store.updateRisk(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Architecture", symbol: "square.3.layers.3d",
                candidates: store.architecture(for: projectID).map { LinkCandidate(id: $0.id, title: $0.name) },
                isLinked: { r.linkedArchitectureIDs.contains($0) },
                toggle: { id in
                    var copy = r; copy.linkedArchitectureIDs = toggledLink(copy.linkedArchitectureIDs, id)
                    store.updateRisk(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Verification", symbol: "checkmark.seal",
                candidates: (store.selectedSnapshot?.verification ?? []).map { LinkCandidate(id: $0.id, title: $0.area) },
                isLinked: { r.linkedVerificationIDs.contains($0) },
                toggle: { id in
                    var copy = r; copy.linkedVerificationIDs = toggledLink(copy.linkedVerificationIDs, id)
                    store.updateRisk(copy, for: projectID)
                }
            )
        ])
    }

    private func impactColor(_ i: RiskImpact) -> Color {
        switch i { case .low: .gray; case .medium: .blue; case .high: .orange; case .critical: .red }
    }
    private func statusColor(_ s: RiskStatus) -> Color {
        switch s { case .open: .red; case .monitoring: .orange; case .mitigated: .green; case .accepted: .blue; case .closed: .gray }
    }
}

// MARK: - Assumptions

private struct AssumptionsTab: View {
    @ObservedObject var store: WorkspaceStore
    var projectID: UUID
    @State private var draftText = ""
    @State private var draftRationale = ""
    @State private var draftVerify = ""
    @State private var draftConfidence: EvidenceClassification = .assumed
    @State private var draftStatus: AssumptionStatus = .active

    var body: some View {
        let items = store.assumptions(for: projectID)
        VStack(alignment: .leading, spacing: 10) {
            composer
            if items.isEmpty {
                EmptyState(text: "Capture beliefs you haven't verified yet. Once verified, supersede them with evidence.")
            }
            ForEach(items) { a in
                Card {
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(a.assumption).font(.system(size: 16, weight: .semibold))
                            Tag(text: a.confidence.rawValue, color: .blue)
                            Tag(text: a.status.rawValue, color: statusColor(a.status))
                            Spacer()
                            linkMenu(for: a)
                            Button(role: .destructive) { store.removeAssumption(id: a.id, for: projectID) } label: { Image(systemName: "trash") }.buttonStyle(.borderless)
                        }
                        if !a.rationale.isEmpty { Field("Rationale", value: a.rationale) }
                        if !a.verificationNeeded.isEmpty { Field("Verification needed", value: a.verificationNeeded) }
                        if !a.linkedVerificationArea.isEmpty { Field("Linked area", value: a.linkedVerificationArea) }
                        RelatedRecordsStrip(related: store.relatedRecords(for: .assumption(a.id), projectID: projectID))
                    }
                }
            }
        }
    }

    private var composer: some View {
        Card {
            VStack(alignment: .leading, spacing: 6) {
                Text("Add Assumption").font(.system(size: 15, weight: .semibold))
                TextField("Assumption (e.g. 'Logic restores AUState correctly')", text: $draftText).textFieldStyle(.roundedBorder)
                TextField("Rationale", text: $draftRationale).textFieldStyle(.roundedBorder)
                TextField("Verification needed", text: $draftVerify).textFieldStyle(.roundedBorder)
                HStack {
                    Picker("", selection: $draftConfidence) {
                        ForEach(EvidenceClassification.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden()
                    Picker("", selection: $draftStatus) {
                        ForEach(AssumptionStatus.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                    }.labelsHidden()
                    Spacer()
                    Button("Save") {
                        let t = draftText.trimmingCharacters(in: .whitespaces); guard !t.isEmpty else { return }
                        store.addAssumption(.init(assumption: t, rationale: draftRationale, confidence: draftConfidence, verificationNeeded: draftVerify, status: draftStatus), for: projectID)
                        draftText = ""; draftRationale = ""; draftVerify = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(draftText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func linkMenu(for a: AssumptionRecord) -> some View {
        TruthLinkMenu(sections: [
            LinkSection(
                label: "Evidence", symbol: "paperclip",
                candidates: store.evidence(for: projectID).map { LinkCandidate(id: $0.id, title: $0.summary) },
                isLinked: { a.linkedEvidenceIDs.contains($0) },
                toggle: { id in
                    var copy = a; copy.linkedEvidenceIDs = toggledLink(copy.linkedEvidenceIDs, id)
                    store.updateAssumption(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Risks", symbol: "exclamationmark.shield",
                candidates: store.risks(for: projectID).map { LinkCandidate(id: $0.id, title: $0.title) },
                isLinked: { a.linkedRiskIDs.contains($0) },
                toggle: { id in
                    var copy = a; copy.linkedRiskIDs = toggledLink(copy.linkedRiskIDs, id)
                    store.updateAssumption(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Verification", symbol: "checkmark.seal",
                candidates: (store.selectedSnapshot?.verification ?? []).map { LinkCandidate(id: $0.id, title: $0.area) },
                isLinked: { a.linkedVerificationIDs.contains($0) },
                toggle: { id in
                    var copy = a; copy.linkedVerificationIDs = toggledLink(copy.linkedVerificationIDs, id)
                    store.updateAssumption(copy, for: projectID)
                }
            )
        ])
    }

    private func statusColor(_ s: AssumptionStatus) -> Color {
        switch s { case .active: .orange; case .verified: .green; case .disproved: .red; case .superseded: .gray; case .needsReview: .yellow }
    }
}

// MARK: - Shared bits

private struct Card<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        VStack(alignment: .leading, spacing: 6) { content() }
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct Tag: View {
    var text: String; var color: Color
    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(color.opacity(0.16), in: Capsule()).foregroundStyle(color)
    }
}

private struct Field: View {
    var label: String; var value: String
    init(_ label: String, value: String) { self.label = label; self.value = value }
    var body: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(label.uppercased()).font(.caption2.weight(.bold)).tracking(0.4).foregroundStyle(.tertiary)
            Text(value).font(.system(size: 14)).foregroundStyle(.secondary).textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct EmptyState: View {
    var text: String
    var body: some View {
        Text(text)
            .font(.system(size: 14))
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
