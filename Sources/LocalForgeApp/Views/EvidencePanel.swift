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
                    Tag(text: record.classification.rawValue, color: .green)
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
