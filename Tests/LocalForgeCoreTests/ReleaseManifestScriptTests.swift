import Foundation
import Testing

@Suite("Release manifest script safety")
struct ReleaseManifestScriptTests {
    @Test("manifest redacts credentials embedded in git remote URLs")
    func manifestRedactsCredentialedRemotes() throws {
        let fm = FileManager.default
        let packageRoot = try findPackageRoot()
        let root = fm.temporaryDirectory.appendingPathComponent("lf-release-manifest-\(UUID().uuidString)")
        let scriptDir = root.appendingPathComponent("script")
        let scriptPath = scriptDir.appendingPathComponent("release_manifest.sh")

        try fm.createDirectory(at: scriptDir, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try fm.copyItem(
            at: packageRoot.appendingPathComponent("script/release_manifest.sh"),
            to: scriptPath
        )

        guard fm.isExecutableFile(atPath: "/usr/bin/git") else { return }
        _ = try run("/usr/bin/git", ["init"], currentDirectory: root)
        _ = try run(
            "/usr/bin/git",
            ["remote", "add", "origin", "https://ghp_privateToken123@github.com/owner/repo.git"],
            currentDirectory: root
        )
        _ = try run(
            "/usr/bin/git",
            ["remote", "add", "upstream", "https://developer:superSecret456@example.com/owner/repo.git"],
            currentDirectory: root
        )

        let result = try run("/bin/bash", [scriptPath.path, "--check"], currentDirectory: root)

        #expect(result.status == 0)
        #expect(!result.output.contains("ghp_privateToken123"))
        #expect(!result.output.contains("superSecret456"))
        #expect(result.output.contains("origin_remote: https://[REDACTED_CREDENTIAL]@github.com/owner/repo.git"))
        #expect(result.output.contains("upstream_remote: https://[REDACTED_CREDENTIAL]@example.com/owner/repo.git"))
        #expect(result.output.contains("remote_credential_redaction: enabled for URL userinfo"))
        #expect(result.output.contains("operator_note: local evidence only"))
    }

    private func findPackageRoot() throws -> URL {
        var candidate = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        while candidate.path != "/" {
            let script = candidate.appendingPathComponent("script/release_manifest.sh")
            if FileManager.default.fileExists(atPath: script.path) {
                return candidate
            }
            candidate.deleteLastPathComponent()
        }
        throw TestFailure("Could not locate package root from current directory.")
    }

    private func run(
        _ executable: String,
        _ arguments: [String],
        currentDirectory: URL
    ) throws -> (status: Int32, output: String) {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()
        process.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return (process.terminationStatus, String(decoding: data, as: UTF8.self))
    }
}

private struct TestFailure: Error, CustomStringConvertible {
    var description: String

    init(_ description: String) {
        self.description = description
    }
}
