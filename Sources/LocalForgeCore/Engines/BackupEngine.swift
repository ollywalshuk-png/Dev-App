import Foundation

/// Phase 8.5: local SQLite backup/restore with a 5-backup rotation.
/// Never uploads, never auto-runs, never deletes without user action.
public final class BackupEngine: Sendable {
    private static let maxBackups = 5
    private static let backupSuffix = ".localforge-backup"

    public init() {}

    // MARK: - Backup directory

    public static func backupDirectory() throws -> URL {
        let support = try FileManager.default.url(
            for: .applicationSupportDirectory, in: .userDomainMask,
            appropriateFor: nil, create: true
        ).appendingPathComponent("LocalForge/Backups", isDirectory: true)
        try FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        return support
    }

    // MARK: - Create backup

    public func createBackup(from sourceURL: URL, note: String = "") throws -> BackupRecord {
        let dir = try Self.backupDirectory()
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        let timestamp = formatter.string(from: Date()).replacingOccurrences(of: ":", with: "-")
        let filename = "workspace-\(timestamp)\(Self.backupSuffix)"
        let destURL = dir.appendingPathComponent(filename)

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw BackupError.sourceNotFound(sourceURL.path)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destURL)

        let attrs = try FileManager.default.attributesOfItem(atPath: destURL.path)
        let size = attrs[.size] as? Int64 ?? 0

        let record = BackupRecord(filename: filename, sizeBytes: size, note: note)
        try rotateBackups(in: dir)
        return record
    }

    // MARK: - Restore backup

    public func restore(backup: BackupRecord, to destinationURL: URL) throws {
        let dir = try Self.backupDirectory()
        let sourceURL = dir.appendingPathComponent(backup.filename)

        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw BackupError.backupFileNotFound(backup.filename)
        }

        // Move the current database aside first.
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            let aside = destinationURL.deletingPathExtension().appendingPathExtension("sqlite.pre-restore")
            _ = try? FileManager.default.removeItem(at: aside)
            try FileManager.default.moveItem(at: destinationURL, to: aside)
        }

        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
    }

    // MARK: - List backups

    public func listBackups() throws -> [BackupRecord] {
        let dir = try Self.backupDirectory()
        let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        var records: [BackupRecord] = []

        for filename in contents where filename.hasSuffix(Self.backupSuffix) {
            let url = dir.appendingPathComponent(filename)
            let attrs = try? FileManager.default.attributesOfItem(atPath: url.path)
            let size = attrs?[.size] as? Int64 ?? 0
            let createdAt = attrs?[.creationDate] as? Date ?? Date()
            records.append(BackupRecord(filename: filename, createdAt: createdAt, sizeBytes: size))
        }

        return records.sorted { $0.createdAt > $1.createdAt }
    }

    // MARK: - Delete backup

    public func delete(backup: BackupRecord) throws {
        let dir = try Self.backupDirectory()
        let url = dir.appendingPathComponent(backup.filename)
        guard FileManager.default.fileExists(atPath: url.path) else { return }
        try FileManager.default.removeItem(at: url)
    }

    // MARK: - Export

    public func export(from sourceURL: URL, to exportURL: URL) throws {
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            throw BackupError.sourceNotFound(sourceURL.path)
        }
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: exportURL)
    }

    // MARK: - Rotation

    private func rotateBackups(in dir: URL) throws {
        let contents = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        let backupFiles = contents.filter { $0.hasSuffix(Self.backupSuffix) }.sorted().reversed()
        let toDelete = Array(backupFiles.dropFirst(Self.maxBackups))
        for filename in toDelete {
            let url = dir.appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: url)
        }
    }

    // MARK: - Errors

    public enum BackupError: Error, LocalizedError {
        case sourceNotFound(String)
        case backupFileNotFound(String)

        public var errorDescription: String? {
            switch self {
            case .sourceNotFound(let p): "Source file not found: \(p)"
            case .backupFileNotFound(let f): "Backup file not found: \(f)"
            }
        }
    }
}
