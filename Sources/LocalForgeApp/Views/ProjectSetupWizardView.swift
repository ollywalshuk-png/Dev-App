import LocalForgeCore
import SwiftUI

struct ProjectSetupWizardView: View {
    var project: ProjectContext
    var snapshot: RepoSnapshot
    var onSave: (ProjectSetupDraft) -> Void
    var onCancel: () -> Void

    @State private var mission: String
    @State private var category: MissionCategory
    @State private var currentPhase: String
    @State private var author: String
    @State private var selectedAreas: Set<String>

    init(
        project: ProjectContext,
        snapshot: RepoSnapshot,
        onSave: @escaping (ProjectSetupDraft) -> Void,
        onCancel: @escaping () -> Void
    ) {
        self.project = project
        self.snapshot = snapshot
        self.onSave = onSave
        self.onCancel = onCancel
        _mission = State(initialValue: snapshot.mission.statedMission == "Mission not yet determined" ? "" : snapshot.mission.statedMission)
        _category = State(initialValue: snapshot.mission.category)
        _currentPhase = State(initialValue: "")
        _author = State(initialValue: NSFullUserName())
        _selectedAreas = State(initialValue: Set(snapshot.applicability.filter { $0.status.inScope }.map(\.area)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    projectTypeStep
                    missionStep
                    phaseStep
                    verificationStep
                }
                .padding()
            }
            Divider()
            footer
        }
        .frame(width: 640, height: 680)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Project Setup")
                    .font(.title2.weight(.semibold))
                Text(project.name)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            ProjectKindBadge(identity: snapshot.identity)
        }
        .padding()
    }

    private var projectTypeStep: some View {
        SetupSection(number: 1, title: "Project Type") {
            HStack {
                Image(systemName: snapshot.identity.kind.symbolName)
                    .font(.title2)
                    .foregroundStyle(snapshot.identity.kind.tint)
                VStack(alignment: .leading, spacing: 4) {
                    Text(snapshot.identity.kind.rawValue)
                        .font(.headline)
                    Text("Detected from local project files. Override of project type is deferred; mission category can be set below.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Text(snapshot.identity.confidence.rawValue)
                    .font(.caption.weight(.medium))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.quaternary, in: Capsule())
            }
        }
    }

    private var missionStep: some View {
        SetupSection(number: 2, title: "Mission") {
            VStack(alignment: .leading, spacing: 8) {
                TextField("What are you building?", text: $mission)
                    .textFieldStyle(.roundedBorder)
                Picker("Category", selection: $category) {
                    ForEach(MissionCategory.allCases, id: \.self) { category in
                        Text(category.rawValue).tag(category)
                    }
                }
            }
        }
    }

    private var phaseStep: some View {
        SetupSection(number: 3, title: "Current Phase") {
            VStack(alignment: .leading, spacing: 8) {
                Picker("Phase", selection: $currentPhase) {
                    ForEach(["Planning", "Development", "UI Refinement", "Testing", "Release", "Maintenance"], id: \.self) { phase in
                        Text(phase).tag(phase)
                    }
                }
                TextField("Verified by", text: $author)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private var verificationStep: some View {
        SetupSection(number: 4, title: "Verification Areas") {
            VStack(alignment: .leading, spacing: 8) {
                Text("Generated from what matters for this project type. Selected areas start as Unknown and drive the Reality score.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                ForEach(snapshot.applicability.filter { $0.status.inScope }) { item in
                    Toggle(isOn: binding(for: item.area)) {
                        HStack {
                            Text(item.area)
                            Spacer()
                            Text(item.status.rawValue)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Skip", action: onCancel)
            Spacer()
            Button("Save Setup") {
                onSave(
                    ProjectSetupDraft(
                        mission: mission,
                        category: category,
                        currentPhase: currentPhase,
                        selectedVerificationAreas: Array(selectedAreas).sorted(),
                        author: author
                    )
                )
            }
            .keyboardShortcut(.defaultAction)
            .disabled(mission.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding()
    }

    private func binding(for area: String) -> Binding<Bool> {
        Binding(
            get: { selectedAreas.contains(area) },
            set: { isSelected in
                if isSelected {
                    selectedAreas.insert(area)
                } else {
                    selectedAreas.remove(area)
                }
            }
        )
    }
}

private struct SetupSection<Content: View>: View {
    var number: Int
    var title: String
    @ViewBuilder var content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("\(number)")
                    .font(.caption.weight(.bold))
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor.opacity(0.22), in: Circle())
                Text(title)
                    .font(.headline)
            }
            content
        }
        .padding()
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
    }
}
