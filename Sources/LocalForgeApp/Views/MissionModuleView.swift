import LocalForgeCore
import SwiftUI

struct MissionModuleView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var showingEditor = false

    var body: some View {
        if let project = store.selectedProject, let snapshot = store.selectedSnapshot {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Mission — \(project.name)")
                            .font(.title2.weight(.semibold))
                        Spacer()
                        Button {
                            showingEditor = true
                        } label: {
                            Label(snapshot.userMission == nil ? "Define Mission" : "Edit Mission", systemImage: "scope")
                        }
                    }
                    Text(snapshot.mission.statedMission)
                        .font(.title3.weight(.medium))
                    Text(snapshot.mission.rationale)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))

                ExplanationCard(
                    title: "Mission",
                    what: "Mission describes what this project is meant to become, what phase it is in, and which goals matter most.",
                    why: "LocalForge uses the mission to decide which verification areas, risks, release checks, and next actions are relevant.",
                    next: snapshot.userMission == nil ? "Define the mission so the dashboard and release checks match the project you are actually building." : "Keep the mission current when the project moves into a new phase or a goal changes.",
                    safety: "Editing the mission changes only LocalForge workspace metadata. It does not edit source files or repository history.",
                    example: "Example: AUv3 instrument, UI refinement phase, goal to verify preset save and host restore.",
                    symbol: "scope",
                    tint: .blue
                )

                if let mission = snapshot.userMission {
                    MissionFactsView(mission: mission)
                } else {
                    Text("This mission is inferred. Define it to make Reality and Verification reflect your actual intent.")
                        .foregroundStyle(.secondary)
                        .padding()
                        .background(Color.yellow.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
                }
            }
            .sheet(isPresented: $showingEditor) {
                MissionEditorView(
                    identity: snapshot.identity,
                    inferred: snapshot.mission,
                    existing: snapshot.userMission,
                    onSave: { mission in
                        store.setMission(mission, for: project.id)
                        showingEditor = false
                    },
                    onCancel: { showingEditor = false }
                )
            }
        } else {
            ContentUnavailableView("Open a project", systemImage: "scope", description: Text("Select a project to define its mission."))
        }
    }
}

private struct MissionFactsView: View {
    var mission: UserMissionProfile

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Defined Mission")
                .font(.headline)
            Fact(label: "Category", value: mission.category.rawValue)
            Fact(label: "Phase", value: mission.currentPhase.isEmpty ? "Not set" : mission.currentPhase)
            if !mission.goals.isEmpty {
                Text("Goals")
                    .font(.subheadline.weight(.semibold))
                ForEach(mission.goals, id: \.self) { goal in
                    Text("• \(goal)")
                        .foregroundStyle(.secondary)
                }
            }
            if !mission.knownIssues.isEmpty {
                Text("Known Issues")
                    .font(.subheadline.weight(.semibold))
                ForEach(mission.knownIssues, id: \.self) { issue in
                    Text("• \(issue)")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct Fact: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
        }
    }
}
