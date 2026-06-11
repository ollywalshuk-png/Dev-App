import Foundation
import Testing
@testable import LocalForgeCore

@Suite("Phase 10A — Dev command engine safety")
struct DevCommandEngineTests {
    @Test("dev command presets are project scoped and allowlisted")
    func presetsAreScopedAndAllowlisted() {
        let engine = DevCommandEngine()
        let root = "/tmp/localforge-devtools"
        let presets = engine.presets(projectRoot: root, appBundlePath: "/tmp/App.app")

        #expect(presets.map(\.kind) == [
            .swiftBuild,
            .swiftTest,
            .gitStatus,
            .codesignVerify,
            .gatekeeperCheck,
            .environmentCapture,
        ])
        #expect(presets.allSatisfy { $0.workingDirectory == root })
        #expect(presets.first { $0.kind == .swiftBuild }?.arguments.contains("build") == true)
        #expect(presets.first { $0.kind == .swiftTest }?.arguments.contains("test") == true)
    }

    @Test("mutating git command is blocked by argument allowlist")
    func mutatingGitCommandIsBlocked() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lf-devtools-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let engine = DevCommandEngine()
        let command = DevToolsCommand(
            kind: .gitStatus,
            title: "Bad Git",
            detail: "Should not run",
            executable: "/usr/bin/git",
            arguments: ["reset", "--hard"],
            workingDirectory: root.path,
            risk: .readOnly,
            timeout: 5,
            verificationArea: "Git"
        )

        let result = engine.validate(command, projectRoot: root.path)
        #expect(result?.status == .blocked)
        #expect(result?.output.contains("Arguments") == true)
    }

    @Test("command outside selected project is blocked")
    func commandOutsideProjectIsBlocked() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lf-devtools-root-\(UUID().uuidString)")
        let other = fm.temporaryDirectory.appendingPathComponent("lf-devtools-other-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        try fm.createDirectory(at: other, withIntermediateDirectories: true)
        defer {
            try? fm.removeItem(at: root)
            try? fm.removeItem(at: other)
        }

        let engine = DevCommandEngine()
        let command = DevToolsCommand(
            kind: .gitStatus,
            title: "Wrong Scope",
            detail: "Should not run",
            executable: "/usr/bin/git",
            arguments: ["status", "--short", "--branch"],
            workingDirectory: other.path,
            risk: .readOnly,
            timeout: 5,
            verificationArea: "Git"
        )

        let result = engine.validate(command, projectRoot: root.path)
        #expect(result?.status == .blocked)
        #expect(result?.output.contains("outside") == true)
    }

    @Test("codesign preset requires an app bundle target")
    func codesignRequiresAppBundle() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("lf-devtools-app-\(UUID().uuidString)")
        try fm.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let engine = DevCommandEngine()
        let command = try #require(engine.presets(projectRoot: root.path, appBundlePath: root.path)
            .first { $0.kind == .codesignVerify }
        )
        let result = try #require(engine.validate(command, projectRoot: root.path))
        #expect(result.status == .blocked)
        #expect(result.output.contains(".app bundle") == true)
    }
}
