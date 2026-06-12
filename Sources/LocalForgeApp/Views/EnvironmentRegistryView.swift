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
                EnvironmentTrustSummaryView(snapshots: snapshots)
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
            "Core snapshot: \(snapshot.coreCompletenessLabel)",
            "Age: \(snapshot.ageReadout.copyLabel)",
            "Release use: \(snapshot.releaseUseCopyLabel)",
        ] + snapshot.summaryLines + [
            "Notes: \(snapshot.notes)",
        ]).joined(separator: "\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(summary, forType: .string)
    }
}

private struct EnvironmentTrustSummaryView: View {
    var snapshots: [EnvironmentSnapshot]

    var body: some View {
        let latest = snapshots[0]
        let diffs = snapshots.count >= 2 ? latest.comparison(to: snapshots[1]) : []
        let changed = diffs.filter(\.changed)
        let releaseUse = latest.releaseUsefulness

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Label("Latest Snapshot Trust", systemImage: "checkmark.shield")
                    .font(.headline)
                Spacer()
                Text("Manual capture")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.blue)
            }

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 190), spacing: 12)], alignment: .leading, spacing: 12) {
                EnvironmentTrustMetric(
                    title: "Core Snapshot",
                    value: latest.coreCompletenessLabel,
                    detail: latest.coreCompletenessDetail,
                    symbol: latest.hasCompleteCoreSnapshot ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
                    color: latest.hasCompleteCoreSnapshot ? .green : .orange
                )
                EnvironmentTrustMetric(
                    title: "Age",
                    value: latest.ageReadout.title,
                    detail: latest.ageReadout.detail,
                    symbol: latest.ageReadout.symbol,
                    color: latest.ageReadout.color
                )
                EnvironmentTrustMetric(
                    title: "Toolchain Drift",
                    value: driftTitle(changed: changed, hasBaseline: snapshots.count >= 2),
                    detail: driftDetail(changed: changed, hasBaseline: snapshots.count >= 2),
                    symbol: snapshots.count >= 2 ? "arrow.left.arrow.right" : "clock.arrow.circlepath",
                    color: driftColor(changed: changed, hasBaseline: snapshots.count >= 2)
                )
                EnvironmentTrustMetric(
                    title: "Release Use",
                    value: releaseUse.title,
                    detail: releaseUse.detail,
                    symbol: releaseUse.symbol,
                    color: releaseUse.color
                )
            }

            Label("This registry records reproducibility context only; it does not prove CI, signing, or notarisation status.", systemImage: "info.circle")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 8))
    }

    private func driftTitle(changed: [EnvironmentSnapshotDiff], hasBaseline: Bool) -> String {
        guard hasBaseline else { return "No baseline" }
        return changed.isEmpty ? "No changes" : "\(changed.count) changed"
    }

    private func driftDetail(changed: [EnvironmentSnapshotDiff], hasBaseline: Bool) -> String {
        guard hasBaseline else {
            return "Capture another snapshot after a toolchain change to compare drift."
        }
        guard !changed.isEmpty else {
            return "Latest matches the previous snapshot across captured fields."
        }
        return changed.map(\.field).joined(separator: ", ")
    }

    private func driftColor(changed: [EnvironmentSnapshotDiff], hasBaseline: Bool) -> Color {
        guard hasBaseline else { return .gray }
        return changed.isEmpty ? .green : .orange
    }
}

private struct EnvironmentTrustMetric: View {
    var title: String
    var value: String
    var detail: String
    var symbol: String
    var color: Color

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: symbol)
                .foregroundStyle(color)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(title.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

            HStack(spacing: 6) {
                EnvironmentSnapshotPill(
                    text: snapshot.coreCompletenessLabel,
                    color: snapshot.hasCompleteCoreSnapshot ? .green : .orange,
                    symbol: snapshot.hasCompleteCoreSnapshot ? "checkmark.circle" : "exclamationmark.triangle"
                )
                EnvironmentSnapshotPill(
                    text: snapshot.ageReadout.title,
                    color: snapshot.ageReadout.color,
                    symbol: snapshot.ageReadout.symbol
                )
                EnvironmentSnapshotPill(
                    text: "Repro context",
                    color: .blue,
                    symbol: "doc.text.magnifyingglass"
                )
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(snapshot.displayFields) { field in
                    EnvironmentSnapshotFieldRow(field: field)
                }
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

private struct EnvironmentSnapshotPill: View {
    var text: String
    var color: Color
    var symbol: String

    var body: some View {
        Label(text, systemImage: symbol)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(color.opacity(0.14), in: Capsule())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
    }
}

private struct EnvironmentSnapshotFieldRow: View {
    var field: EnvironmentSnapshotField

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(field.label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 46, alignment: .leading)
            Text(field.displayValue)
                .font(.caption.monospaced())
                .foregroundStyle(field.isCaptured ? Color.primary : Color.orange)
                .lineLimit(2)
                .textSelection(.enabled)
            Spacer(minLength: 0)
        }
    }
}

