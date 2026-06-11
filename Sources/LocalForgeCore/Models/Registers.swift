import Foundation

// MARK: - Decision Register

public enum DecisionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case proposed = "Proposed"
    case accepted = "Accepted"
    case rejected = "Rejected"
    case superseded = "Superseded"
    case deprecated = "Deprecated"
    case needsReview = "Needs Review"
}

public struct DecisionRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var decision: String
    public var reason: String
    public var alternativesConsidered: String
    public var tradeOffs: String
    public var impact: String
    public var status: DecisionStatus
    public var author: String
    public var createdAt: Date
    public var updatedAt: Date
    public var tags: [String]
    // Phase 7.5 cross-links.
    public var linkedEvidenceIDs: [UUID] = []
    public var linkedRiskIDs: [UUID] = []
    public var linkedArchitectureIDs: [UUID] = []
    public var linkedVerificationIDs: [UUID] = []

    public init(
        id: UUID = UUID(),
        title: String,
        decision: String = "",
        reason: String = "",
        alternativesConsidered: String = "",
        tradeOffs: String = "",
        impact: String = "",
        status: DecisionStatus = .accepted,
        author: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        tags: [String] = [],
        linkedEvidenceIDs: [UUID] = [],
        linkedRiskIDs: [UUID] = [],
        linkedArchitectureIDs: [UUID] = [],
        linkedVerificationIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.decision = decision
        self.reason = reason
        self.alternativesConsidered = alternativesConsidered
        self.tradeOffs = tradeOffs
        self.impact = impact
        self.status = status
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.tags = tags
        self.linkedEvidenceIDs = linkedEvidenceIDs
        self.linkedRiskIDs = linkedRiskIDs
        self.linkedArchitectureIDs = linkedArchitectureIDs
        self.linkedVerificationIDs = linkedVerificationIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, decision, reason, alternativesConsidered, tradeOffs, impact, status, author, createdAt, updatedAt, tags
        case linkedEvidenceIDs, linkedRiskIDs, linkedArchitectureIDs, linkedVerificationIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        decision = try c.decodeIfPresent(String.self, forKey: .decision) ?? ""
        reason = try c.decodeIfPresent(String.self, forKey: .reason) ?? ""
        alternativesConsidered = try c.decodeIfPresent(String.self, forKey: .alternativesConsidered) ?? ""
        tradeOffs = try c.decodeIfPresent(String.self, forKey: .tradeOffs) ?? ""
        impact = try c.decodeIfPresent(String.self, forKey: .impact) ?? ""
        status = try c.decodeIfPresent(DecisionStatus.self, forKey: .status) ?? .accepted
        author = try c.decodeIfPresent(String.self, forKey: .author) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        linkedEvidenceIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedEvidenceIDs) ?? []
        linkedRiskIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedRiskIDs) ?? []
        linkedArchitectureIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedArchitectureIDs) ?? []
        linkedVerificationIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedVerificationIDs) ?? []
    }
}

// MARK: - Architecture Register

public enum SubsystemType: String, Codable, CaseIterable, Hashable, Sendable {
    case uiLayer = "UI Layer"
    case persistence = "Persistence"
    case audioEngine = "Audio Engine"
    case dspEngine = "DSP Engine"
    case midiEngine = "MIDI Engine"
    case presetSystem = "Preset System"
    case stateRestoration = "State Restoration"
    case parameterTree = "Parameter Tree"
    case buildSystem = "Build System"
    case cli = "CLI"
    case reportSystem = "Report System"
    case securityBoundary = "Security Boundary"
    case dataModel = "Data Model"
    case importExport = "Import/Export"
    case networking = "Networking"
    case appShell = "App Shell"
    case pluginHost = "Plugin Host Integration"
    case unknown = "Unknown"
}

public enum ArchitectureStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case planned = "Planned"
    case inProgress = "In Progress"
    case live = "Live"
    case failing = "Failing"
    case needsReview = "Needs Review"
    case deprecated = "Deprecated"
}

