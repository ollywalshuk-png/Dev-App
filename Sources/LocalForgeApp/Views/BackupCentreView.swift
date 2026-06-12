import AppKit
import LocalForgeCore
import SwiftUI

// MARK: - Backup Centre

struct BackupCentreView: View {
    @ObservedObject var store: WorkspaceStore
    @State private var backups: [BackupRecord] = []
    @State private var note: String = ""
    @State private var error: String?
    @State private var operationStatus: String?
    @State private var showRestoreConfirm: BackupRecord?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header
                trustStrip
                ExplanationCard(
                    title: "Backup Centre",
                    what: "Backup Centre protects LocalForge's workspace database: projects, missions, verification, evidence, registers, environment records, and history.",
                    why: "It lets you recover LocalForge knowledge if a workspace database is damaged or you need to move data.",
                    next: "Create a backup before imports, restores, and release validation runs.",
                    safety: "Create and export are non-destructive. Restore replaces the current workspace and always asks for confirmation.",
                    example: "Backups are local files under Application Support. Export creates a JSON copy you control.",
                    symbol: "externaldrive",
                    tint: .orange
                )
                createCard
                listCard
                exportImportCard
            }
            .padding(20)
        }
        .onAppear { refresh() }
        .alert("Restore Backup?",
               isPresented: Binding(get: { showRestoreConfirm != nil }, set: { if !$0 { showRestoreConfirm = nil } })) {
            Button("Cancel", role: .cancel) { showRestoreConfirm = nil }
            Button("Restore", role: .destructive) {
                if let b = showRestoreConfirm { restore(b) }
                showRestoreConfirm = nil
            }
        } message: {
            Text("The current workspace will be moved aside and replaced with the backup. Restart LocalForge after restoring.")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("Backup Centre")
                    .font(.system(size: 28, weight: .bold))
                Spacer()
                statusPill("Local only", systemImage: "lock", tint: .green)
                statusPill("Manual actions", systemImage: "hand.tap", tint: .blue)
            }
            Text("Backups, JSON export, and restore tools for the workspace database on this Mac.")
                .foregroundStyle(.secondary)
            if let operationStatus {
                inlineStatus(operationStatus, systemImage: "checkmark.circle", tint: .green)
            }
            if let error {
                inlineStatus(error, systemImage: "exclamationmark.triangle", tint: .red)
            }
        }
    }

    private var trustStrip: some View {
        HStack(spacing: 8) {
            metricCell(
                title: "Backups",
                value: "\(backups.count)",
                detail: backups.isEmpty ? "None retained yet" : "Retained locally",
                systemImage: "externaldrive",
                tint: .orange
            )
            metricCell(
                title: "Last backup",
                value: lastBackupAge,
                detail: latestBackupDate,
                systemImage: "clock.arrow.circlepath",
                tint: backups.isEmpty ? .secondary : .green
            )
            metricCell(
                title: "Stored size",
                value: totalBackupSizeDisplay,
                detail: "Application Support",
                systemImage: "internaldrive",
                tint: .blue
            )
            metricCell(
                title: "Boundary",
                value: "This Mac",
                detail: "No cloud workflow",
                systemImage: "desktopcomputer",
                tint: .purple
            )
        }
    }

    private var createCard: some View {
        cardSection(title: "Create Backup") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    TextField("Optional note…", text: $note)
                        .textFieldStyle(.roundedBorder)
                    Button {
                        createBackup()
                    } label: {
                        Label("Create Backup", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }
                compactCue(
                    title: "Recoverability point",
                    detail: "Creates a local copy of workspace.sqlite before risky work. It does not run until clicked.",
                    systemImage: "checkmark.seal",
                    tint: .green
                )
            }
        }
    }

    private var listCard: some View {
        cardSection(title: "Backups") {
            VStack(alignment: .leading, spacing: 10) {
                compactCue(
                    title: "Restore caution",
                    detail: "Restore replaces the current workspace database after confirmation; restart LocalForge afterward.",
                    systemImage: "exclamationmark.triangle",
                    tint: .orange
                )

                if backups.isEmpty {
                    emptyBackups
                } else {
                    LazyVStack(spacing: 6) {
                        ForEach(backups) { backup in
                            backupRow(backup)
                        }
                    }
                }
            }
        }
    }

    private var emptyBackups: some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive.badge.questionmark")
                .foregroundStyle(.secondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text("No recovery point yet")
                    .font(.system(size: 13, weight: .medium))
                Text("Create a backup before imports, restores, or release validation runs.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func backupRow(_ backup: BackupRecord) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "externaldrive")
                .foregroundStyle(.orange)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 3) {
                Text(backup.filename)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                HStack(spacing: 6) {
                    Text(backup.createdAt.formatted(date: .abbreviated, time: .shortened))
                    Text("•")
                    Text(relativeAge(for: backup.createdAt))
                    Text("•")
                    Text(backup.sizeDisplay)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            statusPill("Recovery point", systemImage: "arrow.counterclockwise", tint: .green)
            Button {
                showRestoreConfirm = backup
            } label: {
                Label("Restore", systemImage: "arrow.triangle.2.circlepath")
            }
            .controlSize(.small)
            Button(role: .destructive) {
                delete(backup)
            } label: {
                Image(systemName: "trash")
            }
            .controlSize(.small)
        }
        .padding(10)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var exportImportCard: some View {
        cardSection(title: "Export / Import") {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Button {
                        exportWorkspace()
                    } label: {
                        Label("Export Workspace…", systemImage: "square.and.arrow.up")
                    }
                    Button {
                        importWorkspace()
                    } label: {
                        Label("Import Workspace…", systemImage: "square.and.arrow.down")
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    compactCue(
                        title: "Export",
                        detail: "Writes a local JSON copy to the file you choose.",
                        systemImage: "doc.badge.arrow.up",
                        tint: .blue
                    )
                    compactCue(
                        title: "Import",
                        detail: "Reads a selected JSON export and replaces current workspace data.",
                        systemImage: "exclamationmark.arrow.triangle.2.circlepath",
                        tint: .orange
                    )
                }
            }
        }
    }

    private var latestBackup: BackupRecord? {
        backups.first
    }

    private var latestBackupDate: String {
        guard let latestBackup else { return "No local backup" }
        return latestBackup.createdAt.formatted(date: .abbreviated, time: .shortened)
    }

    private var lastBackupAge: String {
        guard let latestBackup else { return "Never" }
        return relativeAge(for: latestBackup.createdAt)
    }

    private var totalBackupSizeDisplay: String {
        let totalBytes = backups.reduce(Int64(0)) { $0 + $1.sizeBytes }
        guard totalBytes > 0 else { return "0 B" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        return formatter.string(fromByteCount: totalBytes)
    }

    private func cardSection<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased()).font(.caption.weight(.semibold)).foregroundStyle(.secondary)
            content()
        }
        .padding(14)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func metricCell(title: String, value: String, detail: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
                Text(detail)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func compactCue(title: String, detail: String, systemImage: String, tint: Color) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(tint.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
    }

    private func statusPill(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tint.opacity(0.12), in: Capsule())
    }

    private func inlineStatus(_ text: String, systemImage: String, tint: Color) -> some View {
        Label(text, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 6))
    }

    private func relativeAge(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func refresh() {
        do {
            backups = try store.backupEngine.listBackups()
        } catch {
            self.error = error.localizedDescription
        }
    }

    private func createBackup() {
        guard let sqliteURL = currentWorkspaceURL() else {
            self.error = "Could not locate the workspace database."
            operationStatus = nil
            return
        }
        do {
            let backup = try store.backupEngine.createBackup(from: sqliteURL, note: note)
            note = ""
            error = nil
            operationStatus = "Created local backup \(backup.filename)."
            refresh()
        } catch {
            operationStatus = nil
            self.error = error.localizedDescription
        }
    }

    private func restore(_ backup: BackupRecord) {
        guard let sqliteURL = currentWorkspaceURL() else {
            self.error = "Could not locate the workspace database."
            operationStatus = nil
            return
        }
        do {
            try store.backupEngine.restore(backup: backup, to: sqliteURL)
            error = nil
            operationStatus = "Restored \(backup.filename). Restart LocalForge to load it."
        } catch {
            operationStatus = nil
            self.error = error.localizedDescription
        }
    }

    private func delete(_ backup: BackupRecord) {
        do {
            try store.backupEngine.delete(backup: backup)
            error = nil
            operationStatus = "Deleted local backup \(backup.filename)."
            refresh()
        } catch {
            operationStatus = nil
            self.error = error.localizedDescription
        }
    }

    private func currentWorkspaceURL() -> URL? {
        try? FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: false
        ).appendingPathComponent("LocalForge/workspace.sqlite")
    }

    private func exportWorkspace() {
        guard let data = store.exportWorkspaceJSON() else {
            error = "Could not export the current workspace."
            operationStatus = nil
            return
        }
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "localforge-workspace.json"
        if panel.runModal() == .OK, let url = panel.url {
            do {
                try data.write(to: url)
                error = nil
                operationStatus = "Exported local JSON to \(url.lastPathComponent)."
            } catch {
                operationStatus = nil
                self.error = error.localizedDescription
            }
        }
    }

    private func importWorkspace() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            do {
                let data = try Data(contentsOf: url)
                _ = store.importWorkspace(from: data)
                error = nil
                operationStatus = "Imported local JSON from \(url.lastPathComponent)."
            } catch {
                operationStatus = nil
                self.error = error.localizedDescription
            }
        }
    }
}
