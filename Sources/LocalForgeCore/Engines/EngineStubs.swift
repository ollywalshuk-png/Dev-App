import Foundation

public protocol LocalForgeEngine: Sendable {
    var name: String { get }
    var v1Status: String { get }
}

public struct EngineStatus: Identifiable, Codable, Hashable, Sendable {
    public let id: UUID
    public var name: String
    public var status: String

    public init(id: UUID = UUID(), name: String, status: String) {
        self.id = id
        self.name = name
        self.status = status
    }
}

public enum EngineRegistry {
    public static let v1Foundations: [EngineStatus] = [
        EngineStatus(name: "ScannerEngine", status: "Implemented: local metadata scan"),
        EngineStatus(name: "ProjectClassifier", status: "Implemented: read-only project recognition"),
        EngineStatus(name: "GitEngine", status: "Implemented: read-only branch/status/log"),
        EngineStatus(name: "BuildIntelligenceEngine", status: "Stub: report surface only"),
        EngineStatus(name: "BloatEngine", status: "Foundation: large-file count"),
        EngineStatus(name: "SecurityEngine", status: "Foundation: redaction/report policy"),
        EngineStatus(name: "ReportEngine", status: "Implemented: Markdown report"),
        EngineStatus(name: "RealityEngine", status: "Implemented: known/verified/assumed/unknown + reality score + next action"),
        EngineStatus(name: "SafetyApprovalEngine", status: "Implemented: V1 blocks mutations"),
        EngineStatus(name: "StorageEngine", status: "Implemented: local workspace preferences/bookmarks"),
        EngineStatus(name: "MissionEngine", status: "Implemented: inferred mission from type/name/README"),
        EngineStatus(name: "ApplicabilityEngine", status: "Implemented: per-kind in-scope check matrix"),
        EngineStatus(name: "GuardianEngine", status: "Implemented: prioritized recommendation"),
        EngineStatus(name: "CommandSafetyEngine", status: "Implemented: command assessment"),
        EngineStatus(name: "WorkspaceIntegrityEngine", status: "Foundation: selected-root warnings"),
        EngineStatus(name: "VerificationEngine", status: "Foundation: unknown is never green"),
        EngineStatus(name: "TimelineEngine", status: "Stub: local events planned"),
        EngineStatus(name: "DocumentationEngine", status: "Stub: docs ledger created"),
        EngineStatus(name: "ReleaseReadinessEngine", status: "Stub: manual report planned"),
        EngineStatus(name: "PrivacyGovernanceEngine", status: "Implemented: default posture"),
        EngineStatus(name: "CommercialReadinessEngine", status: "Implemented: no runtime cost posture")
    ]
}