public struct ArchitectureItem: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var name: String
    public var subsystemType: SubsystemType
    public var purpose: String
    public var status: ArchitectureStatus
    public var owner: String
    public var dependencies: [String]
    public var linkedVerificationAreas: [String]
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    // Phase 7.5 cross-links.
    public var linkedEvidenceIDs: [UUID] = []
    public var linkedRiskIDs: [UUID] = []
    public var linkedDecisionIDs: [UUID] = []
    public var linkedArchitectureIDs: [UUID] = []

    public init(
        id: UUID = UUID(),
        name: String,
        subsystemType: SubsystemType = .unknown,
        purpose: String = "",
        status: ArchitectureStatus = .live,
        owner: String = "",
        dependencies: [String] = [],
        linkedVerificationAreas: [String] = [],
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        linkedEvidenceIDs: [UUID] = [],
        linkedRiskIDs: [UUID] = [],
        linkedDecisionIDs: [UUID] = [],
        linkedArchitectureIDs: [UUID] = []
    ) {
        self.id = id
        self.name = name
        self.subsystemType = subsystemType
        self.purpose = purpose
        self.status = status
        self.owner = owner
        self.dependencies = dependencies
        self.linkedVerificationAreas = linkedVerificationAreas
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedEvidenceIDs = linkedEvidenceIDs
        self.linkedRiskIDs = linkedRiskIDs
        self.linkedDecisionIDs = linkedDecisionIDs
        self.linkedArchitectureIDs = linkedArchitectureIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, subsystemType, purpose, status, owner, dependencies, linkedVerificationAreas, notes, createdAt, updatedAt
        case linkedEvidenceIDs, linkedRiskIDs, linkedDecisionIDs, linkedArchitectureIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        subsystemType = try c.decodeIfPresent(SubsystemType.self, forKey: .subsystemType) ?? .unknown
        purpose = try c.decodeIfPresent(String.self, forKey: .purpose) ?? ""
        status = try c.decodeIfPresent(ArchitectureStatus.self, forKey: .status) ?? .live
        owner = try c.decodeIfPresent(String.self, forKey: .owner) ?? ""
        dependencies = try c.decodeIfPresent([String].self, forKey: .dependencies) ?? []
        linkedVerificationAreas = try c.decodeIfPresent([String].self, forKey: .linkedVerificationAreas) ?? []
        notes = try c.decodeIfPresent(String.self, forKey: .notes) ?? ""
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        linkedEvidenceIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedEvidenceIDs) ?? []
        linkedRiskIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedRiskIDs) ?? []
        linkedDecisionIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedDecisionIDs) ?? []
        linkedArchitectureIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedArchitectureIDs) ?? []
    }
}

// MARK: - Risk Register

public enum RiskLikelihood: String, Codable, CaseIterable, Hashable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case unknown = "Unknown"
}

public enum RiskImpact: String, Codable, CaseIterable, Hashable, Sendable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case critical = "Critical"
}

public enum RiskStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case open = "Open"
    case monitoring = "Monitoring"
    case mitigated = "Mitigated"
    case accepted = "Accepted"
    case closed = "Closed"
}

public struct RiskRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var title: String
    public var description: String
    public var likelihood: RiskLikelihood
    public var impact: RiskImpact
    public var status: RiskStatus
    public var mitigation: String
    public var contingency: String
    public var owner: String
    public var linkedVerificationAreas: [String]
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    // Phase 7.5 cross-links.
    public var linkedEvidenceIDs: [UUID] = []
    public var linkedDecisionIDs: [UUID] = []
    public var linkedArchitectureIDs: [UUID] = []
    public var linkedVerificationIDs: [UUID] = []

    public init(
        id: UUID = UUID(),
        title: String,
        description: String = "",
        likelihood: RiskLikelihood = .medium,
        impact: RiskImpact = .medium,
        status: RiskStatus = .open,
        mitigation: String = "",
        contingency: String = "",
        owner: String = "",
        linkedVerificationAreas: [String] = [],
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        linkedEvidenceIDs: [UUID] = [],
        linkedDecisionIDs: [UUID] = [],
        linkedArchitectureIDs: [UUID] = [],
        linkedVerificationIDs: [UUID] = []
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.likelihood = likelihood
        self.impact = impact
        self.status = status
        self.mitigation = mitigation
        self.contingency = contingency
        self.owner = owner
        self.linkedVerificationAreas = linkedVerificationAreas
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedEvidenceIDs = linkedEvidenceIDs
        self.linkedDecisionIDs = linkedDecisionIDs
        self.linkedArchitectureIDs = linkedArchitectureIDs
        self.linkedVerificationIDs = linkedVerificationIDs
    }

    /// Severity = likelihood × impact, with critical impact dominating.
    public var severityScore: Int {
        let i: Int = { switch impact { case .low: 1; case .medium: 2; case .high: 3; case .critical: 4 } }()
        let l: Int = { switch likelihood { case .low: 1; case .medium: 2; case .high: 3; case .unknown: 2 } }()
        return i * l
    }

    public var isReleaseBlocking: Bool {
        status == .open && (impact == .critical || (impact == .high && likelihood != .low))
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, likelihood, impact, status, mitigation, contingency, owner, linkedVerificationAreas, tags, createdAt, updatedAt
        case linkedEvidenceIDs, linkedDecisionIDs, linkedArchitectureIDs, linkedVerificationIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        title = try c.decode(String.self, forKey: .title)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        likelihood = try c.decodeIfPresent(RiskLikelihood.self, forKey: .likelihood) ?? .medium
        impact = try c.decodeIfPresent(RiskImpact.self, forKey: .impact) ?? .medium
        status = try c.decodeIfPresent(RiskStatus.self, forKey: .status) ?? .open
        mitigation = try c.decodeIfPresent(String.self, forKey: .mitigation) ?? ""
        contingency = try c.decodeIfPresent(String.self, forKey: .contingency) ?? ""
        owner = try c.decodeIfPresent(String.self, forKey: .owner) ?? ""
        linkedVerificationAreas = try c.decodeIfPresent([String].self, forKey: .linkedVerificationAreas) ?? []
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        linkedEvidenceIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedEvidenceIDs) ?? []
        linkedDecisionIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedDecisionIDs) ?? []
        linkedArchitectureIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedArchitectureIDs) ?? []
        linkedVerificationIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedVerificationIDs) ?? []
    }
}

