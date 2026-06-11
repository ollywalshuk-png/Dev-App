import AppKit
import LocalForgeCore
import SwiftUI

struct EnvironmentRegistryView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var isCapturing = false

    var body: some View {
        guard let project = store.selectedProject else {
            return AnyView(ContentUnavailableView(
                "No project selected",
                systemImage: "desktopcomputer.and.macbook",
                description: Text("Open or select a project to capture local toolchain snapshots.")
            ))
        }

        let snapshots = store.environments(for: project.id)
        return AnyView(VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(project.name)
                        .font(.title2.weight(.semibold))
                    Label("Manual read-only snapshots of this Mac's developer environment.", systemImage: "eye")
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    capture(projectID: project.id)
                } label: {
                    Label(isCapturing ? "Capturing..." : "Capture Environment", systemImage: "camera.metering.matrix")
                }
                .disabled(isCapturing)
            }

            ExplanationCard(
                title: "Environment Registry",
                what: "The Environment Registry records macOS, Xcode, Swift, SDK, and related local toolchain details at a point in time.",
                why: "Environment changes can break a project even when the source code did not change.",
                next: "Capture a snapshot before release checks, after Xcode updates, and when a build starts behaving differently.",
                safety: "Capture is explicit and local. LocalForge does not monitor toolchain drift in the background, upload environment data, or poll your system.",
                example: "Compare the latest snapshot with the previous one to see whether Xcode, Swift, or SDK paths changed.",
                symbol: "desktopcomputer.and.macbook",
                tint: .blue
            )

            if snapshots.isEmpty {
                ContentUnavailableView(
                    "No environment snapshots",
                    systemImage: "desktopcomputer",
                    description: Text("Capture a snapshot before release checks, host validation, or toolchain changes.")
                )
            } else {
                EnvironmentComparisonView(snapshots: snapshots)
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 300), spacing: 12)], spacing: 12) {
                    ForEach(snapshots) { snapshot in
                        EnvironmentSnapshotCard(snapshot: snapshot, onCopy: copySummary)
                    }
                }
            }
        })
    }

    private func capture(projectID: UUID) {
        isCapturing = true
        Task {
            let snapshot = await store.utilityCentre.captureEnvironment()
            await MainActor.run {
                store.addEnvironmentSnapshot(snapshot, for: projectID)
                isCapturing = false
            }
        }
    }

    private func copySummary(_ snapshot: EnvironmentSnapshot) {
        let summary = ([
            "Captured: \(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened))",
        ] + snapshot.summaryLines + [
            "Notes: \(snapshot.notes)",
        ]).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }
}

private struct EnvironmentHelpPanel: View {
    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "desktopcomputer.and.macbook")
                .foregroundStyle(.blue)
            VStack(alignment: .leading, spacing: 3) {
                Text("Manual environment snapshots")
                    .font(.subheadline.weight(.semibold))
                Text("Capture is explicit and local. LocalForge does not monitor toolchain drift in the background, upload environment data, or poll your system.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.blue.opacity(0.10), in: RoundedRectangle(cornerRadius: 8))
    }
}

private struct EnvironmentComparisonView: View {
    var snapshots: [EnvironmentSnapshot]

    var body: some View {
        if snapshots.count >= 2 {
            let latest = snapshots[0]
            let previous = snapshots[1]
            let diffs = latest.comparison(to: previous)
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Latest vs Previous", systemImage: "arrow.left.arrow.right")
                        .font(.headline)
                    Spacer()
                    Text("\(diffs.filter { $0.changed }.count) changed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(diffs.contains { $0.changed } ? .orange : .green)
                }
                ForEach(diffs) { diff in
                    HStack {
                        Text(diff.field)
                            .font(.caption.weight(.semibold))
                            .frame(width: 64, alignment: .leading)
                        Text(diff.previousValue.isEmpty ? "Unknown" : diff.previousValue)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(.tertiary)
                        Text(diff.currentValue.isEmpty ? "Unknown" : diff.currentValue)
                            .foregroundStyle(diff.changed ? .orange : .secondary)
                            .lineLimit(1)
                        Spacer()
                    }
                    .font(.caption)
                }
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
        }
    }
}

private struct EnvironmentSnapshotCard: View {
    var snapshot: EnvironmentSnapshot
    var onCopy: (EnvironmentSnapshot) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(snapshot.capturedAt.formatted(date: .abbreviated, time: .shortened), systemImage: "clock")
                    .font(.caption.weight(.semibold))
                Spacer()
                Button { onCopy(snapshot) } label: {
                    Image(systemName: "doc.on.doc")
                }
                .buttonStyle(.borderless)
                .help("Copy environment summary")
            }

            ForEach(snapshot.summaryLines, id: \.self) { line in
                Text(line)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }

            if !snapshot.notes.isEmpty {
                Divider()
                Text(snapshot.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, minHeight: 170, alignment: .topLeading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}
