import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Phase 9A — Utility Centre stabilisation")
struct UtilityCentreTests {

    // MARK: - Target resolution

    @Test("findAppBundles prefers dist/*.app and returns repo-relative candidates")
    func findAppBundlesPrefersDevDist() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lf-targets-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }

        // Build a fake repo: dist/MyApp.app, Archive/dist/MyApp.app, .build/x/Other.app
        let distApp = root.appendingPathComponent("dist/MyApp.app/Contents")
        let archiveApp = root.appendingPathComponent("Archive/dist/MyApp.app/Contents")
        let buildApp = root.appendingPathComponent(".build/x/Other.app/Contents")
        for c in [distApp, archiveApp, buildApp] {
            try fm.createDirectory(at: c, withIntermediateDirectories: true)
            try Data("<plist/>".utf8).write(to: c.appendingPathComponent("Info.plist"))
        }

        let engine = UtilityCentreEngine()
        let candidates = engine.findAppBundles(under: root.path)

        #expect(!candidates.isEmpty)
        // A dist/*.app must rank ahead of a .build/*.app.
        let firstDistIndex = candidates.firstIndex { $0.contains("/dist/") }
        let buildIndex = candidates.firstIndex { $0.contains("/.build/") }
        if let b = buildIndex, let d = firstDistIndex {
            #expect(d < b)
        }
        // Top candidate is a dist bundle.
        #expect(candidates.first?.contains("/dist/") == true)
    }

    @Test("isAppBundle accepts a real .app and rejects a plain directory")
    func isAppBundleDiscrimination() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lf-isapp-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        let appContents = root.appendingPathComponent("Thing.app/Contents")
        try fm.createDirectory(at: appContents, withIntermediateDirectories: true)
        try Data("<plist/>".utf8).write(to: appContents.appendingPathComponent("Info.plist"))
        let plainDir = root.appendingPathComponent("repo")
        try fm.createDirectory(at: plainDir, withIntermediateDirectories: true)

        let engine = UtilityCentreEngine()
        #expect(engine.isAppBundle(root.appendingPathComponent("Thing.app").path))
        #expect(!engine.isAppBundle(plainDir.path))
        #expect(!engine.isAppBundle(root.path))
    }

    @Test("bundle/security tool rejects repo root as a target error, not a crash")
    func bundleToolRejectsRepoRoot() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lf-reporoot-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let engine = UtilityCentreEngine()
        let result = await engine.runBundleInspector(path: root.path)
        #expect(result.status == .targetError)
        #expect(result.output.contains("not an app bundle"))
    }

    // MARK: - Quarantine classification

    @Test("'No such xattr' is classified as clean/success, not failure")
    func quarantineMissingIsClean() {
        let engine = UtilityCentreEngine()
        let raw = UtilityCentreEngine.ProcessResult(
            exitCode: 1,
            combined: "xattr: /some/path: No such xattr: com.apple.quarantine",
            timedOut: false,
            truncated: false
        )
        let result = engine.classifyQuarantineInspector(raw, path: "/some/path")
        #expect(result.status == .success)
        #expect(result.isSuccess)
        #expect(result.interpretation.localizedCaseInsensitiveContains("clean")
                || result.output.localizedCaseInsensitiveContains("no quarantine"))
    }

    @Test("present quarantine attribute is surfaced as a warning")
    func quarantinePresentIsWarning() {
        let engine = UtilityCentreEngine()
        let raw = UtilityCentreEngine.ProcessResult(
            exitCode: 0,
            combined: "00c1;abc;Safari;",
            timedOut: false,
            truncated: false
        )
        let result = engine.classifyQuarantineInspector(raw, path: "/some/path")
        #expect(result.status == .warning)
    }

    // MARK: - DerivedData classification

    @Test("missing DerivedData folder is info, not failure")
    func derivedDataMissingIsInfo() async {
        // On most CI/dev machines DerivedData may or may not exist; we only
        // assert that a non-existent folder maps to .info. To make this
        // deterministic we check the classification contract via a synthetic
        // path through runDerivedDataSize only when the folder is absent.
        let engine = UtilityCentreEngine()
        let ddPath = NSHomeDirectory() + "/Library/Developer/Xcode/DerivedData"
        let result = await engine.runDerivedDataSize()
        if !FileManager.default.fileExists(atPath: ddPath) {
            #expect(result.status == .info)
            #expect(result.isSuccess)
        } else {
            // Folder exists — result should be info/warning, never a hard failure for a successful du.
            #expect(result.status == .info || result.status == .warning)
        }
    }

    // MARK: - Large file classification

    @Test("large file classifier buckets build, git, cache, and source assets")
    func largeFileClassification() {
        let engine = UtilityCentreEngine()
        #expect(engine.classifyLargeFile(path: "/r/.build/x.o") == .buildArtefact)
        #expect(engine.classifyLargeFile(path: "/r/.git/objects/pack/p") == .gitObjects)
        #expect(engine.classifyLargeFile(path: "/r/ModuleCache/x.pcm") == .moduleCache)
        #expect(engine.classifyLargeFile(path: "/r/Assets/logo.png") == .sourceAssets)
        #expect(engine.classifyLargeFile(path: "/r/dist/My.app/Contents/MacOS/My") == .appBundle)
        #expect(engine.classifyLargeFile(path: "/r/Sources/Main.swift") == .other)
    }

    // MARK: - Empty folder ignore rules

    @Test("empty folder finder ignores .git/.build/.swiftpm/cache by default")
    func emptyFolderIgnoresNoise() async throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lf-empty-\(UUID().uuidString)")
        defer { try? fm.removeItem(at: root) }
        // Empty dirs: one real source dir, several noise dirs.
        for sub in ["Sources/Empty", ".git/empty", ".build/empty", ".swiftpm/empty"] {
            try fm.createDirectory(at: root.appendingPathComponent(sub), withIntermediateDirectories: true)
        }

        let engine = UtilityCentreEngine()
        let result = await engine.runEmptyFolders(repoRoot: root.path, includeBuildAndCache: false)
        #expect(!result.output.contains("/.git/"))
        #expect(!result.output.contains("/.build/"))
        #expect(!result.output.contains("/.swiftpm/"))
        // The legitimate empty source dir should still be reported.
        #expect(result.output.contains("Sources/Empty") || result.output.contains("Empty"))
    }

    // MARK: - Output truncation / timeout

    @Test("command output is truncated safely when it exceeds the cap")
    func outputTruncates() async {
        let engine = UtilityCentreEngine()
        // Generate ~1MB of output via yes piped through head — bounded by timeout.
        let r = await engine.run(
            args: ["/bin/sh", "-c", "head -c 1000000 /dev/zero | tr '\\0' 'a'"],
            timeout: UtilityCentreEngine.Timeouts.metadata
        )
        #expect(r.truncated)
        #expect(r.combined.contains("truncated"))
    }

    @Test("command timeout returns a controlled result and does not block indefinitely")
    func timeoutIsControlled() async {
        let engine = UtilityCentreEngine()
        let start = Date()
        // sleep 30 with a 2s timeout must return well before 30s.
        let r = await engine.run(args: ["/bin/sleep", "30"], timeout: 2)
        let elapsed = Date().timeIntervalSince(start)
        #expect(elapsed < 10)
        // Process was terminated; non-zero exit.
        #expect(r.exitCode != 0)
    }
}
