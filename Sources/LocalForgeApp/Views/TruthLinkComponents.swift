import LocalForgeCore
import SwiftUI

/// Phase 7.5 — shared cross-linking UI.
/// `TruthLinkMenu` toggles UUID links on a record; `RelatedRecordsStrip` shows
/// everything connected to it (resolved both directions by the TruthEngine).

/// One linkable target shown in the menu.
struct LinkCandidate: Identifiable {
    let id: UUID
    let title: String
}

/// A group of candidates of one record type, with its current-link test and toggle.
struct LinkSection: Identifiable {
    let label: String
    let symbol: String
    let candidates: [LinkCandidate]
    let isLinked: (UUID) -> Bool
    let toggle: (UUID) -> Void
    var id: String { label }
}

/// Toggle an id in a link array (the helper every toggle closure uses).
func toggledLink(_ ids: [UUID], _ id: UUID) -> [UUID] {
    ids.contains(id) ? ids.filter { $0 != id } : ids + [id]
}

struct TruthLinkMenu: View {
    var sections: [LinkSection]

    private var hasCandidates: Bool {
        sections.contains { !$0.candidates.isEmpty }
    }

    var body: some View {
        if hasCandidates {
            Menu {
                ForEach(sections) { section in
                    if !section.candidates.isEmpty {
                        Section(section.label) {
                            ForEach(section.candidates) { candidate in
                                Button {
                                    section.toggle(candidate.id)
                                } label: {
                                    if section.isLinked(candidate.id) {
                                        Label(candidate.title, systemImage: "checkmark")
                                    } else {
                                        Text(candidate.title)
                                    }
                                }
                            }
                        }
                    }
                }
            } label: {
                Image(systemName: "link")
                    .font(.caption)
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Link this record to evidence, risks, decisions, architecture, or verification")
        }
    }
}

/// Compact "RELATED" block: one line per connected record type, names joined.
struct RelatedRecordsStrip: View {
    var related: RelatedRecords

    var body: some View {
        if !related.isEmpty {
            VStack(alignment: .leading, spacing: 3) {
                Text("RELATED")
                    .font(.caption2.weight(.bold))
                    .tracking(0.4)
                    .foregroundStyle(.tertiary)
                relatedLine("checkmark.seal", "Verification", related.verification.map(\.area), .green)
                relatedLine("paperclip", "Evidence", related.evidence.map(\.summary), .indigo)
                relatedLine("exclamationmark.shield", "Risks", related.risks.map(\.title), .red)
                relatedLine("signpost.right", "Decisions", related.decisions.map(\.title), .purple)
                relatedLine("square.3.layers.3d", "Architecture", related.architecture.map(\.name), .teal)
                relatedLine("questionmark.diamond", "Assumptions", related.assumptions.map(\.assumption), .orange)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.secondary.opacity(0.05), in: RoundedRectangle(cornerRadius: 6))
        }
    }

    @ViewBuilder
    private func relatedLine(_ symbol: String, _ label: String, _ names: [String], _ color: Color) -> some View {
        if !names.isEmpty {
            HStack(alignment: .firstTextBaseline, spacing: 5) {
                Image(systemName: symbol)
                    .font(.caption2)
                    .foregroundStyle(color)
                    .frame(width: 14)
                Text("\(label):")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(color)
                Text(names.joined(separator: " · "))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
