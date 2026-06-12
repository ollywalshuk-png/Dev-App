import AppKit
import LocalForgeCore
import SwiftUI

/// Phase 7 — Evidence Layer. Compact panel that lives under a verification row.
/// Holds the evidence records that justify the row's state.
struct EvidencePanel: View {
    @ObservedObject var store: WorkspaceStore
    var projectID: UUID
    var area: String

    @State private var draftSummary = ""
    @State private var draftBody = ""
    @State private var draftKind: EvidenceKind = .observation
    @State private var draftClass: EvidenceClassification = .observed
    @State private var draftAuthor = ""
    @State private var draftPath = ""

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "paperclip")
                    .foregroundStyle(.tertiary)
                Text("EVIDENCE")
                    .font(.caption2.weight(.bold))
                    .tracking(0.6)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("\(records.count) record(s)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            if !records.isEmpty {
                EvidenceAuditSummary(records: records)
            }

            ForEach(records) { record in
                EvidenceRow(
                    record: record,
                    related: relatedWithoutVerification(record),
                    linkSections: linkSections(for: record)
                ) {
                    store.removeEvidence(id: record.id, for: projectID)
                }
            }

            composer
        }
        .padding(10)
        .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 8))
    }

    private var records: [EvidenceRecord] {
        store.evidence(for: projectID, area: area)
    }

    /// The verification record this panel's area belongs to — new evidence is
    /// auto-linked to it by UUID, not just by area name.
    private var verificationID: UUID? {
        store.snapshots[projectID]?.verification.first { $0.area == area }?.id
    }

    /// Related records for an evidence row, minus verification — inside this
    /// panel the verification context is the row we're already sitting under.
    private func relatedWithoutVerification(_ record: EvidenceRecord) -> RelatedRecords {
        var related = store.relatedRecords(for: .evidence(record.id), projectID: projectID)
        related.verification = []
        return related
    }

    private func linkSections(for record: EvidenceRecord) -> [LinkSection] {
        [
            LinkSection(
                label: "Risks", symbol: "exclamationmark.shield",
                candidates: store.risks(for: projectID).map { LinkCandidate(id: $0.id, title: $0.title) },
                isLinked: { record.linkedRiskIDs.contains($0) },
                toggle: { id in
                    var copy = record; copy.linkedRiskIDs = toggledLink(copy.linkedRiskIDs, id)
                    store.updateEvidence(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Decisions", symbol: "signpost.right",
                candidates: store.decisions(for: projectID).map { LinkCandidate(id: $0.id, title: $0.title) },
                isLinked: { record.linkedDecisionIDs.contains($0) },
                toggle: { id in
                    var copy = record; copy.linkedDecisionIDs = toggledLink(copy.linkedDecisionIDs, id)
                    store.updateEvidence(copy, for: projectID)
                }
            ),
            LinkSection(
                label: "Architecture", symbol: "square.3.layers.3d",
                candidates: store.architecture(for: projectID).map { LinkCandidate(id: $0.id, title: $0.name) },
                isLinked: { record.linkedArchitectureIDs.contains($0) },
                toggle: { id in
                    var copy = record; copy.linkedArchitectureIDs = toggledLink(copy.linkedArchitectureIDs, id)
                    store.updateEvidence(copy, for: projectID)
                }
            )
        ]
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Picker("", selection: $draftKind) {
                    ForEach(EvidenceKind.allCases, id: \.self) { kind in
                        Label(kind.rawValue, systemImage: kind.symbolName).tag(kind)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 170)
                Picker("", selection: $draftClass) {
                    ForEach(EvidenceClassification.allCases, id: \.self) { c in
                        Text(c.rawValue).tag(c)
                    }
                }
                .labelsHidden()
                .frame(maxWidth: 130)
            }
            TextField("Summary (e.g. 'Reproduced twice in Logic Pro 11.2')", text: $draftSummary)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            TextField("Detail (steps, environment, log excerpt)", text: $draftBody)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 13))
            HStack(spacing: 6) {
                TextField("Local file path (optional)", text: $draftPath)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                Button {
                    if let url = pickFile() { draftPath = url.path }
                } label: {
                    Image(systemName: "folder")
                }
                .help("Pick a local file to reference (read-only; never uploaded)")
                TextField("By", text: $draftAuthor)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 12))
                    .frame(maxWidth: 120)
                Button("Add Evidence") {
                    let summary = draftSummary.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !summary.isEmpty else { return }
                    let record = EvidenceRecord(
                        area: area,
                        kind: draftKind,
                        summary: summary,
                        body: draftBody.trimmingCharacters(in: .whitespacesAndNewlines),
                        attachmentPath: draftPath.trimmingCharacters(in: .whitespacesAndNewlines),
                        classification: draftClass,
                        author: draftAuthor.trimmingCharacters(in: .whitespacesAndNewlines),
                        linkedVerificationIDs: verificationID.map { [$0] } ?? []
                    )
                    store.addEvidence(record, for: projectID)
                    draftSummary = ""
                    draftBody = ""
                    draftPath = ""
                }
                .buttonStyle(.borderedProminent)
                .disabled(draftSummary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(8)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }

    private func pickFile() -> URL? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }
}

