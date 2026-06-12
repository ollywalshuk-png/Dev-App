import Foundation

public enum SecretFindingKind: String, Codable, CaseIterable, Hashable, Sendable {
    case credentialAssignment = "Credential Assignment"
    case providerToken = "Provider Token"
    case embeddedCredential = "Embedded Credential"
    case privateKeyMaterial = "Private Key Material"

    public var defaultSeverity: RecommendationSeverity {
        switch self {
        case .credentialAssignment: .warning
        case .providerToken: .high
        case .embeddedCredential: .high
        case .privateKeyMaterial: .critical
        }
    }
}

public struct SecretScanFinding: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var path: String
    public var relativePath: String
    public var lineNumber: Int
    public var kind: SecretFindingKind
    public var severity: RecommendationSeverity
    public var redactedPreview: String
    public var reason: String

    public init(
        id: UUID = UUID(),
        path: String,
        relativePath: String,
        lineNumber: Int,
        kind: SecretFindingKind,
        severity: RecommendationSeverity? = nil,
        redactedPreview: String,
        reason: String
    ) {
        self.id = id
        self.path = path
        self.relativePath = relativePath
        self.lineNumber = lineNumber
        self.kind = kind
        self.severity = severity ?? kind.defaultSeverity
        self.redactedPreview = redactedPreview
        self.reason = reason
    }

    public var recommendationTitle: String {
        "Potential secret in \(relativePath):\(lineNumber)"
    }
}
