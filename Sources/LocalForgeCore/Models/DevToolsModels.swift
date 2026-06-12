import Foundation

public enum DevToolsCommandKind: String, Codable, CaseIterable, Hashable, Sendable {
    case swiftBuild = "Swift Build"
    case swiftTest = "Swift Test"
    case xcodeBuild = "Xcode Build"
    case xcodeTest = "Xcode Test"
    case npmBuild = "npm Build"
    case npmTest = "npm Test"
    case gitStatus = "Git Status"
    case codesignVerify = "Codesign Verify"
    case gatekeeperCheck = "Gatekeeper Check"
    case environmentCapture = "Environment Capture"
}

public enum DevToolsCommandRisk: String, Codable, CaseIterable, Hashable, Sendable {
    case readOnly = "Read-only"
    case buildWrites = "Build output"
    case externalAssessment = "System assessment"
}

public struct DevToolsCommand: Identifiable, Codable, Hashable, Sendable {
    public var id: DevToolsCommandKind { kind }
    public var kind: DevToolsCommandKind
    public var title: String
    public var detail: String
    public var executable: String
    public var arguments: [String]
    public var workingDirectory: String
    public var risk: DevToolsCommandRisk
    public var timeout: TimeInterval
    public var verificationArea: String
    public var requiresAppBundle: Bool

    public init(
        kind: DevToolsCommandKind,
        title: String,
        detail: String,
        executable: String,
        arguments: [String],
        workingDirectory: String,
        risk: DevToolsCommandRisk,
        timeout: TimeInterval,
        verificationArea: String,
        requiresAppBundle: Bool = false
    ) {
        self.kind = kind
        self.title = title
        self.detail = detail
        self.executable = executable
        self.arguments = arguments
        self.workingDirectory = workingDirectory
        self.risk = risk
        self.timeout = timeout
        self.verificationArea = verificationArea
        self.requiresAppBundle = requiresAppBundle
    }

    public var displayCommand: String {
        ([executable] + arguments).joined(separator: " ")
    }
}

public enum DevToolsRunStatus: String, Codable, Hashable, Sendable {
    case success = "Success"
    case failure = "Failure"
    case blocked = "Blocked"
    case timeout = "Timeout"

    public var buildResult: BuildResult {
        switch self {
        case .success: .success
        case .failure: .failure
        case .blocked: .cancelled
        case .timeout: .failure
        }
    }

    public var testOutcome: TestOutcome {
        switch self {
        case .success: .passed
        case .failure, .timeout: .failed
        case .blocked: .blocked
        }
    }
}

public struct DevToolsCommandResult: Identifiable, Hashable, Sendable {
    public var id: UUID
    public var command: DevToolsCommand
    public var status: DevToolsRunStatus
    public var output: String
    public var startedAt: Date
    public var endedAt: Date
    public var exitCode: Int32?

    public init(
        id: UUID = UUID(),
        command: DevToolsCommand,
        status: DevToolsRunStatus,
        output: String,
        startedAt: Date,
        endedAt: Date = Date(),
        exitCode: Int32? = nil
    ) {
        self.id = id
        self.command = command
        self.status = status
        self.output = output
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.exitCode = exitCode
    }

    public var durationDisplay: String {
        let duration = endedAt.timeIntervalSince(startedAt)
        if duration < 60 { return "\(Int(duration))s" }
        return "\(Int(duration / 60))m \(Int(duration.truncatingRemainder(dividingBy: 60)))s"
    }
}