private struct EvidenceRow: View {
    var record: EvidenceRecord
    var related: RelatedRecords
    var linkSections: [LinkSection]
    var onRemove: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: record.kind.symbolName)
                .foregroundStyle(.blue)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(record.summary)
                        .font(.system(size: 13, weight: .semibold))
                    Tag(text: record.kind.rawValue, color: .blue)
                    Tag(text: record.classification.rawValue, color: classificationColor(record.classification))
                    Spacer()
                    Text(record.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    TruthLinkMenu(sections: linkSections)
                    Button(role: .destructive) {
                        onRemove()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
                EvidenceAuditLine(record: record)
                if !record.body.isEmpty {
                    Text(record.body)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if !record.attachmentPath.isEmpty {
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text(record.attachmentPath)
                            .font(.caption2.monospaced())
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                            .textSelection(.enabled)
                    }
                }
                RelatedRecordsStrip(related: related)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.secondary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
    }
}

private struct EvidenceAuditSummary: View {
    var records: [EvidenceRecord]

    private var strongCount: Int {
        records.filter { isStrongEvidence($0.classification) }.count
    }

    private var reviewCount: Int {
        records.count - strongCount
    }

    private var missingVerificationLinks: Int {
        records.filter { !hasVerificationLink($0) }.count
    }

    private var newestRecord: EvidenceRecord? {
        records.max { $0.createdAt < $1.createdAt }
    }

