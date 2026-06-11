import Foundation

public struct DevCommandEngine: Sendable {
    public static let maxOutputBytes = 256 * 1024

    public init() {}

    public func presets(projectRoot: String, appBundlePath: String? = nil) -> [DevToolsCommand] {
        [
            DevToolsCommand(
                kind: .swiftBuild,
                title: "Swift Build",
                detail: "Runs swift build in the selected project. Writes only normal build artefacts.",
                executable: "/usr/bin/env",
                arguments: swiftEnvironment + ["swift", "build", "--cache-path", ".build/swiftpm-cache"],
                workingDirectory: projectRoot,
                risk: .buildWrites,
                timeout: 120,
                verificationArea: "Build"
            ),
            DevToolsCommand(
                kind: .swiftTest,
                title: "Swift Test",
                detail: "Runs swift test in the selected project and records the result as test evidence.",
                executable: "/usr/bin/env",
                arguments: swiftEnvironment + ["swift", "test", "--cache-path", ".build/swiftpm-cache"],
                workingDirectory: projectRoot,
                risk: .buildWrites,
                timeout: 180,
                verificationArea: "Tests"
            ),
            DevToolsCommand(
                kind: .gitStatus,
                title: "Git Status",
                detail: "Reads branch and working-tree status without modifying the repository.",
                executable: "/usr/bin/git",
                arguments: ["status", "--short", "--branch"],
                workingDirectory: projectRoot,
                risk: .readOnly,
                timeout: 15,
                verificationArea: "Git"
            ),
            DevToolsCommand(
                kind: .codesignVerify,
                title: "Codesign Verify",
                detail: "Verifies a selected .app bundle signature.",
                executable: "/usr/bin/codesign",
                arguments: ["--verify", "--deep", "--strict", appBundlePath ?? ""],
                workingDirectory: projectRoot,
                risk: .readOnly,
                timeout: 20,
                verificationArea: "Signing",
                requiresAppBundle: true
            ),
            DevToolsCommand(
                kind: .gatekeeperCheck,
                title: "Gatekeeper Check",
                detail: "Asks Gatekeeper to assess a selected .app bundle. Local adhoc builds are expected to fail this distribution check.",
                executable: "/usr/sbin/spctl",
                arguments: ["--assess", "--verbose=4", appBundlePath ?? ""],
                workingDirectory: projectRoot,
                risk: .externalAssessment,
                timeout: 20,
                verificationArea: "Gatekeeper",
                requiresAppBundle: true
            ),
            DevToolsCommand(
                kind: .environmentCapture,
                title: "Environment Capture",
                detail: "Captures macOS, Xcode, Swift, and SDK versions through existing local environment tools.",
                executable: "",
                arguments: [],
                workingDirectory: projectRoot,
                risk: .readOnly,
                timeout: 15,
                verificationArea: "Environment"
            ),
        ]
    }

    public func validate(_ command: DevToolsCommand, projectRoot: String) -> DevToolsCommandResult? {
        let started = Date()
        guard command.workingDirectory == projectRoot else {
            return blocked(command, started: started, reason: "Command working directory is outside the selected project.")
        }
        guard FileManager.default.fileExists(atPath: projectRoot) else {
            return blocked(command, started: started, reason: "Selected project path does not exist.")
        }
        if command.kind == .environmentCapture {
            return nil
        }
        guard allowedExecutable(command.executable) else {
            return blocked(command, started: started, reason: "Executable is not in the Dev Tools allowlist.")
        }
        guard allowedArguments(for: command.kind, arguments: command.arguments) else {
            return blocked(command, started: started, reason: "Arguments are not in the preset allowlist.")
        }
        if command.requiresAppBundle {
            guard let target = command.arguments.last, isAppBundle(target) else {
                return blocked(command, started: started, reason: "This preset requires a valid .app bundle target.")
            }
        }
        return nil
    }

    public func run(_ command: DevToolsCommand, projectRoot: String) async -> DevToolsCommandResult {
        if let blocked = validate(command, projectRoot: projectRoot) {
            return blocked
        }
        return await Task.detached {
            runSynchronously(command)
        }.value
    }