// MARK: - Assumption Register

public enum AssumptionStatus: String, Codable, CaseIterable, Hashable, Sendable {
    case active = "Active"
    case verified = "Verified"
    case disproved = "Disproved"
    case superseded = "Superseded"
    case needsReview = "Needs Review"
}

public struct AssumptionRecord: Identifiable, Codable, Hashable, Sendable {
    public var id: UUID
    public var assumption: String
    public var rationale: String
    public var confidence: EvidenceClassification
    public var verificationNeeded: String
    public var status: AssumptionStatus
    public var linkedVerificationArea: String
    public var tags: [String]
    public var createdAt: Date
    public var updatedAt: Date
    // Phase 7.5 cross-links.
    public var linkedEvidenceIDs: [UUID] = []
    public var linkedRiskIDs: [UUID] = []
    public var linkedVerificationIDs: [UUID] = []

    public init(
        id: UUID = UUID(),
        assumption: String,
        rationale: String = "",
        confidence: EvidenceClassification = .assumed,
        verificationNeeded: String = "",
        status: AssumptionStatus = .active,
        linkedVerificationArea: String = "",
        tags: [String] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        linkedEvidenceIDs: [UUID] = [],
        linkedRiskIDs: [UUID] = [],
        linkedVerificationIDs: [UUID] = []
    ) {
        self.id = id
        self.assumption = assumption
        self.rationale = rationale
        self.confidence = confidence
        self.verificationNeeded = verificationNeeded
        self.status = status
        self.linkedVerificationArea = linkedVerificationArea
        self.tags = tags
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.linkedEvidenceIDs = linkedEvidenceIDs
        self.linkedRiskIDs = linkedRiskIDs
        self.linkedVerificationIDs = linkedVerificationIDs
    }

    private enum CodingKeys: String, CodingKey {
        case id, assumption, rationale, confidence, verificationNeeded, status, linkedVerificationArea, tags, createdAt, updatedAt
        case linkedEvidenceIDs, linkedRiskIDs, linkedVerificationIDs
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        assumption = try c.decode(String.self, forKey: .assumption)
        rationale = try c.decodeIfPresent(String.self, forKey: .rationale) ?? ""
        confidence = try c.decodeIfPresent(EvidenceClassification.self, forKey: .confidence) ?? .assumed
        verificationNeeded = try c.decodeIfPresent(String.self, forKey: .verificationNeeded) ?? ""
        status = try c.decodeIfPresent(AssumptionStatus.self, forKey: .status) ?? .active
        linkedVerificationArea = try c.decodeIfPresent(String.self, forKey: .linkedVerificationArea) ?? ""
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? Date()
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? Date()
        linkedEvidenceIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedEvidenceIDs) ?? []
        linkedRiskIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedRiskIDs) ?? []
        linkedVerificationIDs = try c.decodeIfPresent([UUID].self, forKey: .linkedVerificationIDs) ?? []
    }
}
