import Foundation

public struct DevCommandEngine: Sendable {
    public static let maxOutputBytes = 256 * 1024

    public init() {}

    public func provenanceRecords(
        for result: DevToolsCommandResult,
        author: String = ""
    ) -> DevToolsProvenanceRecords {
        let output = sanitizedOutput(result.output)
        let evidenceBody = evidenceBody(for: result, output: output)
        let evidence = EvidenceRecord(
            area: result.command.verificationArea,
            kind: result.command.kind == .environmentCapture ? .environment : .logExcerpt,
            summary: "\(result.command.title): \(result.status.rawValue)",
            body: evidenceBody,
            classification: evidenceClassification(for: result.status),
            author: author,
            createdAt: result.endedAt
        )

        return DevToolsProvenanceRecords(
            evidence: evidence,
            build: buildRecord(for: result, output: evidenceBody, evidenceID: evidence.id),
            test: testRecord(for: result, output: evidenceBody, evidenceID: evidence.id, author: author),
            environment: environmentSnapshot(for: result, output: output)
        )
    }

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
            output: sanitizedOutput(combined),
            startedAt: started,
            exitCode: process.terminationStatus
        )
    }

    public func blocked(_ command: DevToolsCommand, started: Date = Date(), reason: String) -> DevToolsCommandResult {
        DevToolsCommandResult(command: command, status: .blocked, output: reason, startedAt: started)
    }

    private func buildRecord(
        for result: DevToolsCommandResult,
        output: String,
        evidenceID: UUID
    ) -> BuildRecord? {
        let buildType: BuildType
        switch result.command.kind {
        case .swiftBuild:
            buildType = .swiftBuild
        case .swiftTest:
            buildType = .swiftTest
        case .gitStatus, .codesignVerify, .gatekeeperCheck, .environmentCapture:
            return nil
        }

        return BuildRecord(
            buildType: buildType,
            startTime: result.startedAt,
            endTime: result.endedAt,
            result: result.status.buildResult,
            notes: output,
            linkedEvidenceIDs: [evidenceID],
            linkedVerificationAreas: [result.command.verificationArea]
        )
    }

    private func testRecord(
        for result: DevToolsCommandResult,
        output: String,
        evidenceID: UUID,
        author: String
    ) -> TestRecord? {
        guard result.command.kind == .swiftTest else { return nil }
        return TestRecord(
            name: "swift test",
            kind: .automated,
            outcome: result.status.testOutcome,
            linkedVerificationArea: result.command.verificationArea,
            linkedEvidenceIDs: [evidenceID],
            notes: output,
            testedAt: result.endedAt,
            author: author
        )
    }

    private func environmentSnapshot(
        for result: DevToolsCommandResult,
        output: String
    ) -> EnvironmentSnapshot? {
        guard result.command.kind == .environmentCapture else { return nil }
        let values = environmentValues(from: output)
        return EnvironmentSnapshot(
            macOSVersion: values["macOS"] ?? "",
            xcodeVersion: values["Xcode"] ?? "",
            swiftVersion: values["Swift"] ?? "",
            sdkVersion: values["SDK"] ?? "",
            auValVersion: values["auval"] ?? "",
            capturedAt: result.startedAt,
            notes: output
        )
    }

    private func environmentValues(from output: String) -> [String: String] {
        var values: [String: String] = [:]
        for line in output.split(whereSeparator: \.isNewline) {
            let parts = line.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            guard parts.count == 2 else { continue }
            let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            values[key] = value == "Unknown" ? "" : value
        }
        return values
    }

    private func evidenceClassification(for status: DevToolsRunStatus) -> EvidenceClassification {
        switch status {
        case .success:
            .observed
        case .failure, .timeout:
            .measured
        case .blocked:
            .unknown
        }
    }

    private func evidenceBody(for result: DevToolsCommandResult, output: String) -> String {
        guard let signal = commandEvidenceSignal(for: result) else { return output }
        guard !output.contains("[output truncated at \(Self.maxOutputBytes) bytes]") else { return output }
        guard !output.isEmpty else { return signal }
        return truncatedOutput("\(signal)\n\n\(output)")
    }

    private func commandEvidenceSignal(for result: DevToolsCommandResult) -> String? {
        guard result.command.kind == .swiftBuild || result.command.kind == .swiftTest else { return nil }

        let status: String
        let caveat: String
        switch result.status {
        case .success:
            status = "succeeded"
            caveat = "Local command output supports \(result.command.verificationArea) but does not by itself mark verification or release readiness as passed."
        case .failure:
            status = "failed"
            caveat = "Local command output records a failed command; fix and rerun before treating \(result.command.verificationArea) as release-supporting evidence."
        case .timeout:
            status = "timed out"
            caveat = "Local command output records an incomplete command; rerun before treating \(result.command.verificationArea) as release-supporting evidence."
        case .blocked:
            status = "was blocked"
            caveat = "The preset was blocked before execution; this is not proof about \(result.command.verificationArea)."
        }

        return "Dev Tools evidence signal: \(result.command.title) \(status)\(exitCodeLabel(for: result)). \(caveat)"
    }

    private func exitCodeLabel(for result: DevToolsCommandResult) -> String {
        guard result.status == .success || result.status == .failure else { return "" }
        guard let exitCode = result.exitCode else { return " (no exit code captured)" }
        return " (exit code \(exitCode))"
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

    private func sanitizedOutput(_ data: Data) -> String {
        sanitizedOutput(String(decoding: data, as: UTF8.self))
    }

    private func sanitizedOutput(_ text: String) -> String {
        let redacted = ReportEngine().redact(text)
        return truncatedOutput(redacted)
    }

    private func truncatedOutput(_ text: String) -> String {
        guard text.utf8.count > Self.maxOutputBytes else { return text }

        var end = text.startIndex
        var byteCount = 0
        while end < text.endIndex {
            let next = text.index(after: end)
            let charByteCount = text[end].utf8.count
            guard byteCount + charByteCount <= Self.maxOutputBytes else { break }
            byteCount += charByteCount
            end = next
        }

        return String(text[..<end]) + "\n\n[output truncated at \(Self.maxOutputBytes) bytes]"
    }
}

public struct DevToolsProvenanceRecords: Hashable, Sendable {
    public var evidence: EvidenceRecord
    public var build: BuildRecord?
    public var test: TestRecord?
    public var environment: EnvironmentSnapshot?

    public init(
        evidence: EvidenceRecord,
        build: BuildRecord? = nil,
        test: TestRecord? = nil,
        environment: EnvironmentSnapshot? = nil
    ) {
        self.evidence = evidence
        self.build = build
        self.test = test
        self.environment = environment
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