    private func runSynchronously(_ command: DevToolsCommand) -> DevToolsCommandResult {
        let started = Date()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: command.executable)
        process.arguments = command.arguments
        process.currentDirectoryURL = URL(fileURLWithPath: command.workingDirectory)
        var environment = ProcessInfo.processInfo.environment
        environment["GIT_TERMINAL_PROMPT"] = "0"
        environment["GIT_PAGER"] = "cat"
        environment["GIT_OPTIONAL_LOCKS"] = "0"
        process.environment = environment

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return DevToolsCommandResult(
                command: command,
                status: .failure,
                output: "Could not run command: \(error.localizedDescription)",
                startedAt: started,
                exitCode: nil
            )
        }

        let group = DispatchGroup()
        let capture = PipeCapture()
        let queue = DispatchQueue(label: "DevCommandEngine.pipe", attributes: .concurrent)

        group.enter()
        queue.async {
            let data = stdout.fileHandleForReading.readDataToEndOfFile()
            capture.setStdout(data)
            group.leave()
        }
        group.enter()
        queue.async {
            let data = stderr.fileHandleForReading.readDataToEndOfFile()
            capture.setStderr(data)
            group.leave()
        }

        if group.wait(timeout: .now() + command.timeout) == .timedOut {
            process.terminate()
            return DevToolsCommandResult(
                command: command,
                status: .timeout,
                output: "Command exceeded \(Int(command.timeout))s timeout.",
                startedAt: started,
                exitCode: nil
            )
        }

        process.waitUntilExit()
        let combined = capture.combined()

        return DevToolsCommandResult(
            command: command,
            status: process.terminationStatus == 0 ? .success : .failure,
            output: truncate(combined),
            startedAt: started,
            exitCode: process.terminationStatus
        )
    }

    public func blocked(_ command: DevToolsCommand, started: Date = Date(), reason: String) -> DevToolsCommandResult {
        DevToolsCommandResult(command: command, status: .blocked, output: reason, startedAt: started)
    }

    private var swiftEnvironment: [String] {
        [
            "DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer",
            "CLANG_MODULE_CACHE_PATH=.build/ModuleCache",
        ]
    }

    private func allowedExecutable(_ executable: String) -> Bool {
        [
            "/usr/bin/env",
            "/usr/bin/git",
            "/usr/bin/codesign",
            "/usr/sbin/spctl",
        ].contains(executable)
    }

    private func allowedArguments(for kind: DevToolsCommandKind, arguments: [String]) -> Bool {
        switch kind {
        case .swiftBuild:
            arguments == swiftEnvironment + ["swift", "build", "--cache-path", ".build/swiftpm-cache"]
        case .swiftTest:
            arguments == swiftEnvironment + ["swift", "test", "--cache-path", ".build/swiftpm-cache"]
        case .gitStatus:
            arguments == ["status", "--short", "--branch"]
        case .codesignVerify:
            arguments.count == 4 && arguments[0...2] == ["--verify", "--deep", "--strict"]
        case .gatekeeperCheck:
            arguments.count == 3 && arguments[0...1] == ["--assess", "--verbose=4"]
        case .environmentCapture:
            arguments.isEmpty
        }
    }

    private func isAppBundle(_ path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        guard url.pathExtension == "app" else { return false }
        var isDir: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else { return false }
        return FileManager.default.fileExists(atPath: url.appendingPathComponent("Contents/Info.plist").path)
    }

    private func truncate(_ data: Data) -> String {
        if data.count <= Self.maxOutputBytes {
            return String(data: data, encoding: .utf8) ?? ""
        }
        let prefix = data.prefix(Self.maxOutputBytes)
        let text = String(data: prefix, encoding: .utf8) ?? ""
        return text + "\n\n[output truncated at \(Self.maxOutputBytes) bytes]"
    }
}

private final class PipeCapture: @unchecked Sendable {
    private let lock = NSLock()
    private var stdout = Data()
    private var stderr = Data()

    func setStdout(_ data: Data) {
        lock.lock()
        stdout = data
        lock.unlock()
    }

    func setStderr(_ data: Data) {
        lock.lock()
        stderr = data
        lock.unlock()
    }

    func combined() -> Data {
        lock.lock()
        let data = stdout + stderr
        lock.unlock()
        return data
    }
}