private struct EnvironmentSnapshotField: Identifiable {
    var id: String { label }
    var label: String
    var value: String
    var isCore: Bool = true

    var trimmedValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var isCaptured: Bool {
        !trimmedValue.isEmpty
    }

    var displayValue: String {
        isCaptured ? trimmedValue : "Missing"
    }
}

private struct EnvironmentAgeReadout {
    var capturedAt: Date

    var days: Int {
        max(0, Calendar.current.dateComponents([.day], from: capturedAt, to: Date()).day ?? 0)
    }

    var title: String {
        if days == 0 { return "Today" }
        if days == 1 { return "1 day old" }
        return "\(days) days old"
    }

    var detail: String {
        "\(gradeDetail) Captured \(capturedAt.formatted(date: .abbreviated, time: .shortened))."
    }

    var copyLabel: String {
        "\(title) (\(capturedAt.formatted(date: .abbreviated, time: .shortened)))"
    }

    var color: Color {
        switch grade {
        case .fresh: .green
        case .aging: .orange
        case .stale: .red
        }
    }

    var symbol: String {
        switch grade {
        case .fresh: "clock.badge.checkmark"
        case .aging: "clock.badge.exclamationmark"
        case .stale: "clock.badge.xmark"
        }
    }

    private var grade: Grade {
        if days <= 7 { return .fresh }
        if days <= 30 { return .aging }
        return .stale
    }

    private var gradeDetail: String {
        switch grade {
        case .fresh:
            "Fresh enough for release-context comparison."
        case .aging:
            "Review before relying on it for release context."
        case .stale:
            "Re-capture before treating it as current release context."
        }
    }

    private enum Grade {
        case fresh
        case aging
        case stale
    }
}

private struct EnvironmentReleaseUsefulness {
    var title: String
    var detail: String
    var copyLabel: String
    var symbol: String
    var color: Color
}

private extension EnvironmentSnapshot {
    var displayFields: [EnvironmentSnapshotField] {
        coreFields + [
            EnvironmentSnapshotField(label: "auval", value: auValVersion, isCore: false),
        ]
    }

    var coreFields: [EnvironmentSnapshotField] {
        [
            EnvironmentSnapshotField(label: "macOS", value: macOSVersion),
            EnvironmentSnapshotField(label: "Xcode", value: xcodeVersion),
            EnvironmentSnapshotField(label: "Swift", value: swiftVersion),
            EnvironmentSnapshotField(label: "SDK", value: sdkVersion),
        ]
    }

    var capturedCoreFieldCount: Int {
        coreFields.filter(\.isCaptured).count
    }

    var hasCompleteCoreSnapshot: Bool {
        capturedCoreFieldCount == coreFields.count
    }

    var coreCompletenessLabel: String {
        "\(capturedCoreFieldCount)/\(coreFields.count) core"
    }

    var coreCompletenessDetail: String {
        if hasCompleteCoreSnapshot {
            return "macOS, Xcode, Swift, and SDK are captured."
        }
        let missing = coreFields.filter { !$0.isCaptured }.map(\.label).joined(separator: ", ")
        return "Missing \(missing); capture again before using as reproducibility evidence."
    }

    var ageReadout: EnvironmentAgeReadout {
        EnvironmentAgeReadout(capturedAt: capturedAt)
    }

    var releaseUsefulness: EnvironmentReleaseUsefulness {
        if !hasCompleteCoreSnapshot {
            return EnvironmentReleaseUsefulness(
                title: "Limited",
                detail: "Incomplete toolchain context; re-capture before release checks.",
                copyLabel: "Limited; incomplete toolchain context.",
                symbol: "exclamationmark.triangle.fill",
                color: .orange
            )
        }
        if ageReadout.days > 30 {
            return EnvironmentReleaseUsefulness(
                title: "Re-capture",
                detail: "Complete, but old enough to refresh before release checks.",
                copyLabel: "Re-capture recommended; complete but stale.",
                symbol: "arrow.clockwise.circle.fill",
                color: .orange
            )
        }
        return EnvironmentReleaseUsefulness(
            title: "Useful Context",
            detail: "Supports reproducing build/test conditions; not a release pass.",
            copyLabel: "Useful reproducibility context; not a release pass.",
            symbol: "doc.text.magnifyingglass",
            color: .green
        )
    }

    var releaseUseCopyLabel: String {
        "\(releaseUsefulness.copyLabel) Does not prove CI, signing, or notarisation status."
    }
}
