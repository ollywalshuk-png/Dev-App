import LocalForgeCore
import SwiftUI

/// Lets the user replace the inferred mission with a real one: what it is trying
/// to be, its goals, the current phase, and known issues. Stored locally.
struct MissionEditorView: View {
    var identity: ProjectIdentity
    var inferred: MissionProfile
    var existing: UserMissionProfile?
    var onSave: (UserMissionProfile) -> Void
    var onCancel: () -> Void

    @State private var statedMission: String
    @State private var category: MissionCategory
    @State private var goalsText: String
    @State private var currentPhase: String
    @State private var knownIssuesText: String

    init(
        identity: ProjectIdentity,
        inferred: MissionProfile,
        existing: UserMissionProfile?,
        onSave: @escaping (UserMissionProfile) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.identity = identity
        self.inferred = inferred
        self.existing = existing
        self.onSave = onSave
        self.onCancel = onCancel
        _statedMission = State(initialValue: existing?.statedMission ?? "")
        _category = State(initialValue: existing?.category ?? inferred.category)
        _goalsText = State(initialValue: (existing?.goals ?? []).joined(separator: "\n"))
        _currentPhase = State(initialValue: existing?.currentPhase ?? "")
        _knownIssuesText = State(initialValue: (existing?.knownIssues ?? []).joined(separator: "\n"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Label("Define Mission", systemImage: "scope")
                    .font(.title2.weight(.semibold))
                Spacer()
                ProjectKindBadge(identity: identity)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    templatesRow
                    field("Mission", help: "What is this project, in one line?") {
                        TextField(inferred.statedMission, text: $statedMission)
                            .textFieldStyle(.roundedBorder)
                    }

                    field("Category", help: nil) {
                        Picker("", selection: $category) {
                            ForEach(MissionCategory.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                        }
                        .labelsHidden()
                    }

                    field("Current Phase", help: "e.g. UI refinement, DSP work, release prep") {
                        TextField("Current phase", text: $currentPhase)
                            .textFieldStyle(.roundedBorder)
                    }

                    field("Goals", help: "One per line.") {
                        TextEditor(text: $goalsText)
                            .font(.body)
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    }

                    field("Known Issues", help: "One per line. These become tracked risks.") {
                        TextEditor(text: $knownIssuesText)
                            .font(.body)
                            .frame(minHeight: 90)
                            .overlay(RoundedRectangle(cornerRadius: 6).stroke(.quaternary))
                    }
                }
                .padding()
            }

            Divider()

            HStack {
                if existing != nil {
                    Button(role: .destructive) {
                        onSave(UserMissionProfile(statedMission: ""))
                    } label: {
                        Label("Clear Mission", systemImage: "trash")
                    }
                }
                Spacer()
                Button("Cancel", action: onCancel)
                Button("Save Mission") { save() }
                    .keyboardShortcut(.defaultAction)
                    .disabled(statedMission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding()
        }
        .frame(width: 540, height: 560)
    }

    @ViewBuilder
    private var templatesRow: some View {
        let templates = MissionTemplateCatalogue().templates(for: identity.kind)
        if !templates.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Start from a template")
                    .font(.subheadline.weight(.semibold))
                Text("Pre-fills mission, category, phase, and goals. You can still edit everything below.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(templates) { template in
                            Button {
                                apply(template)
                            } label: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(template.name)
                                        .font(.system(size: 14, weight: .semibold))
                                    Text(template.blurb)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(2)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(width: 220, alignment: .leading)
                                .padding(10)
                                .background(Color.purple.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private func apply(_ template: MissionTemplate) {
        statedMission = template.statedMission
        category = template.category
        currentPhase = template.defaultPhase
        goalsText = template.defaultGoals.joined(separator: "\n")
    }

    private func save() {
        let profile = UserMissionProfile(
            statedMission: statedMission.trimmingCharacters(in: .whitespacesAndNewlines),
            category: category,
            goals: lines(goalsText),
            currentPhase: currentPhase.trimmingCharacters(in: .whitespacesAndNewlines),
            knownIssues: lines(knownIssuesText)
        )
        onSave(profile)
    }

    private func lines(_ text: String) -> [String] {
        text.split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    @ViewBuilder
    private func field<Content: View>(_ label: String, help: String?, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label)
                .font(.subheadline.weight(.semibold))
            if let help {
                Text(help)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            content()
        }
    }
}
