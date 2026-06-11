import Foundation

public enum RecommendationCategory: String, Codable, CaseIterable, Hashable, Sendable {
    case codeSize = "Code Size"
    case buildHealth = "Build Health"
    case testHealth = "Test Health"
    case repositoryHealth = "Repository Health"
    case releaseReadiness = "Release Readiness"
    case safety = "Safety"
}

public enum RecommendationSeverity: String, Codable, CaseIterable, Hashable, Sendable {
    case info = "Info"
    case advisory = "Advisory"
    case warning = "Warning"
    case high = "High"
    case critical = "Critical"

    public var rank: Int {
        switch self {
        case .info: 0
        case .advisory: 1
        case .warning: 2
        case .high: 3
        case .critical: 4
        }
    }
}

public enum RecommendationApprovalState: String, Codable, CaseIterable, Hashable, Sendable {
    case open = "Open"
    case acknowledged = "Acknowledged"
    case approved = "Approved"
    case rejected = "Rejected"
    case completed = "Completed"
}

public struct RecommendationRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var category: RecommendationCategory
    public var title: String
    public var summary: String
    public var targetPath: String
    public var sourceFilesAffected: Bool
    public var severity: RecommendationSeverity
    public var confidence: Double
    public var evidenceSummary: String
    public var impact: String
    public var suggestedAdjustment: String
    public var safetyWarning: String
    public var rollbackNote: String
    public var approvalState: RecommendationApprovalState
    public var createdAt: Date
    public var updatedAt: Date
    public var approvedBy: String
    public var approvalNote: String
    public var relatedEvidenceIDs: [UUID]

    public init(
        id: UUID = UUID(),
        category: RecommendationCategory,
        title: String,
        summary: String,
        targetPath: String,
        sourceFilesAffected: Bool,
        severity: RecommendationSeverity,
        confidence: Double = 1,
        evidenceSummary: String,
        impact: String,
        suggestedAdjustment: String,
        safetyWarning: String,
        rollbackNote: String,
        approvalState: RecommendationApprovalState = .open,
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        approvedBy: String = "",
        approvalNote: String = "",
        relatedEvidenceIDs: [UUID] = []
    ) {
        self.id = id
        self.category = category
        self.title = title
        self.summary = summary
        self.targetPath = targetPath
        self.sourceFilesAffected = sourceFilesAffected
        self.severity = severity
        self.confidence = confidence
        self.evidenceSummary = evidenceSummary
        self.impact = impact
        self.suggestedAdjustment = suggestedAdjustment
        self.safetyWarning = safetyWarning
        self.rollbackNote = rollbackNote
        self.approvalState = approvalState
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.approvedBy = approvedBy
        self.approvalNote = approvalNote
        self.relatedEvidenceIDs = relatedEvidenceIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, category, title, summary, targetPath, sourceFilesAffected, severity, confidence
        case evidenceSummary, impact, suggestedAdjustment, safetyWarning, rollbackNote
        case approvalState, createdAt, updatedAt, approvedBy, approvalNote, relatedEvidenceIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        category = try c.decodeIfPresent(RecommendationCategory.self, forKey: .category) ?? .safety
        title = try c.decodeIfPresent(String.self, forKey: .title) ?? "Recommendation"
        summary = try c.decodeIfPresent(String.self, forKey: .summary) ?? ""
        targetPath = try c.decodeIfPresent(String.self, forKey: .targetPath) ?? ""
        sourceFilesAffected = try c.decodeIfPresent(Bool.self, forKey: .sourceFilesAffected) ?? false
        severity = try c.decodeIfPresent(RecommendationSeverity.self, forKey: .severity) ?? .advisory
        confidence = try c.decodeIfPresent(Double.self, forKey: .confidence) ?? 1
        evidenceSummary = try c.decodeIfPresent(String.self, forKey: .evidenceSummary) ?? ""
        impact = try c.decodeIfPresent(String.self, forKey: .impact) ?? ""
        suggestedAdjustment = try c.decodeIfPresent(String.self, forKey: .suggestedAdjustment) ?? ""
        safetyWarning = try c.decodeIfPresent(String.self, forKey: .safetyWarning) ?? "Review before changing project files."
        rollbackNote = try c.decodeIfPresent(String.self, forKey: .rollbackNote) ?? "Create a backup or use version control before changing files."
        approvalState = try c.decodeIfPresent(RecommendationApprovalState.self, forKey: .approvalState) ?? .open
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        approvedBy = try c.decodeIfPresent(String.self, forKey: .approvedBy) ?? ""
        approvalNote = try c.decodeIfPresent(String.self, forKey: .approvalNote) ?? ""
        relatedEvidenceIDs = try c.decodeIfPresent([UUID].self, forKey: .relatedEvidenceIDs) ?? []
    }

    public func withApprovalState(_ state: RecommendationApprovalState, by author: String, note: String) -> RecommendationRecord {
        var copy = self
        copy.approvalState = state
        copy.approvedBy = author
        copy.approvalNote = note
        copy.updatedAt = Date()
        return copy
    }
}

public struct CodeSizeFinding: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var path: String
    public var relativePath: String
    public var lineCount: Int
    public var threshold: Int
    public var language: String

    public init(
        id: UUID = UUID(),
        path: String,
        relativePath: String,
        lineCount: Int,
        threshold: Int,
        language: String
    ) {
        self.id = id
        self.path = path
        self.relativePath = relativePath
        self.lineCount = lineCount
        self.threshold = threshold
        self.language = language
    }

    public var recommendationTitle: String {
        "\(relativePath) exceeds \(threshold) lines"
    }
}
