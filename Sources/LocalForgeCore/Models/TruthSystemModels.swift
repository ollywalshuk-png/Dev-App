import Foundation

// MARK: - Reality breakdown (explainable score)

/// One line in the Reality score breakdown: a positive or negative contribution
/// with a human-readable label so the user can see *why* the score is what it is.
public struct RealityContribution: Identifiable, Hashable, Sendable {
    public let id = UUID()
    public var label: String
    public var delta: Int
    public init(label: String, delta: Int) {
        self.label = label
        self.delta = delta
    }
}

/// A full breakdown of the Reality score with every contribution itemised.
public struct RealityBreakdown: Hashable, Sendable {
    public var baseline: Int
    public var contributions: [RealityContribution]
    public var finalScore: Int

    public init(baseline: Int, contributions: [RealityContribution], finalScore: Int) {
        self.baseline = baseline
        self.contributions = contributions
        self.finalScore = finalScore
    }

    public static let empty = RealityBreakdown(baseline: 0, contributions: [], finalScore: 0)

    /// Positive vs negative contribution buckets, useful for the UI.
    public var positives: [RealityContribution] { contributions.filter { $0.delta > 0 } }
    public var negatives: [RealityContribution] { contributions.filter { $0.delta < 0 } }
}

// MARK: - Confidence (separate from Reality)

/// Phase 7.5: Confidence is separate from Reality. Reality measures *state of the
/// project*; Confidence measures *quality of the evidence backing that state*.
///
/// A failing project can still have high confidence — "we are confident this is broken".
/// A passing project with no evidence has low confidence — "we believe it works, but
/// we haven't really checked".
public struct ConfidenceAssessment: Hashable, Sendable {
    public var score: Int
    public var label: String
    public var summary: String
    public var contributions: [RealityContribution]

    public init(score: Int, label: String, summary: String, contributions: [RealityContribution]) {
        self.score = score
        self.label = label
        self.summary = summary
        self.contributions = contributions
    }

    public static let unknown = ConfidenceAssessment(
        score: 0,
        label: "Unknown",
        summary: "No project state to assess.",
        contributions: []
    )
}

// MARK: - Register health (where truth is weak)

public struct RegisterHealth: Hashable, Sendable {
    public var evidenceCoverage: Double
    public var riskCoverage: Double
    public var decisionCoverage: Double
    public var architectureCoverage: Double
    public var assumptionCoverage: Double

    public init(
        evidenceCoverage: Double,
        riskCoverage: Double,
        decisionCoverage: Double,
        architectureCoverage: Double,
        assumptionCoverage: Double
    ) {
        self.evidenceCoverage = evidenceCoverage
        self.riskCoverage = riskCoverage
        self.decisionCoverage = decisionCoverage
        self.architectureCoverage = architectureCoverage
        self.assumptionCoverage = assumptionCoverage
    }

    public static let empty = RegisterHealth(
        evidenceCoverage: 0,
        riskCoverage: 0,
        decisionCoverage: 0,
        architectureCoverage: 0,
        assumptionCoverage: 0
    )
}

// MARK: - Related records ("Show Related")

/// A reference to any record in the truth system, used to ask "what relates to this?"
public enum TruthRecordRef: Hashable, Sendable {
    case evidence(UUID)
    case risk(UUID)
    case decision(UUID)
    case architecture(UUID)
    case assumption(UUID)
    case verification(UUID)
}

/// Everything connected to a single record — resolved both ways: links the
/// record stores (forward) and links other records store pointing back at it
/// (reverse). Storage stays single-direction; resolution is bidirectional, so
/// linking once from either side is enough.
public struct RelatedRecords: Hashable, Sendable {
    public var evidence: [EvidenceRecord] = []
    public var risks: [RiskRecord] = []
    public var decisions: [DecisionRecord] = []
    public var architecture: [ArchitectureItem] = []
    public var assumptions: [AssumptionRecord] = []
    public var verification: [VerificationRecord] = []

    public init() {}

    public var isEmpty: Bool {
        evidence.isEmpty && risks.isEmpty && decisions.isEmpty
            && architecture.isEmpty && assumptions.isEmpty && verification.isEmpty
    }

    public var totalCount: Int {
        evidence.count + risks.count + decisions.count
            + architecture.count + assumptions.count + verification.count
    }
}

// MARK: - Workspace Truth Centre

public struct WorkspaceTruthSummary: Hashable, Sendable {
    public var totalProjects: Int
    public var verifiedRecords: Int
    public var evidenceRecords: Int
    public var openRisks: Int
    public var activeAssumptions: Int
    public var criticalFailures: Int
    public var decisionRecords: Int
    public var architectureItems: Int
    public var staleVerifications: Int
    /// Phase 8 portfolio counts.
    public var criticalOpenRisks: Int
    public var journalEntries: Int

    public init(
        totalProjects: Int = 0,
        verifiedRecords: Int = 0,
        evidenceRecords: Int = 0,
        openRisks: Int = 0,
        activeAssumptions: Int = 0,
        criticalFailures: Int = 0,
        decisionRecords: Int = 0,
        architectureItems: Int = 0,
        staleVerifications: Int = 0,
        criticalOpenRisks: Int = 0,
        journalEntries: Int = 0
    ) {
        self.totalProjects = totalProjects
        self.verifiedRecords = verifiedRecords
        self.evidenceRecords = evidenceRecords
        self.openRisks = openRisks
        self.activeAssumptions = activeAssumptions
        self.criticalFailures = criticalFailures
        self.decisionRecords = decisionRecords
        self.architectureItems = architectureItems
        self.staleVerifications = staleVerifications
        self.criticalOpenRisks = criticalOpenRisks
        self.journalEntries = journalEntries
    }
}