    var body: some View {
        HStack(spacing: 6) {
            AuditCue(
                text: "\(strongCount) strong",
                symbol: "checkmark.seal",
                color: strongCount == 0 ? .secondary : .green
            )
            AuditCue(
                text: "\(reviewCount) to review",
                symbol: "questionmark.diamond",
                color: reviewCount == 0 ? .secondary : .orange
            )
            AuditCue(
                text: missingVerificationLinks == 0 ? "Verification-linked" : "\(missingVerificationLinks) no verification link",
                symbol: "link",
                color: missingVerificationLinks == 0 ? .green : .orange
            )
            if let newestRecord {
                AuditCue(
                    text: "Newest \(evidenceAgeDescriptor(newestRecord.createdAt))",
                    symbol: "clock",
                    color: evidenceAgeColor(newestRecord.createdAt)
                )
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct EvidenceAuditLine: View {
    var record: EvidenceRecord

    var body: some View {
        HStack(spacing: 6) {
            AuditCue(
                text: classificationCue(record.classification),
                symbol: classificationSymbol(record.classification),
                color: classificationColor(record.classification)
            )
            AuditCue(
                text: hasVerificationLink(record) ? "Verification-linked" : "No verification link",
                symbol: "checkmark.seal",
                color: hasVerificationLink(record) ? .green : .orange
            )
            AuditCue(
                text: crossLinkText(record),
                symbol: "link",
                color: crossLinkCount(record) == 0 ? .secondary : .blue
            )
            AuditCue(
                text: evidenceAgeText(record.createdAt),
                symbol: "clock",
                color: evidenceAgeColor(record.createdAt)
            )
            if !record.author.isEmpty {
                AuditCue(text: record.author, symbol: "person", color: .secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct AuditCue: View {
    var text: String
    var symbol: String
    var color: Color

    var body: some View {
        Label {
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        } icon: {
            Image(systemName: symbol)
        }
        .font(.caption2.weight(.semibold))
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.12), in: Capsule())
        .foregroundStyle(color)
    }
}

private struct Tag: View {
    var text: String
    var color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.16), in: Capsule())
            .foregroundStyle(color)
    }
}

private func isStrongEvidence(_ classification: EvidenceClassification) -> Bool {
    classification == .observed || classification == .measured || classification == .verified
}

private func classificationColor(_ classification: EvidenceClassification) -> Color {
    switch classification {
    case .verified: .green
    case .measured: .teal
    case .observed: .blue
    case .inferred: .indigo
    case .assumed: .orange
    case .unknown: .red
    }
}

private func classificationCue(_ classification: EvidenceClassification) -> String {
    switch classification {
    case .verified: "Verified evidence"
    case .measured: "Measured evidence"
    case .observed: "Observed evidence"
    case .inferred: "Inference"
    case .assumed: "Assumption"
    case .unknown: "Basis unknown"
    }
}

private func classificationSymbol(_ classification: EvidenceClassification) -> String {
    switch classification {
    case .verified: "checkmark.seal"
    case .measured: "chart.bar"
    case .observed: "eye"
    case .inferred: "arrowshape.turn.up.right"
    case .assumed: "questionmark.diamond"
    case .unknown: "exclamationmark.triangle"
    }
}

private func hasVerificationLink(_ record: EvidenceRecord) -> Bool {
    !record.linkedVerificationIDs.isEmpty
}

private func crossLinkCount(_ record: EvidenceRecord) -> Int {
    record.linkedRiskIDs.count
        + record.linkedDecisionIDs.count
        + record.linkedArchitectureIDs.count
        + record.linkedAssumptionIDs.count
        + record.linkedJournalIDs.count
        + record.linkedNoteIDs.count
        + (record.linkedID == nil ? 0 : 1)
}

private func crossLinkText(_ record: EvidenceRecord) -> String {
    let count = crossLinkCount(record)
    return count == 0 ? "No cross-links" : "\(count) cross-link\(count == 1 ? "" : "s")"
}

private func evidenceAgeText(_ date: Date) -> String {
    "Added \(evidenceAgeDescriptor(date))"
}

private func evidenceAgeDescriptor(_ date: Date) -> String {
    let days = evidenceAgeDays(since: date)
    if days < 0 { return "in future" }
    if days == 0 { return "today" }
    if days == 1 { return "1d ago" }
    if days < 14 { return "\(days)d ago" }
    if days < 60 { return "\(days / 7)w ago" }
    return "\(days / 30)mo ago"
}

private func evidenceAgeColor(_ date: Date) -> Color {
    let days = evidenceAgeDays(since: date)
    if days < 0 { return .red }
    if days <= 7 { return .green }
    if days <= 30 { return .blue }
    if days <= 90 { return .orange }
    return .red
}

private func evidenceAgeDays(since date: Date) -> Int {
    let calendar = Calendar.current
    let createdDay = calendar.startOfDay(for: date)
    let currentDay = calendar.startOfDay(for: Date())
    return calendar.dateComponents([.day], from: createdDay, to: currentDay).day ?? 0
}
